%% Initialize Scope
Scp = PurpleScope;
%% Double check that 000 is the top left corner of the scope and Lower Limit
% Scp.Z = 0;
% Scp.XY = [0 0];
%% Set up: username, project name and dataset
Scp.Username = 'Thomas'; % your username!
Scp.Project = 'Dendrimer'; % the project this dataset correspond to
Scp.Dataset = ['DissociationTest']; % the name of this specific image dataset - i.e. this experiment.
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
Scp.FlowData.AcqData(2).Exposure = 500; %
Scp.FlowData.AcqData(2).Delay = 10; %

% For Preview
preview_acqdata = AcquisitionData;
preview_acqdata(1).Channel = 'FarRed';
preview_acqdata(1).Exposure = 250; %
preview_acqdata(1).Delay = 50; %
%%
Scp.FlowData.start_Gui()
Scp.FlowData.start_Fluidics()

%% Setup Fluidics Parameters
Scp.FlowData.Rounds = [16, 15];
Scp.FlowData.FlowGroups = {'D'};
Scp.FlowData.Protocols = {'Hybe'};
Scp.FlowData.ImageProtocols = {'Hybe'};
Scp.FlowData.update_FlowData();
Scp.FlowData.Tasks

%% Acquire All Wells First Find Focus manually First
Scp.Chamber = Plate('Underwood6',Scp);
Scp.Chamber.wellSpacingXY = [42500 42500];
position_acq_names = cell(Scp.FlowData.n_coverslips,1);

Scp.AutoFocusType='none';
for c=1:Scp.FlowData.n_coverslips
    coverslip = Scp.FlowData.coverslips{c};
    Wells = {coverslip};
    Scp.createPositionFromMM()
%     Scp.createPositions('spacing',0.9, ...
%         'sitesshape','circle', ...
%         'sitesperwell',[25,25], ...
%         'wells',Wells,'optimize',true)
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
    Scp.AF.channel = 'FarRed'
    Scp.AF.exposure = 500
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


%% Setup Fluidics Parameters
Scp.FlowData.Rounds = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
Scp.FlowData.FlowGroups = {'D'};
Scp.FlowData.Protocols = {'dendbca'};
Scp.FlowData.ImageProtocols = {'dendbca'};
Scp.FlowData.update_FlowData();
Scp.FlowData.Tasks


%% Setup Fluidics Parameters
Scp.FlowData.Rounds = [16, 15];
Scp.FlowData.FlowGroups = {'D'};
Scp.FlowData.Protocols = {'Hybe'};
Scp.FlowData.ImageProtocols = {'Hybe'};
Scp.FlowData.update_FlowData();
Scp.FlowData.Tasks

%%
for i=1:size(Scp.FlowData.Tasks,1)
    Scp.FlowData.current_idx = i;
    % FLOW
    Scp.FlowData.flow(Scp);
    % IMAGE
    for c = 1:length(Scp.FlowData.image_wells)
        coverslip = Scp.FlowData.image_wells(c);
        Scp.Pos = Scp.Pos.load([coverslip]);
        Scp.AF = Scp.AF.load([coverslip]);
        Scp.AF.channel = 'FarRed'
        Scp.AF.exposure = 500
        % Update AutoFocus
        Scp.AF = Scp.AF.updateZ(Scp);
        % Image
        Scp.acquire(Scp.FlowData.AcqData, ...
            'baseacqname',[Scp.FlowData.image_protocol,Scp.FlowData.image_other], ...
            'viewstitched',false)
        Scp.Pos.save
        Scp.AF.save
        
    end
end

%%
Scp.createPositionFromMM
Scp.Pos.save
%% Setup Fluidics Parameters
Scp.FlowData.Rounds = [1,2,3,4,5,6,7,8];
Scp.FlowData.FlowGroups = {'D'};
Scp.FlowData.Protocols = {'blankprotocol'};
Scp.FlowData.ImageProtocols = {'blankprotocol'};
Scp.FlowData.update_FlowData();
Scp.FlowData.Tasks


%%
Scp.AF = NucleiFocus;
Scp.AutoFocusType='none';
for i=2:size(Scp.FlowData.Tasks,1)
    Scp.FlowData.current_idx = i;
    % FLOW
    Scp.FlowData.flow(Scp);
    % IMAGE
    for c = 1:length(Scp.FlowData.image_wells)
        coverslip = Scp.FlowData.image_wells(c);
        Scp.Pos = Scp.Pos.load([coverslip]);
        %Scp.AF = Scp.AF.load([coverslip]);
        %Scp.AF.channel = 'FarRed'
        %Scp.AF.exposure = 500
        % Update AutoFocus
        %Scp.AF = Scp.AF.updateZ(Scp);
        % Image
        Scp.acquire(Scp.FlowData.AcqData, ...
            'baseacqname',[Scp.FlowData.image_protocol,Scp.FlowData.image_other], ...
            'viewstitched',false)
        Scp.Pos.save
        %Scp.AF.save
        pause(60*15)
        
    end
end
%% Setup Fluidics Parameters
Scp.FlowData.Rounds = [1];
Scp.FlowData.FlowGroups = {'CF'};
Scp.FlowData.Protocols = {'dendcycle'};
Scp.FlowData.ImageProtocols = {};
Scp.FlowData.update_FlowData();
Scp.FlowData.Tasks

for i=1:size(Scp.FlowData.Tasks,1)
    Scp.FlowData.current_idx = i;
    % FLOW
    Scp.FlowData.flow(Scp);
    % IMAGE
end

Scp.FlowData.Rounds = [2, 3, 4];
Scp.FlowData.FlowGroups = {'CF'};
Scp.FlowData.Protocols = {'dendbca'};
Scp.FlowData.ImageProtocols = {};
Scp.FlowData.update_FlowData();
Scp.FlowData.Tasks

for i=1:size(Scp.FlowData.Tasks,1)
    Scp.FlowData.current_idx = i;
    % FLOW
    Scp.FlowData.flow(Scp);
    % IMAGE
end

Scp.FlowData.Rounds = [2, 3];
Scp.FlowData.FlowGroups = {'CF'};
Scp.FlowData.Protocols = {'dendcycle'};
Scp.FlowData.ImageProtocols = {};
Scp.FlowData.update_FlowData();
Scp.FlowData.Tasks

for i=1:size(Scp.FlowData.Tasks,1)
    Scp.FlowData.current_idx = i;
    % FLOW
    Scp.FlowData.flow(Scp);
    % IMAGE
end

Scp.FlowData.Rounds = [1];
Scp.FlowData.FlowGroups = {'BCEF'};
Scp.FlowData.Protocols = {'dendcycle'};
Scp.FlowData.ImageProtocols = {};
Scp.FlowData.update_FlowData();
Scp.FlowData.Tasks

for i=1:size(Scp.FlowData.Tasks,1)
    Scp.FlowData.current_idx = i;
    % FLOW
    Scp.FlowData.flow(Scp);
    % IMAGE
end

Scp.FlowData.Rounds = [2, 3, 4];
Scp.FlowData.FlowGroups = {'BCEF'};
Scp.FlowData.Protocols = {'dendbca'};
Scp.FlowData.ImageProtocols = {};
Scp.FlowData.update_FlowData();
Scp.FlowData.Tasks

for i=1:size(Scp.FlowData.Tasks,1)
    Scp.FlowData.current_idx = i;
    % FLOW
    Scp.FlowData.flow(Scp);
    % IMAGE
end

Scp.FlowData.Rounds = [2, 3];
Scp.FlowData.FlowGroups = {'BCEF'};
Scp.FlowData.Protocols = {'dendcycle'};
Scp.FlowData.ImageProtocols = {};
Scp.FlowData.update_FlowData();
Scp.FlowData.Tasks

for i=1:size(Scp.FlowData.Tasks,1)
    Scp.FlowData.current_idx = i;
    % FLOW
    Scp.FlowData.flow(Scp);
    % IMAGE
end

Scp.FlowData.Rounds = [1];
Scp.FlowData.FlowGroups = {'ABCDEF'};
Scp.FlowData.Protocols = {'dendcycle'};
Scp.FlowData.ImageProtocols = {};
Scp.FlowData.update_FlowData();
Scp.FlowData.Tasks

for i=1:size(Scp.FlowData.Tasks,1)
    Scp.FlowData.current_idx = i;
    % FLOW
    Scp.FlowData.flow(Scp);
    % IMAGE
end

Scp.FlowData.Rounds = [2];
Scp.FlowData.FlowGroups = {'ABCDEF'};
Scp.FlowData.Protocols = {'dendbca'};
Scp.FlowData.ImageProtocols = {};
Scp.FlowData.update_FlowData();
Scp.FlowData.Tasks

for i=1:size(Scp.FlowData.Tasks,1)
    Scp.FlowData.current_idx = i;
    % FLOW
    Scp.FlowData.flow(Scp);
    % IMAGE
end