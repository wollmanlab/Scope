%% Initialize Scope
Scp = RamboScope;
%% Double check that 000 is the top left corner of the scope and Lower Limit
% Scp.Z = 0;
% Scp.XY = [0 0];
%% Set up: username, project name and dataset
Scp.Username = 'Zach'; % your username!
Scp.Project = 'Test'; % the project this dataset correspond to
Scp.Dataset = 'TBI'; % the name of this specific image dataset - i.e. this experiment.
Scp.ExperimentDescription = [''];

%% Setup Imaging Parameters
% For Data Collection
Scp.FlowData.AcqData = AcquisitionData;
Scp.FlowData.AcqData(1).Channel = 'DeepBlue';
Scp.FlowData.AcqData(1).Exposure = 10; %
Scp.FlowData.AcqData(1).Delay = 10; %
Scp.FlowData.AcqData(2).Channel = 'FarRed';
Scp.FlowData.AcqData(2).Exposure = 500; %
Scp.FlowData.AcqData(2).Delay = 10; %

% For Preview
preview_acqdata = AcquisitionData;
preview_acqdata(1).Channel = 'DeepBlue';
preview_acqdata(1).Exposure = 20; %
preview_acqdata(1).Delay = 10; %
%%
Scp.FlowData.start_Gui()
Scp.FlowData.start_Fluidics()

%% Setup Fluidics Parameters
Scp.FlowData.Rounds = [1:18,25];
Scp.FlowData.FlowGroups = {'M'};
Scp.FlowData.Protocols = {'ClosedStripHybeImage'};
Scp.FlowData.update_FlowData();
Scp.FlowData.Tasks
%% Acquire All Wells First Find Focus manually First
Scp.Chamber = Plate('FCS2');
position_acq_names = cell(Scp.FlowData.n_coverslips,1);

Scp.AutoFocusType='none';
for c=1: Scp.FlowData.n_coverslips
    coverslip = Scp.FlowData.coverslips{c};
    Wells = {coverslip};
    % Plate
    Scp.createPositions('spacing',1, ...
        'sitesperwell',[30,30], ...
        'sitesshape','grid', ...
        'wells',Wells,'optimize',true)
    % MM
%     Scp.createPositionFromMM()
    Scp.Pos.Well = coverslip;
    Scp.acquire(preview_acqdata);
    position_acq_names{c} = Scp.getLastAcqname;
    Scp.Pos.save;
end
%% Filter Positions by draw
for c=1:Scp.FlowData.n_coverslips
    coverslip = Scp.FlowData.coverslips{c};
    Scp.Pos.load([coverslip])
    Scp.createPositions('spacing',1, ...
        'sitesperwell',[30,30], ...
        'sitesshape','grid', ...
        'wells',Wells,'optimize',true)
    Scp.Pos.Well = coverslip;
    Scp.filterPositionsByDraw('acq_name',position_acq_names{c},'acqdata',Scp.FlowData.AcqData)
    Scp.Pos.save
end
%% Setup AutoFocus and check Focus
for c=1:Scp.FlowData.n_coverslips
    coverslip = Scp.FlowData.coverslips{c};
    Scp.Pos.load([coverslip])
    Scp.AF = ContrastPlaneFocus;
    Scp.AF.channel = 'DeepBlue';%'AutoFocus';
    Scp.AF.exposure = 10;
    Scp.AF.coarse_window = 50;
    Scp.AF.coarse_dZ = 5;
    Scp.AF.medium_window = 15;
    Scp.AF.medium_dZ = 1;
    Scp.AF.fine_window = 2;
    Scp.AF.fine_dZ = 0.2;
    Scp.AF.Well = coverslip;
    Scp.AF = Scp.AF.createPostions(Scp.Pos);
    Scp.AF.save;
    Scp.AutoFocusType='none';
    Scp.AF = Scp.AF.calculateZ(Scp);
    Scp.Pos.load([coverslip])
    hidden = Scp.Pos.Hidden;
    for i =1:length(Scp.Pos.Labels)
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
%%
dZ_min = -5;
dZ_max = 5;
dZ_step = 0.4;
dZ_steps = linspace(dZ_min,dZ_max,ceil((dZ_max-dZ_min)/dZ_step));

%% Collect Data
Scp.AutoFocusType='hardware';
for i=2:size(Scp.FlowData.Tasks,1)
    Scp.FlowData.current_idx = i;
    % FLOW
    Scp.FlowData.flow(Scp);
    % IMAGE
    for c = 1:length(Scp.FlowData.wells)
        coverslip = Scp.FlowData.coverslips(c);
        Scp.Pos.load([coverslip])
        Scp.AF.load([coverslip])
        % Update AutoFocus
        Scp.AF = Scp.AF.updateZ(Scp);
        % Image
        Scp.acquire(Scp.FlowData.AcqData, ...
            'baseacqname',['Hybe',Scp.FlowData.other], ...
            'dz',dZ_steps)
        Scp.Pos.save
        Scp.AF.save
    end
end
