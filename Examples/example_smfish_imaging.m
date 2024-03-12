%% Initialize Scope
Scp = BlueScope;
%% Double check that 000 is the top left corner of the scope and Lower Limit
% Scp.Z = 0;
% Scp.XY = [0 0];
%% Set up: username, project name and dataset
Scp.Username = 'Gaby'; % your username!
Scp.Project = 'Elegans'; % the project this dataset correspond to
Scp.Dataset = 'RNA_20mer_probes_3mL_chitnase'; % the name of this specific image dataset - i.e. this experiment.
Scp.Dataset_Path = fullfile(Scp.basePath,Scp.Username,Scp.Project,[Scp.Dataset '_' datestr(floor(Scp.TimeStamp{1,2}),'yyyymmmdd')]);
%Scp.Dataset_Path = fullfile(Scp.basePath,Scp.Username,Scp.Project,[Scp.Dataset '_' '2023Oct24']);
Scp.ExperimentDescription = ['500 ug TBI Probes/brain'];

%% Setup Imaging Parameters
% For Data Collection
Scp.FlowData.AcqData = AcquisitionData;
Scp.FlowData.AcqData(2).Channel = 'DeepBlue';
Scp.FlowData.AcqData(2).Exposure = 20; %
Scp.FlowData.AcqData(2).Delay = 10; %
Scp.FlowData.AcqData(1).Channel = 'FarRed';
Scp.FlowData.AcqData(1).Exposure = 2500; %
Scp.FlowData.AcqData(1).Delay = 10; %

% For Preview
preview_acqdata = AcquisitionData;
preview_acqdata(1).Channel = 'DeepBlue';
preview_acqdata(1).Exposure = 20; %
preview_acqdata(1).Delay = 10; %

photobleach_acqdata = AcquisitionData;
photobleach_acqdata(1).Channel = 'FarRed';
photobleach_acqdata(1).Exposure = 5000; %
photobleach_acqdata(1).Delay = 10; %
%%
Scp.FlowData.start_Gui()
Scp.FlowData.start_Fluidics()

%% Setup Fluidics Parameters
Scp.FlowData.Rounds = [1:3]; 
Scp.FlowData.FlowGroups = {'M'};
Scp.FlowData.Protocols = {'ClosedStripImage','ClosedHybeImage'};
Scp.FlowData.ImageProtocols = {'ClosedStripImage','ClosedHybeImage'};
Scp.FlowData.update_FlowData();
Scp.FlowData.Tasks
%% Acquire All Wells First Find Focus manually First
Scp.Chamber = Plate('FCS2',Scp);
position_acq_names = cell(Scp.FlowData.n_coverslips,1);
Scp.preview_binning = 20;
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
%     coverslip = Scp.FlowData.coverslips{c};
%     Scp.Pos = Scp.Pos.load([coverslip]);
%     Wells = {coverslip};
%     Scp.createPositions('spacing',1, ...
%         'sitesperwell',[30,30], ...
%         'sitesshape','grid', ...
%         'wells',Wells,'optimize',true)
%     Scp.createPositionFromMM()
    Scp.Pos.Well = coverslip;
    Scp.filterPositionsByDraw()
    length(Scp.Pos.Labels)
    Scp.Pos.save
end

%% Setup AutoFocus and check Focus
Scp.preview_binning = 5;
for c=1:Scp.FlowData.n_coverslips
    coverslip = Scp.FlowData.coverslips{c};
    Scp.Pos = Scp.Pos.load([coverslip]);
    Scp.AF = ContrastPlaneFocus;
    Scp.AF.use_groups = false;
    Scp.AF.channel = 'AutoFocus';
    Scp.AF.exposure = 500;
    Scp.AF.coarse_window = 50;
    Scp.AF.coarse_dZ = 5;
    Scp.AF.medium_window = 15;
    Scp.AF.medium_dZ = 1;
    Scp.AF.fine_window = 2;
    Scp.AF.fine_dZ = 0.2;
    Scp.AF.metric = 'sobel_haley';
    Scp.AF.Well = coverslip;
    Scp.AF.optimize_speed = false;
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
    Scp.acquire(preview_acqdata);
    Scp.Pos.save
    Scp.AF.save
end
%% Check Planarity
for c=1:Scp.FlowData.n_coverslips
    Scp.AutoFocusType='hardware';
    coverslip = Scp.FlowData.coverslips{c};
    Scp.Pos = Scp.Pos.load([coverslip]);
    Scp.AF = Scp.AF.load([coverslip]);
    expected_Z = zeros([length(Scp.Pos.Labels),1]);
    for i=1:length(Scp.Pos.Labels)
        Scp.goto(Scp.Pos.Labels{i},Scp.Pos);
        Scp.autofocus();
        expected_Z(i) = Scp.Z;
    end

    figure(c)
    scatter(Scp.Pos.List(:,1),Scp.Pos.List(:,2),25,expected_Z,'filled')
    colorbar
    colormap jet
    
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
dZ_min = -6 %-5;
dZ_max = 42;
dZ_step = 1; %0.4;
dZ_steps = linspace(dZ_min,dZ_max,ceil((dZ_max-dZ_min)/dZ_step));
%% Remove DAPI
dZ_min = -10 %-5;
dZ_max = 80;
dZ_step = 1; %0.4;
dZ_steps = [20];
%% Collect Data
Scp.FlowData.AcqData = AcquisitionData;
Scp.FlowData.AcqData(1).Channel = 'DeepBlue';
Scp.FlowData.AcqData(1).Exposure = 20; %
Scp.FlowData.AcqData(1).Delay = 10; %
Scp.FlowData.AcqData(2).Channel = 'FarRed';
Scp.FlowData.AcqData(2).Exposure = 2500; %
Scp.FlowData.AcqData(2).Delay = 10; %
Scp.AutoFocusType='hardware';

%for i=37:64 
for i=1:size(Scp.FlowData.Tasks,1)
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
        if contains(Scp.FlowData.image_protocol,'Hybe')
             % Image
            Scp.acquire(Scp.FlowData.AcqData, ...
                'baseacqname',['Hybe',Scp.FlowData.image_other], ...
                'dz',dZ_steps)
        else
            % Image
            Scp.acquire(Scp.FlowData.AcqData, ...
                'baseacqname',['Strip',Scp.FlowData.image_other], ...
                'dz',dZ_steps)
        end
        Scp.Pos.save
        Scp.AF.save
    end
end
%%

%% Filter by Signal
Scp.Pos = Scp.Pos.load([coverslip]);
stk = Scp.Pos.Other{1};
FF = zeros([size(stk,1),size(stk,2),length(Scp.Pos.Other)]);
for i=1:length(Scp.Pos.Other)
    stk = Scp.Pos.Other{i};
    img = stk(:,:,2);
    img = img*2^16-1;
    FF(:,:,i) = img;
end
FF = median(FF,3);
FF= uint16(FF);
thresh = 100;
pixels_thresh = 0.05;
hidden = Scp.Pos.Hidden;
for i =1:length(hidden)
    stk = Scp.Pos.Other{i};
    dapi = stk(:,:,1);
    rna = stk(:,:,2);
    img = rna*2^16-1;
    img = double(img)-double(FF);
    img = medfilt2(img,[3,3]);
    img = imgaussfilt(img,5);
    v = img(:);
    p = sum(v>thresh)/length(v);
    vmin = prctile(img(:),5);
    vmax = prctile(img(:),95);
    img(img<vmin) = vmin;
    img(img>vmax) = vmax;
    try
        close(i)
    end
    if p>pixels_thresh
        hidden(i) = 0;
        figure(i+2000)
        imshow(img,'DisplayRange',[vmin,vmax])
        colormap winter
        colorbar()
    else
        hidden(i) = 1;
        figure(i+2000)
        imshow(img,'DisplayRange',[vmin,vmax])
        colormap autumn
        colorbar()
    end
end
sum(hidden)
%%
Scp.Pos.Hidden = hidden;
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
%         % Check for photobleaching
%         %good_pos = Scp.Pos.Labels(Scp.Pos.Hidden==0);
%         %Scp.goto(good_pos{1},Scp.Pos);
%         %Scp.autofocus();
%         %n_images = 100;
%         %Scp.Channel = Scp.FlowData.AcqData(2).Channel;
%         %Scp.Exposure = 250;
%         %Images = zeros([Scp.Height,Scp.Width,n_images]);
%         %score = zeros(n_images,1);
%         % Set Auto Shutter Off
%         %Scp.mmc.setAutoShutter(0);
%         % Open Shutter (Auto Shutter must be off)
%         %Scp.mmc.setShutterOpen(1);
%         % Delay to account for shutter opening
%         %pause(0.1)
%         %for n=1:n_images
%             %img = Scp.snapImage;
%             %img = uint16(img*2^16-1);
%             %metrics = prctile(img(:),[10,90]);
%             %vmin = metrics(1);
%             %vmax = metrics(2);
%             %score(n) = vmax-vmin;
%             %disp(vmax-vmin)
%             %Images(:,:,n) = img;
%         end
%         % Close Shutter
%         Scp.mmc.setShutterOpen(0);
%         % Set Auto Shutter Off
%         Scp.mmc.setAutoShutter(1);
%         %figure(100)
%         %plot([1:n_images],score)
% 
%         %percent_change = score(end)/score(1);
%         %disp(percent_change)
% %         if percent_change<0.3
% %             Scp.Notifications.sendSlackMessage(Scp,'Photobleaching Detected')
% %             uiwait(msgbox('Ready to proceed?'))
% %         end
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


%% manually go look to check photobleach 







% %% Photobleach (flow in tbs)
% command = Scp.FlowData.build_command('ClosedValve',['M'],'TBS+3');
% Scp.FlowData.send_command(command,Scp)
% Scp.FlowData.wait_until_available()
% 
% photobleach_acqdata = AcquisitionData;
% photobleach_acqdata(1).Channel = 'FarRed';
% photobleach_acqdata(1).Exposure = 5000; %
% photobleach_acqdata(1).Delay = 10; %
% for i=1:5
%     Scp.acquire(photobleach_acqdata)
% end
% %% Recover if coverslip was removed from stage
% for c=1:Scp.FlowData.n_coverslips
%     coverslip = Scp.FlowData.coverslips{c};
%     Scp.Pos = Scp.Pos.load([coverslip]);
%     Scp.AF = Scp.AF.load([coverslip]);
%     % Update AutoFocus
%     Scp.AF = Scp.AF.calculateZ(Scp);
%     Scp.Pos.save
%     Scp.AF.save
% end

%% DAPI stain image
Scp.FlowData.AcqData = AcquisitionData;
Scp.FlowData.AcqData(1).Channel = 'DeepBlue';
Scp.FlowData.AcqData(1).Exposure = 250; %
Scp.FlowData.AcqData(1).Delay = 10; %
Scp.AutoFocusType='hardware';
Scp.AF = Scp.AF.updateZ(Scp);
Scp.acquire(Scp.FlowData.AcqData, ...
            'baseacqname',['nucstain'], ...
            'dz',dZ_steps)

%% Flush
command = Scp.FlowData.build_command('ReverseFlush',[''],'Dapi+5');
Scp.FlowData.send_command(command,Scp)
Scp.FlowData.wait_until_available()

command = Scp.FlowData.build_command('Prime',[''],'Dapi+5');
Scp.FlowData.send_command(command,Scp)
Scp.FlowData.wait_until_available()

command = Scp.FlowData.build_command('ReverseFlush',[''],'Air+3');
Scp.FlowData.send_command(command,Scp)
Scp.FlowData.wait_until_available()

command = Scp.FlowData.build_command('ReverseFlush',[''],'Air+3');
Scp.FlowData.send_command(command,Scp)
Scp.FlowData.wait_until_available()

%%
%Scp.X = 7.4314e+04;
%Scp.Y =  4.3402e+04;
% Scp.autofocus()
% Scp.Z = Scp.Z+5;
tic
n_images = 10;
intensity = zeros([n_images,1]);
for n=1:n_images
    Scp.Channel = 'DeepBlue';
    Scp.Exposure = 50;
    img = Scp.snapImage;
    Scp.Channel = 'FarRed';
    Scp.Exposure = 2500;
    img = Scp.snapImage;
    img = uint16(img*2^16-1);
    img = medfilt2(img,[2,2]); % remove hot pixels
    bkg = imgaussfilt(img,5);
    img_processed = img-bkg;
    if n==1
        thresh = median(img_processed(:))+4*std(double(img_processed(:)));
        mask = img_processed>thresh;
    end
    intensity(n) = median(img_processed(mask));
end
intensity(end)
intensity(1)
if intensity(1)<400
    Scp.Notifications.sendSlackMessage(Scp,'Low Signal Detected')
    uiwait(msgbox('Ready to proceed?'))
end

percent_decrease = (intensity(1)-intensity(end))/intensity(1)
if percent_decrease>0.25
    Scp.Notifications.sendSlackMessage(Scp,'Photobleaching Detected')
    uiwait(msgbox('Ready to proceed?'))
end

toc
%%
percent_decrease = (intensity(1)-intensity(end))/intensity(1)