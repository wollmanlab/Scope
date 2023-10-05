%% Initialize Scope
Scp = BlueScope;
%% Double check that 000 is the top left corner of the scope and Lower Limit
% Scp.Z = 0;
% Scp.XY = [0 0];
%% Set up: username, project name and dataset
Scp.Username = 'Haley'; % your username!
Scp.Project = 'TBI'; % the project this dataset correspond to
Scp.Dataset = 'DNA'; % the name of this specific image dataset - i.e. this experiment.
Scp.Dataset_Path = fullfile(Scp.basePath,Scp.Username,Scp.Project,[Scp.Dataset '_' datestr(floor(Scp.TimeStamp{1,2}),'yyyymmmdd')]);
% Scp.Dataset_Path = fullfile(Scp.basePath,Scp.Username,Scp.Project,[Scp.Dataset '_' '2023Sep21']);
Scp.ExperimentDescription = ['500 ug TBI Probes/brain'];

%% Setup Imaging Parameters
% For Data Collection
Scp.FlowData.AcqData = AcquisitionData;
Scp.FlowData.AcqData(1).Channel = 'DeepBlue';
Scp.FlowData.AcqData(1).Exposure = 20; %
Scp.FlowData.AcqData(1).Delay = 10; %
Scp.FlowData.AcqData(2).Channel = 'FarRed';
Scp.FlowData.AcqData(2).Exposure = 2500; %
Scp.FlowData.AcqData(2).Delay = 10; %

% For Preview
preview_acqdata = AcquisitionData;
preview_acqdata(1).Channel = 'FarRed';
preview_acqdata(1).Exposure = 50; %
preview_acqdata(1).Delay = 10; %

photobleach_acqdata = AcquisitionData;
photobleach_acqdata(1).Channel = 'FarRed';
photobleach_acqdata(1).Exposure = 5000; %
photobleach_acqdata(1).Delay = 10; %
%%
Scp.FlowData.start_Gui()
Scp.FlowData.start_Fluidics()

%% Setup Fluidics Parameters
Scp.FlowData.Rounds = [25,1:18];
% Scp.FlowData.Rounds = [1:4];
Scp.FlowData.FlowGroups = {'M'};
Scp.FlowData.Protocols = {'ClosedStripHybeImage'};
Scp.FlowData.ImageProtocols = {'ClosedStripHybeImage'};
Scp.FlowData.update_FlowData();
Scp.FlowData.Tasks
%% Acquire All Wells First Find Focus manually First
Scp.Chamber = Plate('FCS2');
position_acq_names = cell(Scp.FlowData.n_coverslips,1);

Scp.AutoFocusType='none';
for c=1: Scp.FlowData.n_coverslips
    coverslip = Scp.FlowData.coverslips{c};
    Wells = {coverslip};
    % Plate only if sample is in center
%     Scp.createPositions('spacing',1, ...
%         'sitesperwell',[30,30], ...
%         'sitesshape','grid', ...
%         'wells',Wells,'optimize',true)
    % MM if sample is not in center
    Scp.createPositionFromMM()
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
%     Scp.createPositions('spacing',1, ...
%         'sitesperwell',[30,30], ...
%         'sitesshape','grid', ...
%         'wells',Wells,'optimize',true)
%     Scp.createPositionFromMM()
    Scp.Pos.Well = coverslip;
    Scp.filterPositionsByDraw()
    Scp.Pos.save
end

%% Setup AutoFocus and check Focus
for c=1:Scp.FlowData.n_coverslips
    coverslip = Scp.FlowData.coverslips{c};
    Scp.Pos = Scp.Pos.load([coverslip]);
    Scp.AF = ContrastPlaneFocus;
    Scp.AF.use_groups = false;
    Scp.AF.channel = 'AutoFocus';
    Scp.AF.exposure = 100;
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
%% Manually look to where you may want to image
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
%% Use Judgement Call
dZ_min = 0;
dZ_max = 15;
dZ_step = 0.4;
dZ_steps = linspace(dZ_min,dZ_max,ceil((dZ_max-dZ_min)/dZ_step))
%% Image PolyT
Scp.FlowData.AcqData = AcquisitionData;
Scp.FlowData.AcqData(1).Channel = 'DeepBlue';
Scp.FlowData.AcqData(1).Exposure = 20; %
Scp.FlowData.AcqData(1).Delay = 10; %
Scp.FlowData.AcqData(2).Channel = 'FarRed';
Scp.FlowData.AcqData(2).Exposure = 100; %
Scp.FlowData.AcqData(2).Delay = 10; %
Scp.AutoFocusType='hardware';
for i=2:2
    Scp.FlowData.current_idx = i;
    % FLOW
    Scp.FlowData.flow(Scp);
    %pause(60)
    % IMAGE
    for c = 1:length(Scp.FlowData.image_wells)
        coverslip = Scp.FlowData.image_wells(c);
        Scp.Pos = Scp.Pos.load([coverslip]);
        Scp.AF = Scp.AF.load([coverslip]);
        % Update AutoFocus
        Scp.AF = Scp.AF.updateZ(Scp);
        pause(15);
        % Check for photobleaching
        good_pos = Scp.Pos.Labels(Scp.Pos.Hidden==0);
        Scp.goto(good_pos{1},Scp.Pos);
        Scp.autofocus();
        n_images = 100;
        Scp.Channel = Scp.FlowData.AcqData(2).Channel;
        Scp.Exposure = Scp.FlowData.AcqData(2).Exposure;
        Images = zeros([Scp.Height,Scp.Width,n_images]);
        for n=1:n_images
            Images(:,:,n) = Scp.snapImage;
        end
        score = zeros(n_images,1);
        for n=1:n_images
            img = Images(:,:,n);
            img = uint16(img*2^16-1);
            metrics = prctile(img(:),[10,90]);
            vmin = metrics(1);
            vmax = metrics(2);
            score(n) = vmax-vmin;
        end
        figure(100)
        plot([1:n_images],score)

        percent_change = score(end)/score(1);
        disp(percent_change)
%         if percent_change<0.3
%             Scp.Notifications.sendSlackMessage(Scp,'Photobleaching Detected')
%             uiwait(msgbox('Ready to proceed?'))
%         end
        Scp.Notifications.sendSlackMessage(Scp,['Hybe',Scp.FlowData.image_other,' Are you ready to proceed?'])
        uiwait(msgbox('Ready to proceed?'))

        % Image
        Scp.acquire(Scp.FlowData.AcqData, ...
            'baseacqname',['Hybe',Scp.FlowData.image_other], ...
            'dz',dZ_steps)
        Scp.Pos.save
        Scp.AF.save
    end
end

%% Photobleach (flow in tbs)
command = Scp.FlowData.build_command('ClosedValve',['M'],'TBS+3');
Scp.FlowData.send_command(command,Scp)
Scp.FlowData.wait_until_available()

photobleach_acqdata = AcquisitionData;
photobleach_acqdata(1).Channel = 'FarRed';
photobleach_acqdata(1).Exposure = 5000; %
photobleach_acqdata(1).Delay = 10; %
for i=1:5
    Scp.acquire(photobleach_acqdata)
end

%% Collect Data
Scp.FlowData.AcqData = AcquisitionData;
Scp.FlowData.AcqData(1).Channel = 'DeepBlue';
Scp.FlowData.AcqData(1).Exposure = 20; %
Scp.FlowData.AcqData(1).Delay = 10; %
Scp.FlowData.AcqData(2).Channel = 'FarRed';
Scp.FlowData.AcqData(2).Exposure = 2500; %
Scp.FlowData.AcqData(2).Delay = 10; %
Scp.AutoFocusType='hardware';
for i=3:size(Scp.FlowData.Tasks,1)
    Scp.FlowData.current_idx = i;
    % FLOW
    Scp.FlowData.flow(Scp);
    %pause(60)
    % IMAGE
    for c = 1:length(Scp.FlowData.image_wells)
        coverslip = Scp.FlowData.image_wells(c);
        Scp.Pos = Scp.Pos.load([coverslip]);
        Scp.AF = Scp.AF.load([coverslip]);
        % Update AutoFocus
        Scp.AF = Scp.AF.updateZ(Scp);

        % Check for photobleaching
        good_pos = Scp.Pos.Labels(Scp.Pos.Hidden==0);
        Scp.goto(good_pos{1},Scp.Pos);
        Scp.autofocus();
        n_images = 100;
        Scp.Channel = Scp.FlowData.AcqData(2).Channel;
        Scp.Exposure = Scp.FlowData.AcqData(2).Exposure;
        Images = zeros([Scp.Height,Scp.Width,n_images]);
        for n=1:n_images
            Images(:,:,n) = Scp.snapImage;
        end
        score = zeros(n_images,1);
        for n=1:n_images
            img = Images(:,:,n);
            img = uint16(img*2^16-1);
            metrics = prctile(img(:),[10,90]);
            vmin = metrics(1);
            vmax = metrics(2);
            score(n) = vmax-vmin;
        end
        figure(100)
        plot([1:n_images],score)

        percent_change = score(end)/score(1);
        disp(percent_change)
%         if percent_change<0.3
%             Scp.Notifications.sendSlackMessage(Scp,'Photobleaching Detected')
%             uiwait(msgbox('Ready to proceed?'))
%         end
        Scp.Notifications.sendSlackMessage(Scp,['Hybe',Scp.FlowData.image_other,' Are you ready to proceed?'])
        uiwait(msgbox('Ready to proceed?'))

        % Image
        Scp.acquire(Scp.FlowData.AcqData, ...
            'baseacqname',['Hybe',Scp.FlowData.image_other], ...
            'dz',dZ_steps)
        Scp.Pos.save
        Scp.AF.save
    end
end
%%
Scp.FlowData.AcqData = AcquisitionData;
Scp.FlowData.AcqData(1).Channel = 'DeepBlue';
Scp.FlowData.AcqData(1).Exposure = 500; %
Scp.FlowData.AcqData(1).Delay = 10; %
Scp.AutoFocusType='hardware';
Scp.AF = Scp.AF.updateZ(Scp);
Scp.acquire(Scp.FlowData.AcqData, ...
            'baseacqname',['nucstain'], ...
            'dz',dZ_steps)
