classdef FluidicsData < handle

    %%
    % FlowData = Copy_of_FluidicsData
    % FlowData.start_Gui
    % FlowData.send_command(FlowData.build_command('Valve',['A','B','C'],'TBS+3'),Scp)
    %%
    properties
        device = 'Fluidics'
        available = false;
        log = 'C:/GitRepos/Fluidics/Status.txt';
        Rounds = [1:25];
        Protocols = {'Strip','Hybe'};
        FlowGroups = {'ABC','DEF'};
        Tasks
        current_idx = 1;
        python = 'C:/Users/wollmanlab/miniconda3/envs/py37/python';
        fluidics = 'C:\GitRepos\Fluidics\Fluidics.py';
        gui = 'C:\GitRepos\Fluidics\GUI.py';
        extras = '';
        n_coverslips = 1;
        coverslips;
        all_wells;
        wells;
        protocol;
        other;
        hybe;
        AcqData;

    end

    methods
        function FlowData = FluidicsData()
            FlowData.update_FlowData();
        end

        function start_Gui(FlowData)
            system([FlowData.python,' ',FlowData.gui,'-f ',FlowData.device,' &'])
        end

        function start_Fluidics(FlowData)
            system([FlowData.python,' ',FlowData.fluidics,'-f ',FlowData.device,' &'])
        end

        function command = build_command(FlowData,protocol,wells,other)
            chambers = ['[',repmat(',', [1, (2*size(wells,2))-1]),']'];
            chambers(2*(1:size(wells,2))) = wells(1:size(wells,2));
            command = [protocol,'*',chambers,'*',other];
        end

        function fill_wells_TBS(FlowData,Scp)
            command = FlowData.build_command('Valve',FlowData.all_wells,'TBS+3');
            FlowData.send_command(command,Scp);
        end

        function flow(FlowData,Scp)
            command = FlowData.build_command(FlowData.protocol,FlowData.wells,FlowData.other);
            if ~isempty(FlowData.wells)
                FlowData.send_command(command,Scp)
            end
        end

        function wells = get.wells(FlowData)
            wells = FlowData.Tasks{FlowData.current_idx,3};
        end

        function protocol = get.protocol(FlowData)
            protocol = FlowData.Tasks{FlowData.current_idx,2};
        end

        function other = get.other(FlowData)
            other = FlowData.Tasks{FlowData.current_idx,1};
        end

        function hybe = get.hybe(FlowData)
            hybe = split(FlowData.other,'Hybe');
            hybe = hybe{end};
        end

        function available = get.available(FlowData)
            message = fileread(FlowData.log);
            if contains(message,'Finished')
                available = true;
            elseif contains(message,'Available')
                available = true;
            else
                available = false;
            end
        end

        function writelog(FlowData,message)
            disp('Sending Command')
            fileID = fopen(FlowData.log,'w');
            fprintf(fileID,message);
            fclose(fileID);
        end

        function send_command(FlowData,message,Scp)
            FlowData.wait_until_available()
            FlowData.writelog(['Command:',message]);
            Scp.Notifications.sendSlackMessage(Scp,['Flowing ',message]);
        end

        function wait_until_available(FlowData)
            start = clock;
            while ~FlowData.available
                fprintf('\n');
                x = etime(clock, start);
                if x<60
                    fprintf('Waiting: %.2f seconds',x)
                elseif x<(60*60)
                    fprintf('Waiting: %.2f minutes',x/60)
                else
                    fprintf('Waiting: %.2f hours',x/(60*60))
                end
                pause(10)
            end
            fprintf('\n');
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
            FlowData.all_wells = [FlowData.FlowGroups{1:end}];
            FlowData.coverslips = cell(length(FlowData.wells),1);
            for i=1:length(FlowData.wells)
                FlowData.coverslips{i} = FlowData.wells(i);
            end
            FlowData.n_coverslips = size(FlowData.coverslips,1);
        end
    end
end

