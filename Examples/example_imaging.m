%% Imaging
Scp = NinjaScope;

%% Set up: username, project name and dataset
Scp.Username = 'Zach'; % your username!
Scp.Project = 'dredFISH'; % the project this dataset correspond to
Scp.Dataset = 'Dapi_100um.E'; % the name of this specific image dataset - i.e. this experiment.
Scp.ExperimentDescription = ['500 ug DPNMF Probes/brain'];

%% Setup Imaging Parameters
% For Data Collection
Scp.FlowData.AcqData = AcquisitionData;
Scp.FlowData.AcqData(1).Channel = 'DeepBlue';
Scp.FlowData.AcqData(1).Exposure = 10; %
Scp.FlowData.AcqData(1).Delay = 10; %
% Scp.FlowData.AcqData(2).Channel = 'FarRed';
% Scp.FlowData.AcqData(2).Exposure = 2500; %
% Scp.FlowData.AcqData(2).Delay = 10; %

% For Preview
preview_acqdata = AcquisitionData;
preview_acqdata(1).Channel = 'DeepBlue';
preview_acqdata(1).Exposure = 5; %
preview_acqdata(1).Delay = 10; %

%%
Scp.FlowData.start_Gui()
Scp.FlowData.start_Fluidics()

%% Setup Fluidics Parameters
Scp.FlowData.Rounds = [25];
Scp.FlowData.FlowGroups = {'E'};
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
    Scp.createPositions('spacing',0.9, ...
        'sitesshape','circle', ...
        'wells',Wells,'optimize',true)
    Scp.Pos.Well = coverslip;
    Scp.filterPositionsByDraw('acq_name',position_acq_names{c},'acqdata',Scp.FlowData.AcqData)
    Scp.Pos.save
end
%% Setup AutoFocus and check Focus
for c=1:Scp.FlowData.n_coverslips
    coverslip = Scp.FlowData.coverslips{c};
    Scp.Pos = Scp.Pos.load([coverslip]);
    Scp.AF = ContrastPlaneFocus;
    Scp.AF.Well = coverslip;
    Scp.AF = Scp.AF.createPostions(Scp.Pos);
    Scp.AF.save;
    Scp.AutoFocusType='none';
    Scp.AF = Scp.AF.calculateZ(Scp);
    Scp.Pos = Scp.Pos.load([coverslip]);
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


%% Image Background
Scp.AutoFocusType='hardware';
for i=[2] 
    Scp.FlowData.current_idx = i;
    % FLOW
    Scp.FlowData.flow(Scp);
    % IMAGE
    for c = 1:length(Scp.FlowData.image_wells)
        coverslip = Scp.FlowData.coverslips{c};
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
%% Manual Hybe

%% Image Hybe
Scp.AutoFocusType='hardware';
for i=[4]
    Scp.FlowData.current_idx = i;
    % FLOW
    Scp.FlowData.flow(Scp);
    % IMAGE
    for c = 1:length(Scp.FlowData.image_wells)
        coverslip = Scp.FlowData.coverslips{c};
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
