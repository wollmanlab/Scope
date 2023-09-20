%% Initialize Scope
Scp = OrangeScope;
%% Double check that 000 is the top left corner of the scope and Lower Limit
% Scp.Z = 0;
% Scp.XY = [0 0];
%% Set up: username, project name and dataset
Scp.Username = 'Zach'; % your username!
Scp.Project = 'dredFISH'; % the project this dataset correspond to
Scp.Dataset = ['250T250M47C30F4H.A_1000T250M47C30F4H.B_250T250M47C30F4H.D_1000T250M47C30F4H.E']; % the name of this specific image dataset - i.e. this experiment.
Scp.Dataset_Path = fullfile(Scp.basePath,Scp.Username,Scp.Project,[Scp.Dataset '_' datestr(floor(Scp.TimeStamp{1,2}),'yyyymmmdd')]);
% Scp.Dataset_Path = fullfile(Scp.basePath,Scp.Username,Scp.Project,[Scp.Dataset '_' '2023Sep19']);
Scp.ExperimentDescription = [''];
%% Setup Imaging Parameters
% For Data Collection
Scp.FlowData.AcqData = AcquisitionData;
Scp.FlowData.AcqData(1).Channel = 'DeepBlue';
Scp.FlowData.AcqData(1).Exposure = 50; %
Scp.FlowData.AcqData(1).Delay = 10; %
Scp.FlowData.AcqData(2).Channel = 'FarRed';
Scp.FlowData.AcqData(2).Exposure = 2500; %
Scp.FlowData.AcqData(2).Delay = 10; %

% For Preview
preview_acqdata = AcquisitionData;
preview_acqdata(1).Channel = 'DeepBlue';
preview_acqdata(1).Exposure = 50; %
preview_acqdata(1).Delay = 50; %
%%
Scp.FlowData.start_Gui()
Scp.FlowData.start_Fluidics()

%% Setup Fluidics Parameters
Scp.FlowData.Rounds = [0];
Scp.FlowData.FlowGroups = {'ABCDEF'};
Scp.FlowData.Protocols = {'Strip','Hybe'};
Scp.FlowData.update_FlowData();
Scp.FlowData.Tasks
%% Acquire All Wells First Find Focus manually First
Scp.Chamber = Plate('Underwood6');
position_acq_names = cell(Scp.FlowData.n_coverslips,1);

Scp.AutoFocusType='none';
for c=1:Scp.FlowData.n_coverslips
    coverslip = Scp.FlowData.coverslips{c};
    Wells = {coverslip};
    Scp.createPositions('spacing',0.9, ...
        'sitesshape','circle', ...
        'sitesperwell',[25,25], ...
        'wells',Wells,'optimize',true)
    Scp.Pos.Well = coverslip;
    Scp.acquire(preview_acqdata);
    position_acq_names{c} = Scp.getLastAcqname;
    Scp.Pos.save;
end
%% Filter Positions by draw
for c=1:Scp.FlowData.n_coverslips
    coverslip = Scp.FlowData.coverslips{c};
    Scp.Pos = Scp.Pos.load([coverslip]);
    Wells = {coverslip};
    Scp.Pos.Well = coverslip;
    Scp.filterPositionsByDraw()
    Scp.Pos.save
end
%% Setup AutoFocus and check Focus
for c=1:Scp.FlowData.n_coverslips
    coverslip = Scp.FlowData.coverslips{c};
    Scp.Pos = Scp.Pos.load([coverslip]);
    Scp.AF = ContrastPlaneFocus;
    Scp.AF.use_groups = true;
    Scp.AF.Well = coverslip;
    Scp.AF = Scp.AF.createPostions(Scp.Pos);
    Scp.AF.save;
    Scp.AutoFocusType='none';
    Scp.AF = Scp.AF.calculateZ(Scp);
    Scp.Pos = Scp.Pos.load([coverslip]);
    hidden = Scp.Pos.Hidden;
    for i=1:length(Scp.Pos.Labels)
        if contains(Scp.Pos.Labels{i},'Well')
            hidden(i) = 0;
        end
    end
    Scp.Pos.Hidden = hidden;
    Scp.AutoFocusType='hardware';
    Scp.acquire(preview_acqdata)
    Scp.Pos.save
    Scp.AF.save
end
%% Collect Data
Scp.FlowData.Rounds = [26,27,17,7,15,3,22,11,6,10,13,2,4,1,5,23,14,20,9,16,21,24,8,18,19,12,25];
Scp.FlowData.FlowGroups = {'ABDE'};
Scp.FlowData.Protocols = {'Strip','Hybe'};
Scp.FlowData.update_FlowData();
Scp.FlowData.Tasks
Scp.AutoFocusType='hardware';
% Scp.FlowData.current_idx = i;
% for c = 1:length(Scp.FlowData.image_wells)
%     coverslip = Scp.FlowData.image_wells(c);
%     Scp.Pos = Scp.Pos.load([coverslip]);
%     Scp.AF = Scp.AF.load([coverslip]);
%     Scp.AF.percentage_thresh = 25;
%     % Update AutoFocus
%     Scp.AF = Scp.AF.updateZ(Scp);
%     % Image
%     Scp.acquire(Scp.FlowData.AcqData, ...
%         'baseacqname',[Scp.FlowData.image_protocol,Scp.FlowData.image_other])
%     Scp.Pos.save
%     Scp.AF.save
% end

% Scp.FlowData.current_idx = i;
% % FLOW
% Scp.FlowData.flow(Scp);

for i=1:size(Scp.FlowData.Tasks,1)
    Scp.FlowData.current_idx = i;
    % FLOW
    Scp.FlowData.flow(Scp);
    % IMAGE
    for c = 1:length(Scp.FlowData.image_wells)
        coverslip = Scp.FlowData.image_wells(c);
        Scp.Pos = Scp.Pos.load([coverslip]);
        Scp.AF = Scp.AF.load([coverslip]);
        % Update AutoFocus
        Scp.AF = Scp.AF.updateZ(Scp);
        % Image
        Scp.acquire(Scp.FlowData.AcqData, ...
            'baseacqname',[Scp.FlowData.image_protocol,Scp.FlowData.image_other])
        Scp.Pos.save
        Scp.AF.save
    end
end