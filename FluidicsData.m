classdef FluidicsData < handle
    properties
        Rounds = [fliplr(1:24),25];%[1:25];
        Protocols = {'strip','hybe'};
        FlowGroups = {'ABC','DEF'};
        Round
        Protocol
        Group
        Image = false;
        Flow = true;
        Completed_Tasks = {}
        Single = false;
        strip_wait_per_coverslip = 250; 
        hybe_wait_per_coverslip = 350; % 350
        initial_protocol = 'strip';
        initial_group = 'ABC';
        Tasks
        Parallel = true;
        start_round = int2str(1);
        start_protocol = 'strip';
        start_group = 'ABC';
        skip_flow = false;
        skip_image= false;
        start_idx = 1;
        current_idx = 1;
        python = 'C:/Users/wollmanlab/miniconda3/envs/py27/python';
        fluidics = 'C:/Repos/fluidics/Chamber_Fluidics.py';
        extras = '';
        start = clock;
        wait_time = 0;
    end
    methods
        function FlowData = FluidicsData()
            FlowData.update_FlowData();
        end

        function fill_wells_TBS(FlowData,Scp)
            wells = [FlowData.FlowGroups{1:end}];
            chambers = ['[',repmat(',', [1, (2*size(wells,2))-1]),']'];
            chambers(2*(1:size(wells,2))) = wells(1:size(wells,2));
            protocol = 'valve+3';
            command = ['TBS_',chambers,'_',protocol];
            Scp.Notifications.sendSlackMessage(Scp,[Scp.Dataset,' ',command],'all',true);
            system([FlowData.python,' ',FlowData.fluidics,'  ',command,' ',FlowData.extras,' &'])
        end

        function flow(FlowData,Scp)
            while etime(clock,FlowData.start)<FlowData.wait_time
                Scp.Notifications.sendSlackMessage(Scp,[Scp.Dataset,' ','Waiting For Previous Flow to Finish'],'all',true);
                disp('Waiting For Previous Flow to Finish')
                pause(60)
            end
            chambers = '[';
            wells = FlowData.Tasks{FlowData.current_idx,3};
            for g = 1:size(wells,2)
                group = wells(g);
                if g<size(wells,2)
                    chambers = [chambers,group,','];
                else
                    chambers = [chambers,group,']'];
                end
            end
            hybe = FlowData.Tasks{FlowData.current_idx,1};
            protocol = FlowData.Tasks{FlowData.current_idx,2};
            command = ['Hybe',hybe,'_',chambers,'_',protocol];
            if strcmp(protocol,'strip')
                FlowData.wait_time = FlowData.strip_wait_per_coverslip*size(wells,2) + 600;
            elseif strcmp(protocol,'hybe')
                FlowData.wait_time = FlowData.hybe_wait_per_coverslip*size(wells,2) + 600;
            else
                FlowData.wait_time = FlowData.hybe_wait_per_coverslip*size(wells,2) + 600;
            end
            FlowData.start = clock;
            Scp.Notifications.sendSlackMessage(Scp,[Scp.Dataset,' ',command],'all',true);
            system([FlowData.python,' ',FlowData.fluidics,'  ',command,' ',FlowData.extras,' &'])
        end

        function set.start_round(FlowData,start_round)
            FlowData.start_round = start_round;
            FlowData.update_FlowData();
        end

        function set.start_group(FlowData,start_group)
            FlowData.start_group = start_group;
            FlowData.update_FlowData();
        end

        function set.start_protocol(FlowData,start_protocol)
            FlowData.start_protocol = start_protocol;
            FlowData.update_FlowData();
        end

        function set.skip_flow(FlowData,skip_flow)
            FlowData.skip_flow = skip_flow;
            FlowData.update_FlowData();
        end

        function set.skip_image(FlowData,skip_image)
            FlowData.skip_image = skip_image;
            FlowData.update_FlowData();
        end

        function update_FlowData(FlowData)
            % Update Steps
            Steps = cell(size(FlowData.Rounds,1)*size(FlowData.Rounds,1)*size(FlowData.FlowGroups,1),3);
            ticker = 0;
            for hybe = FlowData.Rounds
                for protocol = FlowData.Protocols
                    for group = FlowData.FlowGroups
                        ticker = ticker+1;
                        Steps(ticker,:) = [int2str(hybe),protocol,group];
                    end
                end
            end
            % 1-3 are flow commands % 4-6 are image commands
            if length(FlowData.FlowGroups)>1
                FlowData.Tasks = cell(size(Steps,1)+1,6);
                FlowData.Tasks(1:size(Steps,1),1:3) = Steps;
                FlowData.Tasks(2:(size(Steps,1)+1),4:6) = Steps;
            else
                FlowData.Tasks = cell(2*size(Steps,1)+1,6);
                for i=1:size(Steps,1)
                    FlowData.Tasks(2*i,4:6) = Steps(i,:);
                    FlowData.Tasks((2*i)-1,1:3) = Steps(i,:);
                end
            end

            for i=1:size(FlowData.Tasks,1)
                if (strcmp(FlowData.Tasks(i,1),{FlowData.start_round}))&(strcmp(FlowData.Tasks(i,2),{FlowData.start_protocol}))&(strcmp(FlowData.Tasks(i,3),{FlowData.start_group}))
                    FlowData.start_idx = i;
                    %disp(FlowData.start_idx)
                    if FlowData.start_idx>1
                        i = FlowData.start_idx-1;
                        FlowData.Tasks(1:i,1:6) = cell(i,6);
                    end
                    if FlowData.skip_flow
                        FlowData.Tasks(i,1:3) = cell(3,1);
                    end
                    if FlowData.skip_image
                        FlowData.Tasks(i,4:6) = cell(3,1);
                    end
                end
            end
        end
    end
end

