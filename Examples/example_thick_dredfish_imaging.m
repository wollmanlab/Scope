%% Initialize Scope
Scp = PurpleScope;
%% Double check that 000 is the top left corner of the scope and Lower Limit
% Scp.Z = 0;
% Scp.XY = [0 0];
%% Set up: username, project name and dataset
Scp.Username = 'Zach'; % your username!
Scp.Project = 'thick_dredFISH'; % the project this dataset correspond to
Scp.Dataset = ['stage_test-100um.B_10um.C_100um.E_10um.F']; % the name of this specific image dataset - i.e. this experiment.
Scp.Dataset_Path = fullfile(Scp.basePath,Scp.Username,Scp.Project,[Scp.Dataset '_' datestr(floor(Scp.TimeStamp{1,2}),'yyyymmmdd')]);
% Scp.Dataset_Path = fullfile(Scp.basePath,Scp.Username,Scp.Project,[Scp.Dataset '_' '2023Sep19']);
Scp.ExperimentDescription = [''];
%% Setup Imaging Parameters
% For Data Collection
Scp.FlowData.AcqData = AcquisitionData;
Scp.FlowData.AcqData(1).Channel = 'DeepBlue';
Scp.FlowData.AcqData(1).Exposure = 100; %
Scp.FlowData.AcqData(1).Delay = 10; %
% Scp.FlowData.AcqData(2).Channel = 'FarRed';
% Scp.FlowData.AcqData(2).Exposure = 2500; %
% Scp.FlowData.AcqData(2).Delay = 10; %

% For Preview
preview_acqdata = AcquisitionData;
preview_acqdata(1).Channel = 'DeepBlue';
preview_acqdata(1).Exposure = 100; %
preview_acqdata(1).Delay = 10; %
%%
Scp.FlowData.start_Gui()
Scp.FlowData.start_Fluidics()

%% Setup Fluidics Parameters
Scp.FlowData.Rounds = [0];
Scp.FlowData.FlowGroups = {'BCEF'};
Scp.FlowData.Protocols = {'Strip','Hybe'};
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
    Scp.createPositions('spacing',0.9, ...
        'sitesshape','circle', ...
        'sitesperwell',[30,30], ...
        'wells',Wells,'optimize',true);
    Scp.Pos.Well = coverslip;
%     Scp.XY = mean(Scp.Pos.List)
    disp(coverslip)
    disp(mean(Scp.Pos.List))
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

%% Manually look to where you may want to image
dZ_mins = zeros(Scp.FlowData.n_coverslips,1);
dZ_maxs = zeros(Scp.FlowData.n_coverslips,1);
for c=1:Scp.FlowData.n_coverslips
    coverslip = Scp.FlowData.coverslips{c};
    Scp.Pos = Scp.Pos.load([coverslip]);
    Scp.AF = Scp.AF.load([coverslip]);
    Scp.XY = mean(Scp.Pos.List);
    Scp.AutoFocusType='hardware';
    good_pos = Scp.Pos.Labels(Scp.Pos.Hidden==0);
    Scp.goto(good_pos{1},Scp.Pos);
    Scp.autofocus();
    focus = Scp.Z;
    uiwait(msgbox('Click Okay when at min Z'))
    min_Z = Scp.Z;
    uiwait(msgbox('Click Okay when at max Z'))
    max_Z = Scp.Z;
    dZ_min = min_Z-focus;
    dZ_max = max_Z-focus;
    disp(dZ_min)
    disp(dZ_max)
    dZ_mins(c) = dZ_min;
    dZ_maxs(c) = dZ_max;
end
%% Use Judgement Call
dZ_min = 0;
dZ_max = 100;
dZ_step = 1;
dZ_steps = linspace(dZ_min,dZ_max,ceil((dZ_max-dZ_min)/dZ_step))
%% Collect Data
Scp.FlowData.Rounds = [0];
Scp.FlowData.FlowGroups = {'BCEF'};
Scp.FlowData.Protocols = {'Strip','Hybe'};
Scp.FlowData.update_FlowData();
Scp.FlowData.Tasks
% Scp.AutoFocusType='hardware';
Scp.AutoFocusType='none';

for i=2:2%1:size(Scp.FlowData.Tasks,1)
    Scp.FlowData.current_idx = i;
    % FLOW
    Scp.FlowData.flow(Scp);
    % IMAGE
    for c = 1:length(Scp.FlowData.image_wells)
        coverslip = Scp.FlowData.image_wells(c);
        Scp.Pos = Scp.Pos.load([coverslip]);
%         Scp.AF = Scp.AF.load([coverslip]);
        % Update AutoFocus
%         Scp.AF = Scp.AF.updateZ(Scp);
%         c_idx = strcmp(coverslip,Scp.FlowData.coverslips);
%         dZ_steps = linspace(dZ_mins(c_idx),dZ_maxs(c_idx),ceil((dZ_maxs(c_idx)-dZ_mins(c_idx))/dZ_step));
        Scp.XY = mean(Scp.Pos.List);
        uiwait(msgbox('Click Okay when at Lowest Z'))
        % Image
        if any(strcmp(coverslip,{'F','C'}))
            % No Z Steps
            Scp.acquire(Scp.FlowData.AcqData, ...
                'baseacqname',[Scp.FlowData.image_protocol,Scp.FlowData.image_other])
        else
            % With Z Steps
            Scp.acquire(Scp.FlowData.AcqData, ...
                'baseacqname',[Scp.FlowData.image_protocol,Scp.FlowData.image_other],'dz',dZ_steps)
        end
        Scp.Pos.save
%         Scp.AF.save
    end
end