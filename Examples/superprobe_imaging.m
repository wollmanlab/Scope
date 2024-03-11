%% Initialize Scope
Scp = OrangeScope;
%% Double check that 000 is the top left corner of the scope and Lower Limit
% Scp.Z = 0;
% Scp.XY = [0 0];
%% Set up: username, project name and dataset
Scp.Username = 'Gaby'; % your username!
Scp.Project = 'dredFISH'; % the project this dataset correspond to
Scp.Dataset = ['20um37C500M1H3A2SDS24H100ug47C50F18H50F1H2SDS37C1H-PolyT_DP.A_PolyT_SP.C_TREE_DP.D_TREE_SP.E_TREE_SP.F']; % the name of this specific image dataset - i.e. this experiment.
%Scp.Dataset = ['Tree20um37C500M3A2SDS100ug50F50F1H2SDS37C1H-M12H12Hr.A_M1H60Hr.B_M12H60Hr.C_M0H12Hr.D_M1H60Hr.E_M12H60Hr.F']; % the name of this specific image dataset - i.e. this experiment.
% Scp.Dataset = ['UnclearedTree20um47C100ug50F60H-MF31.A']; % the name of this specific image dataset - i.e. this experiment.
Scp.Dataset_Path = fullfile(Scp.basePath,Scp.Username,Scp.Project,[Scp.Dataset '_' datestr(floor(Scp.TimeStamp{1,2}),'yyyymmmdd')]);
% Scp.Dataset_Path = fullfile(Scp.basePath,Scp.Username,Scp.Project,[Scp.Dataset '_' '2024Feb15']);
Scp.ExperimentDescription = [''];
%% Setup Imaging Parameters
% For Data Collection
Scp.FlowData.AcqData = AcquisitionData;
Scp.FlowData.AcqData(1).Channel = 'DeepBlue';
Scp.FlowData.AcqData(1).Exposure = 150; %
Scp.FlowData.AcqData(1).Delay = 10; %
Scp.FlowData.AcqData(2).Channel = 'FarRed';
Scp.FlowData.AcqData(2).Exposure = 2500; %
Scp.FlowData.AcqData(2).Delay = 10; %

% For Preview
preview_acqdata = AcquisitionData;
preview_acqdata(1).Channel = 'DeepBlue';
preview_acqdata(1).Exposure = 20; %
preview_acqdata(1).Delay = 10; %
% % For Preview
% preview_acqdata = AcquisitionData;
% preview_acqdata(1).Channel = 'FarRed';
% preview_acqdata(1).Exposure = 250; %
% preview_acqdata(1).Delay = 10; %

%% Setup Fluidics Parameters
Scp.FlowData.FlowGroups = {'AC','FED'};
Scp.FlowData.Protocols = {'Strip','Hybe'};
Scp.FlowData.update_FlowData();
Scp.FlowData.Tasks
%% Acquire All Wells First Find Focus manually First
Scp.Chamber = Plate('Underwood6',Scp);
Scp.Chamber.wellSpacingXY = [42500 42500];
position_acq_names = cell(Scp.FlowData.n_coverslips,1);
Scp.AF = NucleiFocus;
Scp.AF.coarse_window = 250;
Scp.AF.channel = 'DeepBlue';
Scp.AF.exposure = 20;
Scp.AutoFocusType='none';
for c=1:Scp.FlowData.n_coverslips
    coverslip = Scp.FlowData.coverslips{c};
    Wells = {coverslip};
    Scp.createPositions('spacing',0.9, ...
        'sitesshape','circle', ...
        'sitesperwell',[35,35], ...
        'wells',Wells,'optimize',true)
    Scp.Pos.Well = coverslip;
    Scp.XY = mean(Scp.Pos.List);
%     Scp.AF.PrimaryImageBasedScan(Scp);
    Scp.acquire(preview_acqdata);
    position_acq_names{c} = Scp.getLastAcqname;
    Scp.Pos.save;
end
%%
% c = Scp.FlowData.n_coverslips;
% coverslip = Scp.FlowData.coverslips{c};
% Wells = {coverslip};
% Scp.createPositions('spacing',0.9, ...
%     'sitesshape','circle', ...
%     'sitesperwell',[28,28], ...
%     'wells',Wells,'optimize',true)
% Scp.Pos.Well = coverslip;
% Scp.XY = mean(Scp.Pos.List);
% Scp.AF.PrimaryImageBasedScan(Scp);
% Scp.acquire(preview_acqdata);
% position_acq_names{c} = Scp.getLastAcqname;
% Scp.Pos.save;
%% Filter Positions by draw
for c=1:Scp.FlowData.n_coverslips
    coverslip = Scp.FlowData.coverslips{c};
    Scp.Pos = Scp.Pos.load([coverslip]);
    Wells = {coverslip};
    Scp.Pos.Well = coverslip;
    Scp.filterPositionsByDraw()
    Scp.Pos.save
end
%% Aquire To ensure that the area you selected is what you actually want
preview_acqdata = AcquisitionData;
preview_acqdata(1).Channel = 'DeepBlue';
preview_acqdata(1).Exposure = 20; %
preview_acqdata(1).Delay = 10; %
% preview_acqdata(2).Channel = 'FarRed';
% preview_acqdata(2).Exposure = 500; %
% preview_acqdata(2).Delay = 10; %
for c=1:Scp.FlowData.n_coverslips
    coverslip = Scp.FlowData.coverslips{c};
    Scp.AutoFocusType='none';
    Scp.Pos = Scp.Pos.load([coverslip]);
    [~,idx] = min(sum(abs(Scp.Pos.List - mean(Scp.Pos.List)),2));
    Scp.XY = Scp.Pos.List(idx,:);
    Scp.AF.coarse_window = 250;
    Scp.AF.PrimaryImageBasedScan(Scp);
    Scp.acquire(preview_acqdata)
    Scp.Pos.save
end
%% Filter Positions for Autofocus Choose only positions that look flat and have a lot of cells to focus on
% for c=1:Scp.FlowData.n_coverslips
%     coverslip = Scp.FlowData.coverslips{c};
%     Scp.Pos = Scp.Pos.load([coverslip]);
%     Scp.Pos.Well = coverslip;
% 
%     Scp.filterPositionsByDraw('rename',false) %%%%%%%%%
%     Scp.AF = ContrastPlaneFocus;
%     Scp.AF.coarse_window = 200;
%     Scp.AF.min_positions  = 5;
%     Scp.AF.n_neighbors  = 5;
%     Scp.AF.channel = 'DeepBlue';
%     Scp.AF.exposure = 25;
%     Scp.AF.use_groups = true;
% %     Scp.AF.use_groups = false;
%     Scp.AF.Well = coverslip;
%     Scp.AF.optimize_speed = false;
% 
%     Scp.AF = Scp.AF.createPostions(Scp.Pos);
%     Scp.AF.save
% end

%% Manually Find Focus for each position
for c=1:1%Scp.FlowData.n_coverslips
    Scp.AutoFocusType='none';
    %coverslip = Scp.FlowData.coverslips{c};
    coverslip = 'F'
    Scp.Pos = Scp.Pos.load([coverslip]);
    Scp.Pos.Well = coverslip;
    Scp.AF = RelativeManualPlaneFocus;
    Scp.AF.Well = coverslip;
    Scp.AF.locations = {'Center','Top','Right','Bottom','Left'};
    Scp.AF.channel = 'FarRed';
    Scp.AF.exposure = 100;
    Scp.AF.dZ = 1;
    Scp.AF.use_groups = true;
    Scp.AF = Scp.AF.createPostions(Scp.Pos);
    Scp.AF = Scp.AF.manualSetPlane(Scp);
    Scp.AF.save
end
%%
for c=1:1% Scp.FlowData.n_coverslips
    Scp.AutoFocusType='none';
    coverslip = 'F' %Scp.FlowData.coverslips{c};
    Scp.AF = Scp.AF.load([coverslip]);
    Scp.AF.window = 200;
    Scp.AF.dZ = 5;
    tic
    Scp.AF = Scp.AF.setRelativeReferencePosition(Scp);
    Scp.Z
    toc
    Scp.AF.save
end
%% Setup AutoFocus and check Focus
% for c=1:1% Scp.FlowData.n_coverslips
%     coverslip = 'F'%Scp.FlowData.coverslips{c};
%     Scp.AF = Scp.AF.load([coverslip]);
%     Scp.AutoFocusType='none';
%     Scp.Pos = Scp.Pos.load([coverslip]);
%     Scp.XY = mean(Scp.Pos.List);
%     Scp.AF.coarse_window = 500;
%     Scp.AF.PrimaryImageBasedScan(Scp);
%     Scp.AF.coarse_window = 100;
%     Scp.AF = Scp.AF.calculateZ(Scp);
%     
% %     hidden = Scp.Pos.Hidden;
% %     for i=1:length(Scp.Pos.Labels)
% %         if contains(Scp.Pos.Labels{i},'Well')
% %             hidden(i) = 0;
% %         end
% %     end
% %     Scp.Pos.Hidden = hidden;
%     Scp.AutoFocusType='hardware';
%     Scp.acquire(preview_acqdata)
%     Scp.Pos.save
%     Scp.AF.save
% end
%% Check Focus
for c=1:1% Scp.FlowData.n_coverslips
    coverslip = 'F' %Scp.FlowData.coverslips{c};
    Scp.AF = Scp.AF.load([coverslip]);
    Scp.Pos = Scp.Pos.load([coverslip]);
    Scp.AF.window = 25;
    Scp.AF.dZ = 5;
    Scp.AF = Scp.AF.updateZ(Scp);
    Scp.AutoFocusType='hardware';
    Scp.acquire(preview_acqdata)
    Scp.Pos.save
    Scp.AF.save
end

%% jittering 
%Z = Scp.Z;
% while true
%     Scp.Z = Z+20*(rand()-0.5);
%     disp(Scp.Z)
%     pause(5)
% end
%% Start Fluidics
Scp.FlowData.start_Gui()
Scp.FlowData.start_Fluidics()
%% Collect Data
Scp.FlowData.FlowGroups = {'ABC','FED'};
Scp.FlowData.Protocols = {'Strip','Hybe'};
Scp.FlowData.ImageProtocols = {'Strip','Hybe'};
% Scp.FlowData.Rounds = [25,27,26,21,17,7,15,3,22,11,6,10,13,2,4,1,5,23,14,20,9,16,24,8,18,19,12];
% Scp.FlowData.Rounds = [27,26,21,17,7,15,3,22,11,6,10,13,2,4,1,5,23,14,20,9,16,24,8,18,19,12];
% Brightest to dimmest
% Scp.FlowData.Rounds = [25,27,26,12,24,18,9,8,19,21,20,6,7,16,5,13,14,1,10,3,11,23,15,22,2,4,17];
% Scp.FlowData.Rounds = [25,12,27,21,6,23,26];
%Scp.FlowData.Rounds = [24,18,9,8,19,20,7,16,5,13,14,1,10,3,11,15,22,2,4,17];
% Scp.FlowData.Rounds = [27,1,10,20,19,25];
% Scp.FlowData.Rounds = [25];

% All Cell Averages
% Scp.FlowData.Rounds = [25,27,26,12,16,20,8,5,18,24,9,6,15,14,19,3,17,2,21,22,10,1,13,4,11,7,23]; % H->L Mean Smartseq row norm
% Scp.FlowData.Rounds = [25,27,26,12,16,20,8,18,5,24,9,6,15,14,19,3,17,21,2,22,10,1,13,4,11,23,7] % H->L Mean Smartseq no norm
% Scp.FlowData.Rounds = [25,27,26,12,16,20,5,8,18,24,9,3,6,14,2,15,13,17,22,19,10,1,4,21,11,7,23] % H->L 95th Smartseq row norm
% Scp.FlowData.Rounds = [25,27,26,12,16,20,18,8,5,24,9,6,14,15,3,2,19,17,13,22,1,10,21,4,11,7,23] % H->L 95th Smartseq no norm
% Cell Type Averages
% Scp.FlowData.Rounds = [25,27,26,12,20,16,8,5,18,24,9,6,14,15,19,21,22,17,23,2,3,10,1,13,4,11,7] % H->L Mean Smartseq row norm 
% Scp.FlowData.Rounds = [25,27,26,12,20,16,8,5,18,24,9,6,21,23,14,15,19,22,2,17,3,13,1,10,4,11,7] % H->L Mean Smartseq no norm
% Scp.FlowData.Rounds = [25,27,26,12,16,20,8,5,18,24,9,6,23,14,15,2,22,19,17,21,10,4,1,13,11,3,7] % H->L 95th Smartseq row norm
% Scp.FlowData.Rounds = [25,27,26,12,16,20,8,18,5,24,9,6,14,23,15,2,22,19,21,17,10,1,4,13,11,3,7] % H->L 95th Smartseq no norm


% Before Waste
% Scp.FlowData.Rounds = [25,27,26,12,24,18,9,8,19,21,20,6,7];

% After waste removal
% Scp.FlowData.Rounds = [16,5,13,14,1,10,3,11,23,15,22,2,4,17]; 
% 
%Scp.FlowData.Rounds = [21,12,25,27,26,16,20,8,5,18,24,9,6,15,14,19,3,17,2,22,10,1,13,4,11,7,23];
% Scp.FlowData.Rounds = [25,12,21,27,26,16,20,8,5,18,24,9,6,15,14,19,3,17,2,22,10,1,13,4,11,7,23,28];
Scp.FlowData.Rounds = [12,21,27,26,16,20,8,5,18,24,9,6,15,14,19,3,17,2,22,10,1,13,4,11,7,23];
Scp.FlowData.Rounds = [15,14,19,3,17,2,22,10,1,13,4,11,7,23];
% Scp.FlowData.Rounds = [23];

Scp.FlowData.update_FlowData();
Scp.FlowData.Tasks

%% Tree
Scp.FlowData.FlowGroups = {'D','EF'};
Scp.FlowData.Protocols = {'Strip','Hybe'};
Scp.FlowData.ImageProtocols = {'Strip','Hybe'};
Scp.FlowData.Rounds = [10,25,19,20,100,12];
Scp.FlowData.update_FlowData();
% Scp.FlowData.Tasks
tube_order = cell(25,1);
imaging_order = cell(25,1);
ticker = 1;
for i=1:length(Scp.FlowData.Tasks)
    if ~isempty(Scp.FlowData.Tasks{i,1})
        current_name = Scp.FlowData.Tasks{i,1};
        if strcmp(Scp.FlowData.Tasks{i,3},Scp.FlowData.FlowGroups{1})
            if strcmp(current_name,'12')
                imaging_name = [current_name,'Readout3nM_R'];
            else
                imaging_name = [current_name,'Readout_R'];
            end
        else
            if strcmp(current_name,'12')
                imaging_name = [current_name,'Readout10nM_R'];
            else
                imaging_name = [current_name,'Super_R'];
            end
        end

        if contains(imaging_name,'10Super')
            imaging_name = '10Readout_R';
        elseif contains(imaging_name,'100Readout')
            imaging_name = '100Super_R';
        end

        if any(cellfun(@(x) isequal(x, imaging_name), imaging_order))
            new_name = find(cellfun(@(x) isequal(x, imaging_name), imaging_order));
        else
            new_name = ticker;
            tube_order{new_name} = current_name;

            imaging_order{new_name} = imaging_name;
            ticker = ticker + 1;
        end
        Scp.FlowData.Tasks{i,1} = [int2str(new_name),'+20&WBuffer'];
        Scp.FlowData.Tasks{i+1,4} = imaging_name;
    end
end
view = cell(length(imaging_order),3);
for i=1:length(imaging_order)
    view{i,1} = i;
end
view(:,2) = tube_order;
view(:,3) = imaging_order;

 % Which Hybes should be in which tubes
Task1 = Scp.FlowData.Tasks;
% %%
% skip_first_flow=false; % added to fix matlab crashes when the flow was already done 
% for i=1:size(Scp.FlowData.Tasks,1)
%     Scp.FlowData.current_idx = i;
%     % FLOW
%     if skip_first_flow
%         skip_first_flow = false;
%     else
%         Scp.FlowData.flow(Scp);
%     end
%     % IMAGE
%     for c = 1:length(Scp.FlowData.image_wells)
%         coverslip = Scp.FlowData.image_wells(c);
%         Scp.Pos = Scp.Pos.load([coverslip]);
%         Scp.AF = Scp.AF.load([coverslip]);
%         % Update AutoFocus
% %         Scp.AF.optimize_speed = false;
%         Scp.AF = Scp.AF.updateZ(Scp);
%         % Image
%         Scp.AutoFocusType='hardware';
%         Scp.acquire(Scp.FlowData.AcqData, ...
%             'baseacqname',[Scp.FlowData.image_protocol,Scp.FlowData.image_other])
%         Scp.Pos.save
%         Scp.AF.save
%     end
% end
% PolyT
Scp.FlowData.FlowGroups = {'A','C'};
Scp.FlowData.Protocols = {'Strip','Hybe'};
Scp.FlowData.ImageProtocols = {'Strip','Hybe'};
Scp.FlowData.Rounds = [10,25,19,20,100];
Scp.FlowData.update_FlowData();
% Scp.FlowData.Tasks
tube_order = cell(25,1);
imaging_order = cell(25,1);
starting_ticker = ticker;
for i=1:length(Scp.FlowData.Tasks)
    if ~isempty(Scp.FlowData.Tasks{i,1})
        current_name = Scp.FlowData.Tasks{i,1};
        if strcmp(Scp.FlowData.Tasks{i,3},Scp.FlowData.FlowGroups{1})
            if strcmp(current_name,'12')
                imaging_name = [current_name,'Readout3nM_D'];
            else
                imaging_name = [current_name,'Readout_D'];
            end
        else
            if strcmp(current_name,'12')
                imaging_name = [current_name,'Readout10nM_D'];
            else
                imaging_name = [current_name,'Super_D'];
            end
        end

        if contains(imaging_name,'10Super')
            imaging_name = '10Readout_D';
        elseif contains(imaging_name,'100Readout')
            imaging_name = '100Super_D';
        end

        if any(cellfun(@(x) isequal(x, imaging_name), imaging_order))
            new_name = find(cellfun(@(x) isequal(x, imaging_name), imaging_order));
        else
            new_name = ticker;
            tube_order{new_name} = current_name;

            imaging_order{new_name} = imaging_name;
            ticker = ticker + 1;
        end
        Scp.FlowData.Tasks{i,1} = [int2str(new_name),'+20&WBuffer2'];
        Scp.FlowData.Tasks{i+1,4} = imaging_name;
    end
end
% view = cell(length(imaging_order),3);
% for i=1:length(imaging_order)
%     view{i,1} = i;
% end
view(starting_ticker:end,2) = tube_order(starting_ticker:length(view));
view(starting_ticker:end,3) = imaging_order(starting_ticker:length(view));
% Add another row to the view cell array
view{19, 2} = '8';  % Add '8' to the second column
view{19, 3} = '8Readout_D';  % Add '8Readout_D' to the third column
view{20, 2} = '19';  % Add '19' to the second column
view{20, 3} = '19Super_10nM_R';  % Add '19Super_10nM_R' to the third column
view{21, 2} = '20_10nM';  % Add '20' to the second column
view{21, 3} = '20Super_10nM_R';  % Add '20Super_10nM_R' to the third column
view % Which Hybes should be in which tubes
Task2 = Scp.FlowData.Tasks;
Scp.FlowData.Tasks = vertcat(Task1,Task2);
Scp.FlowData.Tasks
%%
skip_first_flow=false; % added to fix matlab crashes when the flow was already done 
for i=2:size(Scp.FlowData.Tasks,1)
    Scp.FlowData.current_idx = i;
    % FLOW
    if skip_first_flow
        skip_first_flow = false;
    else
        Scp.FlowData.flow(Scp);
    end
    % IMAGE
    for c = 1:length(Scp.FlowData.image_wells)
        coverslip = Scp.FlowData.image_wells(c);
        Scp.Pos = Scp.Pos.load([coverslip]);
        Scp.AF = Scp.AF.load([coverslip]);
        % Update AutoFocus
%         Scp.AF.optimize_speed = false;
        Scp.AF = Scp.AF.updateZ(Scp);
        % Image
        Scp.AutoFocusType='hardware';
        Scp.acquire(Scp.FlowData.AcqData, ...
            'baseacqname',[Scp.FlowData.image_protocol,Scp.FlowData.image_other])
        Scp.Pos.save
        Scp.AF.save
    end
end
%% Tree_hybetime_test
Scp.FlowData.FlowGroups = {'D','E'};
Scp.FlowData.Protocols = {'Strip','Hybe'};
Scp.FlowData.ImageProtocols = {'Strip','Hybe'};
Scp.FlowData.Rounds = [19];
Scp.FlowData.update_FlowData();
Scp.FlowData.Tasks
for i=1:5
    if ~isempty(Scp.FlowData.Tasks{i,1})
        current_name = Scp.FlowData.Tasks{i,1};
        if strcmp(Scp.FlowData.Tasks{i,3},Scp.FlowData.FlowGroups{1})
            imaging_name = [current_name,'Readout_R'];
        else
            imaging_name = [current_name,'Super_R'];
        end

        if strcmp(Scp.FlowData.Tasks{i,3},'D')
            new_name = '14';
        else
            new_name = '15';
        end

        if strcmp(Scp.FlowData.Tasks{i,2}, 'Strip')
            Scp.FlowData.Tasks{i,1} = [new_name, '+20&WBuffer'];
        else
            Scp.FlowData.Tasks{i,1} = [new_name, '+60&WBuffer'];
        end
        Scp.FlowData.Tasks{i+1,4} = imaging_name;
    end
end

Task1 = Scp.FlowData.Tasks;

% PolyT
Scp.FlowData.FlowGroups = {'A','C'};
Scp.FlowData.Protocols = {'Strip','Hybe'};
Scp.FlowData.ImageProtocols = {'Strip','Hybe'};
Scp.FlowData.Rounds = 8;
Scp.FlowData.update_FlowData();
% Scp.FlowData.Tasks
tube_order = cell(25,1);
imaging_order = cell(25,1);
for i=1:5
    if ~isempty(Scp.FlowData.Tasks{i,1})
        current_name = Scp.FlowData.Tasks{i,1};
        if strcmp(Scp.FlowData.Tasks{i,3},Scp.FlowData.FlowGroups{1})
            imaging_name = [current_name,'Readout_D'];
        else
            imaging_name = [current_name,'Super_D'];
        end

        if contains(imaging_name,'8Super')
            imaging_name = '8Readout_D';
        end

        Scp.FlowData.Tasks{i,1} = '19+20&WBuffer2';
        Scp.FlowData.Tasks{i+1,4} = imaging_name;
    end
end

view % Which Hybes should be in which tubes
Task2 = Scp.FlowData.Tasks;
Scp.FlowData.Tasks = vertcat(Task1,Task2);
Scp.FlowData.Tasks
%% Tree_spconc_test
Scp.FlowData.FlowGroups = {'D','E'};
Scp.FlowData.Protocols = {'Strip','Hybe'};
Scp.FlowData.ImageProtocols = {'Strip','Hybe'};
Scp.FlowData.Rounds = [19,20];
Scp.FlowData.update_FlowData();
Scp.FlowData.Tasks
for i=1:length(Scp.FlowData.Tasks)
    if ~isempty(Scp.FlowData.Tasks{i,1})
        current_name = Scp.FlowData.Tasks{i,1};
        
        imaging_name = [current_name,'_10nM_Super_R'];

        if strcmp(imaging_name,'19_10nM_Super_R')
            new_name = '20';
        else
            new_name = '21';
        end

        Scp.FlowData.Tasks{i,1} = [new_name,'+20&WBuffer'];
        Scp.FlowData.Tasks{i+1,4} = imaging_name;
    end

    
end

Task1 = Scp.FlowData.Tasks;

view % Which Hybes should be in which tubes
Scp.FlowData.Tasks = Task1;
Scp.FlowData.Tasks
%%
skip_first_flow=false; % added to fix matlab crashes when the flow was already done 
for i=1:size(Scp.FlowData.Tasks,1)
    Scp.FlowData.current_idx = i;
    % FLOW
    if skip_first_flow
        skip_first_flow = false;
    else
        Scp.FlowData.flow(Scp);
    end
    % IMAGE
    for c = 1:length(Scp.FlowData.image_wells)
        coverslip = Scp.FlowData.image_wells(c);
        Scp.Pos = Scp.Pos.load([coverslip]);
        Scp.AF = Scp.AF.load([coverslip]);
        % Update AutoFocus
%         Scp.AF.optimize_speed = false;
        Scp.AF = Scp.AF.updateZ(Scp);
        % Image
        Scp.AutoFocusType='hardware';
        Scp.acquire(Scp.FlowData.AcqData, ...
            'baseacqname',[Scp.FlowData.image_protocol,Scp.FlowData.image_other])
        Scp.Pos.save
        Scp.AF.save
    end
end
%%
















%%
command = Scp.FlowData.build_command('Valve',['ABCDEF'],'TBS+3');
Scp.FlowData.send_command(command,Scp)
Scp.FlowData.wait_until_available()
%% Flush
command = Scp.FlowData.build_command('ReverseFlush',[''],'TBS+5');
Scp.FlowData.send_command(command,Scp)
Scp.FlowData.wait_until_available()

command = Scp.FlowData.build_command('Prime',[''],'TBS+5');
Scp.FlowData.send_command(command,Scp)
Scp.FlowData.wait_until_available()

command = Scp.FlowData.build_command('ReverseFlush',[''],'Air+3');
Scp.FlowData.send_command(command,Scp)
Scp.FlowData.wait_until_available()

command = Scp.FlowData.build_command('ReverseFlush',[''],'Air+3');
Scp.FlowData.send_command(command,Scp)
Scp.FlowData.wait_until_available()
%%
command = Scp.FlowData.build_command('Hybe',['D' ],'1+20&WBuffer2!');
Scp.FlowData.send_command(command,Scp)
Scp.FlowData.wait_until_available()

%%
Scp.FlowData.Rounds = [{'25+20&WBuffer2'}];
Scp.FlowData.update_FlowData();
Scp.FlowData.Tasks
%%
Scp.FlowData.Rounds = [25];
Scp.FlowData.update_FlowData();
Scp.FlowData.Tasks