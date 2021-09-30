classdef HypeScope < Scope
    % Subclass of Scope that makes certain behavior specific to the
    % zeiss scope.
    
    properties
        last_channel = '0';
        good_focus_z = [];
        focus_fail = 0;
        currentHybe = '';
        acqname = '';
        BeadFocus;
        AF = AutoFocusOfTheseus;
        LargeMove = 500; % large movement, i.e. break the move into steps and autofocus in between 
        Notifications = Notifications;
    end
    
    
    methods
        
        function Scp = HypeScope()
            % call "super" constuctor
            Scp@Scope; 
            
            addpath('C:\Program Files\Micro-Manager-2.0gamma')

            Scp.studio = StartMMStudio('C:\Program Files\Micro-Manager-2.0gamma');
            
            % Scp.gui = Scp.studio.getMMStudioMainFrameInstance;
            
            Scp.mmc = Scp.studio.getCMMCore;
            Scp.mmc.setChannelGroup('Channel');
            Scp.LiveWindow = Scp.studio.live;
            Scp.ScopeName = 'Zeiss_Axio_0';
            
            import org.micromanager.navigation.*
            Scp.CameraName = 'Zyla42';
            
            Scp.CameraAngle = 2.75;

            %% Scope-startup - runs Nikon-Epi specific configurations
            Scp.basePath = 'D:\HypeImages';
            
            %% some propeties require knowing the name of the device
            Scp.DeviceNames.Objective = 'ZeissObjectiveTurret';
            % There is no offset device Scp.DeviceNames.AFoffset = 'TIPFSOffset';
            
            %%
            %% Autofocus method
            Scp.AutoFocusType = 'hardware';
            Scp.Optovar = 0;
            
            Scp.CorrectFlatField = false; 
            
            Scp.Chamber = Plate('Robs PDMS');
            Scp.Chamber.wellSpacingXY = [8500 8000];
            Scp.Chamber.x0y0 = [0 0]; 
            Miji;
            
        end
        
        function acqZcalibration(Scp, AcqData, acqname, dZ, varargin)
            %disp('starting z stack')
            % acqZstack acquires a whole Z stack
            arg.channelfirst = true; % if True will acq multiple channels per Z movement.
            % False will acq a Z stack per color.
            arg = parseVarargin(varargin,arg);
            Scp.autofocus;
            Z0 = Scp.Z;
            AFmethod = Scp.AutoFocusType;
            
            % turn autofocus off
            Scp.AutoFocusType='none';
            pos = Scp.Pos.peek;
            
            % acquire a Z stack and do all colors each plane
            xy = Scp.XY;
            if arg.channelfirst
                for i=1:numel(dZ)
                    Scp.Z=Z0+dZ(i);
                    acqFrame(Scp,AcqData,acqname,'z',i);
                    [l fimg] = Scp.Devices.df.snapFocus(1);
                    filename = sprintf('focusimg_%09g_%09g_%s_000.tif',i,randi(99999),'definite_focus');
                    if Scp.Pos.N>1 % add position folder
                        filename =  fullfile(sprintf('Pos%g',Scp.Pos.current-1),filename);
                    end
                    [movement confidence, pos_starting, linescan] = Scp.Devices.df.checkFocus;
                    Scp.MD.addNewImage(filename, 'Channel', 'DefiniteFocus', 'df_pos', pos_starting, 'linescan', l, 'Position',pos, 'acq',acqname,'XY',xy,'PixelSize',Scp.Devices.df.pixel_size,'Z',Scp.Z,'Zindex',dZ(i));
                    imwrite(uint16(mat2gray(fimg)*2^16-1),fullfile(Scp.pth,acqname,filename));
                    pause(2.5)
                end
            else % per color acquire a Z stack
                for j=1:numel(AcqData)
                    Scp.AutoFocusType = AFmethod;
                    Scp.autofocus
                    disp('Autofocus time')
                    Scp.AutoFocusType='none';
                    for i=1:numel(dZ)
                        Scp.Z=Z0+dZ(i);
                        acqFrame(Scp,AcqData(j),acqname,'z',i);
                    end
                end
            end
            
            % return to base and set AF back to it's previous state
            Scp.AutoFocusType = AFmethod;
            Scp.Z=Z0;
        end
        
        function acqZstack(Scp,AcqData,acqname,dZ,varargin)
            disp('starting z stack')
            % acqZstack acquires a whole Z stack
            arg.channelfirst = true; % if True will acq multiple channels per Z movement.
            arg.autoshutter = true; 
            %arg.delay = false;
            % False will acq a Z stack per color.
            arg = parseVarargin(varargin,arg);
            Z0 = Scp.Z;
            AFmethod = Scp.AutoFocusType;
            Scp.autofocus
            % turn autofocus off
            Scp.AutoFocusType='none';
            
            % acquire a Z stack and do all colors each plane
            if arg.channelfirst
                for i=1:numel(dZ)
                    Scp.Z=Z0+dZ(i);
                    for j=1:numel(AcqData)
                        acqFrame(Scp,AcqData(j),acqname,'z',i,'savemetadata',false);
                    end
                end
            else % per color acquire a Z stack
                
                    
                for j=1:numel(AcqData)
                    if arg.autoshutter == false
                        Scp.mmc.setAutoShutter(0);
                        Scp.Channel = AcqData(j).Channel;
                        Scp.mmc.setShutterOpen(1);
                        D0 = AcqData(j).Delay;
                        pause(AcqData(j).Delay*(1/1000));
                        AcqData(j).Delay = 0;
                    end
                    for i=1:numel(dZ)
                        Scp.Z=Z0+dZ(i);
                        acqFrame(Scp,AcqData(j),acqname,'z',i,'savemetadata',false);
                    end
                    if arg.autoshutter == false
                        Scp.mmc.setAutoShutter(1);
                        Scp.mmc.setShutterOpen(0);
                        AcqData(j).Delay = D0;
                    end
                end
            end
            Scp.MD.saveMetadata(fullfile(Scp.pth,acqname));
            % return to base and set AF back to it's previous state
            Scp.AutoFocusType = AFmethod;
            Scp.Z=Z0;
            %Scp.autofocus
            java.lang.System.gc()
        end
        
        function PixelSize = getPixelSize(Scp)
            PixelSize = Scp.mmc.getPixelSizeUm;
%             PixelSize = 0.325;
        end
        
        function img = snapImage(Scp)
            % Accounting for timing differences in camera communication
            
            % Set Auto Shutter Off
            %Scp.mmc.setAutoShutter(0);
            % Open Shutter (Auto Shutter must be off)
            %Scp.mmc.setShutterOpen(1);
            % Delay to account for shutter opening
            %pause(250*0.001)
            % Acquire Image
            img = snapImage@Scope(Scp);
            % Close Shutter
            %pause(10*0.001)
            %Scp.mmc.setShutterOpen(0);
            % Set Auto Shutter Off
            %Scp.mmc.setAutoShutter(1);
            
            % RKF Jan 2020
            % Previously was img=flipup(img) only;
            % Changed to fliplr(img) only so that images are in same
            % orientation as on the Ninja;
            %img = flipud(img);
            %img = fliplr(img);
        end
        
        
        function [worked confidence total_movement] = autofocus(Scp,AcqData)
            %             persistent XY;
            z=nan;
            s=nan;
            predicted_movement=nan;
            total_movement=0;
            worked=1;
            if strcmp('6-Plan-Apochromat 63x/1.40 Oil M27', Scp.mmc.getProperty('ZeissObjectiveTurret', 'Label'))
                min_movement = 0.10;
            else
                min_movement=0.4;
            end
            
            
            switch lower(Scp.AutoFocusType)
                case 'theseus'
                    Scp.AF = Scp.AF.findFocus(Scp);
                case 'relative'
                    RelativeAutoFocus(Scp);
                case 'hardware'
                    tic
                    confidence_thresh = 500;
                    course_search_range = 400;
                    tolerance = 400;
                    [move confidence pos] = Scp.Devices.df.checkFocus(Scp);
                    predicted_movement=move;
                    %disp(['Movement (um):', num2str(move), ' with ', num2str(confidence), ' confidence.'])
                    if confidence > confidence_thresh
                        move_magnitude = 10000;
                        if abs(move)<min_movement
                            disp('Movement too small.')
                            return
                        end
                        while (abs(move) < move_magnitude) && (abs(move) > min_movement)
                            Scp.move_focus(move);
                            total_movement = total_movement+move;
                            move_magnitude = abs(move);
                            [move confidence pos] = Scp.Devices.df.checkFocus();
                        end
                        Scp.good_focus_z = [Scp.good_focus_z Scp.Z];
                        total_movement./predicted_movement;
                        
                    else
                        % implement wait 2 sec then try again
                        current_focus = Scp.Z;
                        found_focus = 0;
                        disp('Trying course grain focus find.')
                        ave_z = nanmedian(Scp.good_focus_z);
                        search_range = linspace(ave_z-course_search_range, ave_z+course_search_range, 24);
                        if max(search_range)>ave_z+tolerance
                            error('Range max bigger tolerance.')
                        end
                        attempt_counter = 1;
                        for z_val = search_range
                            
                            Scp.Z = z_val;
                            [move confidence mi] = Scp.Devices.df.checkFocus(Scp);
                            if confidence > confidence_thresh
                                move_magnitude = 10000;
                                while (abs(move) < move_magnitude) & (abs(move) > min_movement)%& (max(search_range)<ave_z+tolerance)
                                    Scp.move_focus(move);
                                    total_movement = total_movement+move;
                                    move_magnitude = abs(move);
                                    [move confidence mi] = Scp.Devices.df.checkFocus(Scp);
                                end
                                if confidence < confidence_thresh
                                    pause(0.2)
                                    continue
                                else
                                    found_focus=1;
                                    move_magnitude = 10000;
                                    if abs(move)<min_movement
                                        disp('Movement too small.')
                                        return
                                    end
                                    while (abs(move) < move_magnitude) & (abs(move) > min_movement)
                                        Scp.move_focus(move);
                                        total_movement = total_movement+move;
                                        move_magnitude = abs(move);
                                        [move confidence pos] = Scp.Devices.df.checkFocus(Scp);
                                    end
                                    if confidence<confidence_thresh
                                        continue
                                    else
                                        Scp.good_focus_z = [Scp.good_focus_z Scp.Z];
                                        break
                                    end
                                end
                            end
                            
                        end
                        if found_focus
                            disp('Woo hoo found course focus')
                            
                        else
                            Scp.Z = current_focus;
                            Scp.Z = ave_z;
                            disp('Did not have confidence in finding focus. Should implement better course find if this happens a lot.')
                            worked=0;
                            Scp.focus_fail = Scp.focus_fail+1;
                        end
                        
                    end
                    toc
                    %                     Scp.mmc.sleep(1);
                case 'none'
                    disp('No autofocus used')
                    
                case 'beadfocus'
                    tic
                    
%                     switch Scp.currentHybe
%                         case Scp.BeadFocus.refHybe
%                             % corrects systematic z variataion between positions
%                             a=0;
%                         otherwise
%                             Scp.Z = Scp.Z+Scp.BeadFocus.corrections(char(Scp.Pos.Labels(Scp.Pos.current)));
%                     end
                    %Save current positons
                    currentX = Scp.X;
                    currentY = Scp.Y;
                    currentZ = Scp.Z;
                    % Bead Based Autofocus Wrapper
                    stk = Scp.BeadFocus.aquireBeads(Scp);
                    beads = Scp.BeadFocus.findBeads(Scp,stk);
                    disp(size(beads,1))
                    if size(beads,1)<20
                        disp('Trying Larger Z Range')
                        Scp.Z = currentZ;
                        switch Scp.currentHybe
                            case Scp.BeadFocus.refHybe
                                prev_min = Scp.BeadFocus.refdstart;
                                Scp.BeadFocus.refdstart = prev_min-10;
                                prev_max = Scp.BeadFocus.refdend;
                                Scp.BeadFocus.refdend = prev_max+10;
                                stk = Scp.BeadFocus.aquireBeads(Scp);
                                Scp.BeadFocus.refdstart = prev_min;
                                Scp.BeadFocus.refdend = prev_max;
                            otherwise
                                prev_min = Scp.BeadFocus.dstart;
                                Scp.BeadFocus.dstart = prev_min-10;
                                prev_max = Scp.BeadFocus.dend;
                                Scp.BeadFocus.dend = prev_max+10;
                                stk = Scp.BeadFocus.aquireBeads(Scp);
                                Scp.BeadFocus.dstart = prev_min;
                                Scp.BeadFocus.dend = prev_max;
                        end
                        beads = Scp.BeadFocus.findBeads(Scp,stk);
                    end
                    disp(strcat('Beads Found: ',num2str(size(beads,1))))
                    [tform,tformError] = Scp.BeadFocus.findTforms(Scp,beads);
                    tform = Scp.BeadFocus.pixle2StageTform(Scp,tform);
                    disp('Found Tform')
                    disp(tform)
                    Scp.BeadFocus.findCorrection(Scp,tform);
                    % Check tform
                    if tformError<Scp.BeadFocus.thresh
                        % If good move back to ref postion
                        Scp.X = currentX + tform(1); % Double check X and Y
                        Scp.Y = currentY + tform(2); % Double check X and Y
                        if tform(3)<50
                            Scp.Z = currentZ+tform(3);
                        else
                            Scp.Z = currentZ;
                            disp('Move to focus was too large >50 um')
                            disp('Went back to origional Z')
                        end
                        disp('Found Bead Focus')
                    else
                        disp('Unable to find Bead Focus')
                        disp(strcat('Error: ',num2str(tformError)))
                        % Go back to the oritional locations
                        Scp.X = currentX;
                        Scp.Y = currentY;
                        Scp.Z = currentZ;
                    end
                    toc
                    
                    
            end
            
        end
        
        
        
        function move_focus(Scp, movement)
            if abs(movement>50)
                if length(Scp.good_focus_z)>10
                    Scp.Z = nanmedian(Scp.good_focus_z(end-10:end));
                else
                    Scp.Z = nanmedian(Scp.good_focus_z);
                end
                %disp('Movement too large. I am afraid to break the coverslip.')
                disp('Movement too large. Usign average good focus.')
            else
                Scp.Z = Scp.Z + movement;
            end
        end
        
        function hybe_acq(Scp, number_hybes, varargin)
            arg.baseacqname='hybe';
            arg.show=Scp.acqshow;
            arg.save=Scp.acqsave;
            arg.closewhendone=false;
            arg.type = 'time(site)';
            arg.func = [];
            arg.acqname = '';
            arg.dz=[];
            arg.channelfirst = true; % used for Z stack
            arg = parseVarargin(varargin,arg);
            %% Flush the Zyla42 image buffer
            Scp.mmc.setCameraDevice('Zyla42');
            Scp.mmc.getImage();
            %% Init Acq
            if isempty(arg.acqname)
                acqname = Scp.initAcq(AcqData,arg);
            else
                acqname = arg.acqname;
            end
            
            
            %% move scope to camera port
            %             Scp.mmc.setProperty(Scp.LightPath{1},Scp.LightPath{2},Scp.LightPath{3});
            
            %% set up acq function
            if isempty(arg.func)
                if isempty(arg.dz)
                    arg.func = @() acqFrame(Scp,AcqData,acqname);
                else
                    arg.func = @() acqZstack(Scp,AcqData,acqname,arg.dz,'channelfirst',arg.channelfirst);
                end
            end
            
            
            %% start a mutli-time / Multi-position / Multi-Z acquisition
            switch arg.type
                case 'hybe(site)'
                    func = @() multiSiteAction(Scp,arg.func);
                    multiTimepointAction(Scp,func);
                case 'site(time)'
                    func = @() multiTimepointAction(Scp,arg.func);
                    multiSiteAction(Scp,func);
            end
            Scp.MD.saveMetadata(fullfile(Scp.pth,acqname));
            
        end
        function createPositionByDraw(Scp,acq_name,channel)
            pth = Scp.pth;
            md = Metadata(pth);
            [Images, idxes] = md.stkread('Channel', channel, 'acq', acq_name, 'flatfieldcorrection', false);
            % Converting XY Cell to XY double with X and Y Seperate
            XY_Cell = md.getSpecificMetadataByIndex('XY', idxes);
            A = cell2mat(XY_Cell(1,1));
            B = A;%str2num(A);
            for n = 2:size(XY_Cell,1)
                A = cell2mat(XY_Cell(n,1));
                B = vertcat(B,A); %vertcat(B,str2num(A));
            end
            XY = B;
            % reindex
            indxes = transpose(1:numel(XY_Cell));
            XY_Indexes = [XY, indxes];
            Sort = sortrows(XY_Indexes,[2 1 3]);
            X_Values = unique(Sort(:,2));
            
            if numel(Images) >1
                X_Columns = sum(Sort(:,2) == X_Values(1));
                Stitched = zeros(1,(2048*X_Columns));
                N = [1:X_Columns];
                while max(N) <= numel(XY_Indexes(:,3))
                    A = Sort(N,3);
                    X_Bin = Images(:,:,A);
                    X_Merge = X_Bin(:,:,1);
                    for hor_i = 2:size(X_Bin, 3)
                        X_Merge = horzcat(X_Merge, X_Bin(:,:,hor_i));
                    end
                    %X_Merge = fliplr(X_Merge);
                    Stitched = vertcat(Stitched,X_Merge);
                    N = N+X_Columns;
                end
                %Stitched = rot90(Stitched,2);
            else
            end
            %Display
            figure(88)
            I = imadjust(Stitched);
            imshow(I)
            switch order
                case 'stitched'
                    i=1;
                    Coordinates =[];
                    CameraDirection = [1 1]; %[X Y]
                    InputPixelSize = 1.266;
                    OutputPixelSize = 0.103;
                    Ratio = InputPixelSize/OutputPixelSize;
                    for i = 1:size(Images,3)
                        Image = Images(:,:,i);
                        figure(89)
                        imshow(imadjust(Image))
                        totMask = false(size(Image));
                        h = imfreehand(gca); setColor(h,'red');
                        position = wait(h);
                        BW = createMask(h);
                        while sum(BW(:)) > 10 % less than 10 pixels is considered empty mask
                            totMask = totMask | BW;
                            h = imfreehand(gca); setColor(h,'red');
                            position = wait(h);
                            BW = createMask(h);
                        end
                        BlockSize = floor([2048/Ratio 2048/Ratio]); %[170 170]%XY in pixels
                        fun = @(block_struct) detect(block_struct.data,0.1); % 0.1 is threshold
                        Blocks = blockproc(totMask, BlockSize, fun, 'BorderSize',[0,0], 'TrimBorder', false);
                        Position = regionprops(Blocks, 'PixelList');
                        if numel(Position) > 0
                            Pixel_Position = Position.PixelList;
                            %Coordinates for Stitched
                            XY_Stitched = XY(i,:);
                            Block_Y_Coordinates = mean(XY(:,2)) + (CameraDirection(2) * InputPixelSize * (Pixel_Position(:,2) * BlockSize(2) - size(Image,1)/2));
                            Block_X_Coordinates = mean(XY(:,1)) + (CameraDirection(1) * InputPixelSize * (Pixel_Position(:,1) * BlockSize(1) - size(Image,2)/2));
                            Block_Coordinates = [Block_X_Coordinates(),Block_Y_Coordinates()];
                            Coordinates = vertcat(Coordinates,Block_Coordinates);
                        end
                    end
                    figure(89)
                    scatter(Coordinates(:,1),Coordinates(:,2))
                otherwise
                    i=1;
                    Coordinates =[];
                    CameraDirection = [1 1]; %[X Y]
                    InputPixelSize = 1.266;
                    OutputPixelSize = 0.103;
                    Ratio = InputPixelSize/OutputPixelSize;
                    figure(89)
                    Image = Stitched;
                    imshow(imadjust(Image))
                    totMask = false(size(Image));
                    h = imfreehand(gca); setColor(h,'red');
                    position = wait(h);
                    BW = createMask(h);
                    while sum(BW(:)) > 10 % less than 10 pixels is considered empty mask
                        totMask = totMask | BW;
                        h = imfreehand(gca); setColor(h,'red');
                        position = wait(h);
                        BW = createMask(h);
                    end
                    BlockSize = floor([2048/Ratio 2048/Ratio]); %XY in pixels
                    fun = @(block_struct) detect(block_struct.data,0.1); % 0.1 is threshold
                    Blocks = blockproc(totMask, BlockSize, fun, 'BorderSize',[0,0], 'TrimBorder', false);
                    Position = regionprops(Blocks, 'PixelList');
                    if numel(Position) > 0
                        Pixel_Position = Position.PixelList;
                        Block_Y_Coordinates = mean(XY(:,2)) + (CameraDirection(2) * InputPixelSize * (Pixel_Position(:,2) * BlockSize(2) - size(Image,1)/2));
                        Block_X_Coordinates = mean(XY(:,1)) + (CameraDirection(1) * InputPixelSize * (Pixel_Position(:,1) * BlockSize(1) - size(Image,2)/2));
                        Block_Coordinates = [Block_X_Coordinates(),Block_Y_Coordinates()];
                        Coordinates = vertcat(Coordinates,Block_Coordinates);
                        figure(89)
                        scatter(Coordinates(:,1),Coordinates(:,2))
                    else
                        disp('no positions found')
                    end
            end
            p = Positions;
            for i = 1:size(Coordinates, 1)
                p.add(Coordinates(i, :), strcat('Pos', num2str(i)))
            end
            Scp.Pos = p;
        end
        function [img] = saveAcqFrame(Scp,AcqData,acqname,varargin)
            % acqFrame - acquire a single frame in currnet position / timepoint
            % here is also where we add / save the metadata
            
            % set up default position based on Scope's Tpnts and Pos
            if ~isempty(Scp.Tpnts)
                arg.t = Scp.Tpnts.current;
            else
                arg.t=1;
            end
            if ~isempty(Scp.Pos)
                arg.p = Scp.Pos.current;
            else
                arg.p = 1;
            end
            arg.z=1;
            arg.savemetadata=true;
            arg.refposname='';
            arg = parseVarargin(varargin,arg);
            
            t = arg.t;
            p = arg.p;
            
            if isempty(arg.refposname)
                Scp.FrameCount(p)=Scp.FrameCount(p)+1;
            end
            
            % autofocus function depends on scope settings
            Scp.TimeStamp = 'before_focus';
            Scp.autofocus;
            Scp.TimeStamp = 'after_focus';
            %% Make sure I'm using the right MD
            if arg.savemetadata
                Scp.MD = acqname;
                % Watch out for the Scp.set.Metadata - it create a Metadata
                % object from the acqname
                % if the Acq wasn't initizlied properly it should throw an error
            end
            
            % set baseZ to allow dZ between channels
            baseZ=Scp.Z;
            
            % get XY to save in metadata
            
            XY = Scp.XY; %#ok<PROPLC>
            Z=Scp.Z;  %#ok<PROPLC>
            
            n = numel(AcqData);
            ix=zeros(n,1);
            T=zeros(n,1);
            skipped=false(n,1);
            
            %% Figure out if some of the channels are triggered and if so start triggered seq
            TriggeredChannels = cat(1,AcqData.Triggered);
            if any(TriggeredChannels)
                %% verify that they are all in the beginning
                assert(nnz(diff(double(TriggeredChannels)))<=1 && TriggeredChannels(1),'All Triggered Channels must be in one group in the beginnig of AcqData!')
                
                %% update state to the first AcqData (all the rest should be the same up to trigger)
                Scp.updateState(AcqData(1));
                
                %% Set up seq acqusition
                stk=Scp.snapSeq(sum(TriggeredChannels));
            end
            
            
            % look over all channel
            for i=1:n
                
                % Never skip on the first frame...
                if  isempty(arg.refposname) && Scp.FrameCount(p) >1 && mod(Scp.FrameCount(p),AcqData(i).Skip)
                    skipped(i)=true;
                    continue
                end
                
                %% update Scope state
                if ~TriggeredChannels(i)
                    Scp.updateState(AcqData(i)); % set scope using all fields of AcqData including channel, dZ, exposure etc.
                end
                Scp.TimeStamp='updateState';
                
                % we are not strobbing and therefore are going to either acquire one image at a time and save it or reference the previously acquried stack from Trigger channels
                
                %% figure out image filename to be used by MM
                % start write
                poslabel = Scp.Pos.peek;
                if ~Scp.Strobbing
                    filename = sprintf('img_%s_%09g_%09g_%s_000.tif',poslabel,Scp.FrameCount(p),t-1,AcqData(i).Channel);
                else %spim specific
                    filename = sprintf('img_%s_%03g_Ch%d_000.tif',poslabel,Scp.FrameCount(p)-1,i);
                end
                if Scp.Pos.N>1 && ~Scp.Strobbing % add position folder
                    filename =  fullfile(sprintf('Pos%g',p-1),filename);
                end
                if ~isempty(arg.z) && ~Scp.Strobbing
                    filename = filename(1:end-4);
                    filename = sprintf('%s_%03g.tif',filename,arg.z);
                end
                if ~isempty(AcqData(i).dZ)
                    filename = filename(1:end-4);
                    filename = sprintf('%s_%03g.tif',filename,i);
                end
                if ~isempty(arg.refposname)
                    filename = filename(1:end-4);
                    filename = sprintf('%s_%05g.tif',filename,randi(99999)); % Rob forced me to do it
                end
                
                %%
                Scp.TimeStamp='image';
                %% Snap image / or pull from camera seq
                % proceed differ whether we are using MM to show the stack
                if Scp.Strobbing
                    filename = filename(1:end-4); % remote .tiff
                    filename2ds = fullfile(acqname,filename);
                    NFrames = Scp.Pos.ExperimentMetadata(Scp.Pos.current).nFrames;
                    dz = Scp.Pos.ExperimentMetadata(Scp.Pos.current).dz;
                    Scp.ZStage.Velocity = 8;
                    Scp.ZStage.moveWithDelay(dz*NFrames);
                    tic;
                    Scp.snapSeqDatastore(Scp.pth,filename2ds,NFrames)
                    Scp.ZStage.Velocity = 10;
                    Scp.goto(Scp.Pos.peek,Scp.Pos);
                    filename = [filename filesep 'MMStack.ome.tif'];
                else
                    if Scp.Pos.N>1
                        if ~exist([Scp.pth filesep acqname filesep sprintf('Pos%g',p-1)],'dir')
                            mkdir([Scp.pth filesep acqname filesep sprintf('Pos%g',p-1)]);
                        end
                    else
                        if ~exist([Scp.pth filesep acqname],'dir')
                            mkdir([Scp.pth filesep acqname]);
                        end
                    end
                    if TriggeredChannels(i)
                        % replace all part till else with indexing from stk.
                        img=stk(:,:,i);
                    else
                        img = Scp.snapImage;
                    end
                    try
                        imwrite(uint16(img*2^16-1),fullfile(Scp.pth,acqname,filename));%AOY added -1
                    catch  %#ok<CTCH>
                        errordlg('Cannot save image to harddeive. Check out space on drive');
                    end
                end
                
                Scp.TimeStamp='save image';
                if strcmp(Scp.acqshow,'channel')
                    Scp.showStack;
                end
                
                
                % timestamp to update Scope when last image was taken
                T(i)=now; % to save in metadata
                
                % return Z to baseline
                Zformd=Scp.Z; % for record keeping
                if ~isempty(AcqData(i).dZ) && AcqData(i).dZ~=0 % only move if dZ was not empty;
                    Scp.Z=baseZ;
                    Z=baseZ; %#ok<PROPLC>
                end
                
                %% deal with metadata of scope parameters
                if isempty(arg.refposname)
                    
                    grp = Scp.Pos.peek('group',true); % the position group name, e.g. the well
                    pos = Scp.Pos.peek;
                else
                    grp = 'RefPoints';
                    pos = arg.refposname;
                end
                [~,xy_before_transform] = Scp.Pos.getPositionFromLabel(Scp.Pos.peek);
                ix(i) = Scp.MD.addNewImage(filename,'FlatField',Scp.CurrentFlatFieldConfig,'Position',pos,'group',grp,'acq',acqname,'frame',t,'TimestampImage',T(i),'XY',XY,'PixelSize',Scp.PixelSize,'PlateType',Scp.Chamber.type,'Z',Zformd,'Zindex',arg.z,'XYbeforeTransform',xy_before_transform); %#ok<PROPLC>
                fld = fieldnames(AcqData(i));
                for j=1:numel(fld)
                    if ~isempty(AcqData(i).(fld{j}))
                        Scp.MD.addToImages(ix(i),fld{j},AcqData(i).(fld{j}))
                    end
                end
                Scp.TimeStamp='metadata'; % to save within scope timestamps
            end
            T(skipped)=[];
            ix(skipped)=[];
            
            % add metadata - average time for frame and position based
            % experimental metadata
            Scp.MD.addToImages(ix,'TimestampFrame',mean(T));
            ExpMetadata = fieldnames(Scp.Pos.ExperimentMetadata);
            for i=1:numel(ExpMetadata)
                Scp.MD.addToImages(ix,ExpMetadata{i},Scp.Pos.ExperimentMetadata(p).(ExpMetadata{i}));
            end
            if arg.savemetadata
                
                Scp.MD.saveMetadata(fullfile(Scp.pth,acqname));
                
            end
            Scp.TimeStamp='endofframe';
            
        end
        
        function setXY(Scp,XY)
            currXY = Scp.XY;
            dist = sqrt(sum((currXY(:)-XY(:)).^2));
            if Scp.XYpercision >0 && dist < Scp.XYpercision
                fprintf('movment too small - skipping XY movement\n');
                return
            end
            Scp.autofocus; 
%             if dist > Scp.LargeMove
%                 n=ceil(dist/Scp.LargeMove);
%                 XYvec = [linspace(currXY(1),XY(1),n)' linspace(currXY(2),XY(2),n)'];
%                 for i=1:n
%                     try % Timeout error on hype scope where um misses task completely signal
%                         Scp.mmc.setXYPosition(Scp.mmc.getXYStageDevice,XYvec(i,1),XYvec(i,2))
%                         Scp.mmc.waitForDevice(Scp.mmc.getProperty('Core','XYStage'));
%                     catch % try again
%                         disp('Error during stage movement. Trying again')
%                         Scp.mmc.setXYPosition(Scp.mmc.getXYStageDevice,XYvec(i,1),XYvec(i,2))
%                         Scp.mmc.waitForDevice(Scp.mmc.getProperty('Core','XYStage'));
%                     end
%                     Scp.autofocus; 
%                 end
%             end
            try % Timeout error on hype scope where um misses task completely signal
                Scp.mmc.setXYPosition(Scp.mmc.getXYStageDevice,XY(1),XY(2))
                Scp.mmc.waitForDevice(Scp.mmc.getProperty('Core','XYStage'));
            catch % try again
                disp('Error during stage movement. Trying again')
                Scp.mmc.setXYPosition(Scp.mmc.getXYStageDevice,XY(1),XY(2))
                Scp.mmc.waitForDevice(Scp.mmc.getProperty('Core','XYStage'));
            end
        end
    end
    
    
    
end
