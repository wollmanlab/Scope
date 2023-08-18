%% Initialize Scope
Scp = OrangeScope;
%% Double check that 000 is the top left corner of the scope and Lower Limit
% Scp.Z = 0;
% Scp.XY = [0 0];
%% Set up: username, project name and dataset
Scp.Username = 'Zach'; % your username!
Scp.Project = 'dredFISH'; % the project this dataset correspond to
Scp.Dataset = ['Tree100(M).A_Tree300(M).A_Tree100(P).D_Tree300(P).E']; % the name of this specific image dataset - i.e. this experiment.
Scp.ExperimentDescription = ['500 ug DPNMF Probes/brain'];
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
Scp.FlowData.Rounds = [25,23,22,4,11,13,12,3,7,21,17,2,10,1,15,19,6,9,14,18,20,24,8,5,16,21];
% Scp.FlowData.Rounds = [19,6,9,14,18,20,24,8,5,16,21];
Scp.FlowData.FlowGroups = {'ABDE'};
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
        'sitesperwell',[20,20], ...
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
        'sitesperwell',[20,20], ...
        'wells',Wells,'optimize',true)
    Scp.Pos.Well = coverslip;
    Scp.filterPositionsByDraw('acq_name',position_acq_names{c},'acqdata',preview_acqdata)
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
%% Collect Data
% Scp.FlowData.Rounds = [25,23,22,4,11,13,12,3,7,21,17,2,10,1,15,19,6,9,14,18,20,24,8,5,16,21];
% Scp.FlowData.Rounds = [25,16,17,2,15,23,5,4,20,22,3,10,13,6,14,12,11,24,1,7,8,21,19,18,9];
Scp.FlowData.Rounds = [25,16,10,22,23,3,17,11,13,4,2,15,6,20,1,21,14,5,7,19,24,12,18,8,9];
Scp.FlowData.FlowGroups = {'ABDE'};
Scp.FlowData.Protocols = {'Strip','Hybe'};
Scp.FlowData.update_FlowData();
Scp.FlowData.Tasks
Scp.AutoFocusType='hardware';
for i=71:size(Scp.FlowData.Tasks,1)
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
%%
% %%
% Scp.FlowData.Rounds = [1];
% Scp.FlowData.FlowGroups = {'ADF'};
% Scp.FlowData.Protocols = {'Strip','Hybe'};
% Scp.FlowData.ImageProtocols = {'Strip','Hybe'};
% Scp.FlowData.update_FlowData();
% Scp.FlowData.Tasks
% Scp.AutoFocusType='hardware';
% for i=4:4%:size(Scp.FlowData.Tasks,1)
%     Scp.FlowData.current_idx = i;
%     % FLOW
%     Scp.FlowData.flow(Scp);
%     % IMAGE
%     for c = 1:length(Scp.FlowData.image_wells)
%         coverslip = Scp.FlowData.coverslips{c};
%         Scp.Pos = Scp.Pos.load([coverslip]);
%         Scp.AF = Scp.AF.load([coverslip]);
%         % Update AutoFocus
% %         Scp.AF = Scp.AF.updateZ(Scp);
%         % Image
%         Scp.acquire(Scp.FlowData.AcqData, ...
%             'baseacqname',[Scp.FlowData.image_protocol,Scp.FlowData.image_other])
%         Scp.Pos.save
%         Scp.AF.save
%     end
% end
% %
% Scp.FlowData.Rounds = [25];
% Scp.FlowData.FlowGroups = {'BEC'};
% Scp.FlowData.Protocols = {'Strip','Hybe'};
% Scp.FlowData.ImageProtocols = {'Strip','Hybe'};
% Scp.FlowData.update_FlowData();
% Scp.FlowData.Tasks
% Scp.AutoFocusType='hardware';
% for i=4:4%:size(Scp.FlowData.Tasks,1)
%     Scp.FlowData.current_idx = i;
%     % FLOW
%     Scp.FlowData.flow(Scp);
%     % IMAGE
%     for c = 1:length(Scp.FlowData.image_wells)
%         coverslip = Scp.FlowData.coverslips{c};
%         Scp.Pos = Scp.Pos.load([coverslip]);
%         Scp.AF = Scp.AF.load([coverslip]);
%         % Update AutoFocus
% %         Scp.AF = Scp.AF.updateZ(Scp);
%         % Image
%         Scp.acquire(Scp.FlowData.AcqData, ...
%             'baseacqname',[Scp.FlowData.image_protocol,Scp.FlowData.image_other])
%         Scp.Pos.save
%         Scp.AF.save
%     end
% end
% %%
% Scp.FlowData.Rounds = [25];
% Scp.FlowData.FlowGroups = {'C'};
% Scp.FlowData.Protocols = {'Strip'};
% Scp.FlowData.ImageProtocols = {'Strip'};
% Scp.FlowData.update_FlowData();
% Scp.FlowData.Tasks
% Scp.AutoFocusType='hardware';
% for i=2:2%:size(Scp.FlowData.Tasks,1)
%     Scp.FlowData.current_idx = i;
%     % FLOW
%     Scp.FlowData.flow(Scp);
%     % IMAGE
%     for c = 1:length(Scp.FlowData.image_wells)
%         coverslip = Scp.FlowData.coverslips{c};
%         Scp.Pos = Scp.Pos.load([coverslip]);
%         Scp.AF = Scp.AF.load([coverslip]);
%         % Update AutoFocus
% %         Scp.AF = Scp.AF.updateZ(Scp);
%         % Image
%         Scp.acquire(Scp.FlowData.AcqData, ...
%             'baseacqname',[Scp.FlowData.image_protocol,Scp.FlowData.image_other])
%         Scp.Pos.save
%         Scp.AF.save
%     end
% end