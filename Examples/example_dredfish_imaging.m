%% Initialize Scope +++++++++++++++++++
Scp = OrangeScope;
%% Double check that 000 is the top left corner of the scope and Lower Limit
% Scp.Z = 0;
% Scp.XY = [0 0];
%% Set up: username, project name and dataset +++++++++++++++++++
Scp.Username = 'Zach'; % your username!
Scp.Project = 'dredFISH'; % the project this dataset correspond to
Scp.Dataset = ['Tree20um47C500M1H3APre2SDS100ug47C50F18H50F1HPost2SDS47C-ctrl.A_48HPre1HPost.B_12HPre24HPost.C_ctrl.D_48HPre1HPost.E_12hrPre24HPost.F']; % the name of this specific image dataset - i.e. this experiment.
%Scp.Dataset = ['Tree20um37C500M3A2SDS100ug50F50F1H2SDS37C1H-M12H12Hr.A_M1H60Hr.B_M1H60Hr.C_M0H12Hr.D_M1H60Hr.E_M12H60Hr.F']; % the name of this specific image dataset - i.e. this experiment.
% Scp.Dataset = ['UnclearedTree20um47C100ug50F60H-MF31.A']; % the name of this specific image dataset - i.e. this experiment.
Scp.Dataset_Path = fullfile(Scp.basePath,Scp.Username,Scp.Project,[Scp.Dataset '_' datestr(floor(Scp.TimeStamp{1,2}),'yyyymmmdd')]);
% IF MATLAB CRASH
Scp.Dataset_Path = fullfile(Scp.basePath,Scp.Username,Scp.Project,[Scp.Dataset '_' '2024Mar07']); 
Scp.ExperimentDescription = [''];
%% Setup Imaging Parameters +++++++++++++++++++
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
Scp.FlowData.FlowGroups = {'ABC','FED'};
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
%% If you want to image a larger area in the well to create positions 
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

%% Manually Find Focus for each position
for c=1:Scp.FlowData.n_coverslips
    Scp.AutoFocusType='none';
    coverslip = Scp.FlowData.coverslips{c};
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
for c=1:Scp.FlowData.n_coverslips
    Scp.AutoFocusType='none';
    coverslip = Scp.FlowData.coverslips{c};
    Scp.AF = Scp.AF.load([coverslip]);
    Scp.AF.window = 200;
    Scp.AF.dZ = 5;
    tic
    Scp.AF = Scp.AF.setRelativeReferencePosition(Scp);
    Scp.Z
    toc
    Scp.AF.save
end
%% Check Focus
for c=1:Scp.FlowData.n_coverslips
    coverslip = Scp.FlowData.coverslips{c};
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

%% Start Fluidics +++++++++++++++++++
Scp.FlowData.start_Gui()
Scp.FlowData.start_Fluidics()
%% +++++++++++++++++++
Scp.FlowData.FlowGroups = {'ABC','FED'};
Scp.FlowData.Protocols = {'Strip','Hybe'};
Scp.FlowData.ImageProtocols = {'Strip','Hybe'};
Scp.FlowData.Rounds = [25,24,27,26,28,18,8,21,9,12,16,19,20,5,6,1,14,7,15,11,10,4,2,3,17,22,13,23];
Scp.FlowData.update_FlowData();
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

%% imaging a single well in case of matlab crash
Scp.AutoFocusType='hardware';
Scp.FlowData.current_idx = 93; %+++++++++
c = 3; % +++++++++
coverslip = Scp.FlowData.image_wells(c);
Scp.Pos = Scp.Pos.load([coverslip]);
Scp.AF = Scp.AF.load([coverslip]);
Scp.AF = Scp.AF.updateZ(Scp);
% Image
Scp.acquire(Scp.FlowData.AcqData, ...
    'baseacqname',[Scp.FlowData.image_protocol,Scp.FlowData.image_other])
Scp.Pos.save
Scp.AF.save
%%











%% 
% %% Poly T On the microscope
% 
% Scp.FlowData.Rounds = [25];
% Scp.FlowData.update_FlowData();
% Scp.FlowData.Tasks
% 
% command = Scp.FlowData.build_command('EncodingHybe',Scp.FlowData.all_wells,'28+60');
% Scp.FlowData.send_command(command,Scp);
% %%
% Scp.FlowData.wait_until_available()
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

% % Scp.FlowData.Rounds = [25,27,26,12,16,20,8,5,18,24,9,6,15,14,19,3,17,2,21,22,10,1,13,4,11,7,23]; % H->L Mean Smartseq row norm
% % Scp.FlowData.Rounds = [25,27,26,12,16,20,8,18,5,24,9,6,15,14,19,3,17,21,2,22,10,1,13,4,11,23,7] % H->L Mean Smartseq no norm
% % Scp.FlowData.Rounds = [25,27,26,12,16,20,5,8,18,24,9,3,6,14,2,15,13,17,22,19,10,1,4,21,11,7,23] % H->L 95th Smartseq row norm
% % Scp.FlowData.Rounds = [25,27,26,12,16,20,18,8,5,24,9,6,14,15,3,2,19,17,13,22,1,10,21,4,11,7,23] % H->L 95th Smartseq no norm
% % Cell Type Averages
% % Scp.FlowData.Rounds = [25,27,26,12,20,16,8,5,18,24,9,6,14,15,19,21,22,17,23,2,3,10,1,13,4,11,7] % H->L Mean Smartseq row norm 
% % Scp.FlowData.Rounds = [25,27,26,12,20,16,8,5,18,24,9,6,21,23,14,15,19,22,2,17,3,13,1,10,4,11,7] % H->L Mean Smartseq no norm
% % Scp.FlowData.Rounds = [25,27,26,12,16,20,8,5,18,24,9,6,23,14,15,2,22,19,17,21,10,4,1,13,11,3,7] % H->L 95th Smartseq row norm
% % Scp.FlowData.Rounds = [25,27,26,12,16,20,8,18,5,24,9,6,14,23,15,2,22,19,21,17,10,1,4,13,11,3,7] % H->L 95th Smartseq no norm