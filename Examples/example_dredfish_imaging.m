%% Initialize Scope
Scp = RamboScope;
%% Double check that 000 is the top left corner of the scope and Lower Limit
% Scp.Z = 0;
% Scp.XY = [0 0];
%% Set up: username, project name and dataset
Scp.Username = 'Zach'; % your username!
Scp.Project = 'Test'; % the project this dataset correspond to
Scp.Dataset = 'Test'; % the name of this specific image dataset - i.e. this experiment.
Scp.ExperimentDescription = [''];

%% Setup Imaging Parameters
% For Data Collection
Scp.FlowData.AcqData = AcquisitionData;
Scp.FlowData.AcqData(1).Channel = 'DeepBlue';
Scp.FlowData.AcqData(1).Exposure = 10; %
Scp.FlowData.AcqData(1).Delay = 10; %
Scp.FlowData.AcqData(2).Channel = 'FarRed';
Scp.FlowData.AcqData(2).Exposure = 2500; %
Scp.FlowData.AcqData(2).Delay = 10; %

% For Preview
preview_acqdata = AcquisitionData;
preview_acqdata(1).Channel = 'DeepBlue';
preview_acqdata(1).Exposure = 10; %
preview_acqdata(1).Delay = 10; %

%% Setup Fluidics Parameters
Scp.FlowData.Rounds = [1:25];
Scp.FlowData.FlowGroups = {'ABC'};
Scp.FlowData.Tasks
%% Acquire All Wells First Find Focus manually First
Scp.Chamber = Plate('Underwood6');
position_acq_names = cell(n_coverslips,1);

Scp.AutoFocusType='none';
for c=1:FlowData.n_coverslips
    coverslip = FlowData.coverslips{c};
    Wells = {coverslip};
    Scp.createPositions('spacing',0.9, ...
        'sitesshape','circle', ...
        'wells',Wells,'optimize',true)
    Scp.acquire(preview_acqdata);
    position_acq_names{c} = Scp.getLastAcqname;
    Scp.Pos.save;
end
%% Filter Positions by draw
for c=1:FlowData.n_coverslips
    coverslip = FlowData.coverslips{c};
    Scp.Pos.load(['Well',coverslip])
    Scp.filterPositionsByDraw('acq_name',position_acq_names{c})
    Scp.Pos.save
    Scp.AF = ContrastPlaneFocus;
    Scp.AF.Pos = Scp.Pos;
    AF.save;
end
%% Setup AutoFocus and check Focus
for c=1:FlowData.n_coverslips
    coverslip = FlowData.coverslips{c};
    Scp.AF.load(['Well',coverslip])
    Scp.AutoFocusType='none';
    Scp.AF = Scp.AF.calculateZ(Scp,'filter',true);
    Scp.Pos.load(['Well',coverslip])
    Scp.AutoFocusType='hardware';
    Scp.acquire(preview_acqdata)
    Scp.Pos.save
    Scp.AF.save
end
%% Collect Data
Scp.AutoFocusType='hardware';
for i=1:size(FlowData.Tasks,1)
    FlowData.current_idx = i;
    % FLOW
    FlowData.flow(Scp);
    % IMAGE
    for c = 1:length(FlowData.wells)
        coverslip = FlowData.coverslips(c);
        Scp.Pos.load(['Well',coverslip])
        Scp.AF.load(['Well',coverslip])
        % Update AutoFocus
        Scp.AF = Scp.AF.updateZ(Scp);
        % Image
        Scp.acquire(Scp.FlowData.AcqData, 'baseacqname',[FlowData.protocol,FlowData.other])
        Scp.Pos.save
        Scp.AF.save
    end
end
