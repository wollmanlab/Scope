classdef (Abstract) Scope < handle
    % Version 0.5 Feb 2018 - split Ninja specific stuff.
    % Making Scope compatible with MM 2.0

    properties (Transient = true) % don't save to disk - ever...

        %% MM objects
        mmc % the MM core
        studio %% MM studio - the main plugin
        LiveWindow; % a MM live windows, can also be used to trigger snap
        frameID=0; % internal running number

        %% Acquisition related properties
        openAcq={};
        currentAcq = 0;
        CurrentDatastore;
        Strobbing = false;

        ContinousImaging = false;

        %% imaging properties
        Binning=1;

        Objective
        ObjectiveOffsets
        CameraAngle = 0;

        %%
        lastImg;

        %% User etc
        Username
        Dataset
        Project
        ExperimentDescription %free form description of the experiment to be saved in the Metadata for this experiment.

        %% Acquisition information
        SkipCounter = 0; % this is for Position skipping
        Pos
        Tpnts
        AllMDs = [];
        MD = []; % current MD (this is a pointer, a copy of which will be in AllMDs as well!

        acqshow = 'single'; %This controls how imgaes are shown:
        % 'none' - skips image show, only works with MM 2.0 and above
        acqsave = true;

        %%
        plotPlate = true;

        %% image size properties
        Width
        Height
        BitDepth
        PixelSize

        %% Plate configurations
        Chamber % determine what is the current chamber (plate, slide, etc) that is being imaged

        %% Temp/Humidity sensor
        Temperature
        Humidity
        CO2
        TempLog=[];
        HumidityLog=[];
        CO2Log=[];


        %% properties needed to save images
        AllAcqDataUsedInThisDataset
        AcqData % last AcqData used in a frame
        FrameCount = 0; % this is for per channel skipping
        basePath = '';


        %% Monitoring (logging and profiling)
        TimeStamp={'init',now};
        ErrorLogPth

        %% software image based autofocus related parameters
        AutoFocusType = 'Hardware'; % Software / Hardware / DefiniteFocus / None
        autogrid=10;
        AFparam=struct('scale',2,'resize',1,'channel','DeepBlue','exposure',10,'verbose',true);
        AFgrid
        AFscr
        AFlog=struct('Time',[],'Z',[],'Score',[],'Channel','','Type','');
        TtoplotAFlogFrom=0;
        autofocusTimeout = 10; %seconds

        %% Flag to determine if should take shortcuts for speed
        reduceAllOverheadForSpeed = false; % several steps could be ignored for speed

        %% an array to determine config sepcific naming
        ScopeName = 'None';
        LightPath = '';
        CameraName
        DeviceNames
        TriggerDeviceName;

        %%  additional non-MM devices
        Devices = struct();

        %% Flat field correction
        FlatFields
        FlatFieldsFileName='';
        CorrectFlatField = false;
        CurrentFlatFieldConfig

        %% Percision XY
        XYpercision = 10; % microns
        dXY = [0 0];
        Zpercision = 0.5; % microns


        %% Magnification
        Optovar = 1;

        EnforcePlatingDensity = true;

        %% Live shift adjust
        shiftfilepath =[];

        MMversion = 2.0;

    end

    properties (Dependent = true)
        Channel
        Exposure
        Gain
        Z
        X
        Y
        XY % so I can set them togahter in a singla call
        pth
        relpth
        %         MMversion
    end


    %% Methods

    methods (Static = true)
        function cl = java2cell(jv)
            n=jv.size;
            cl = cell(n,1);
            for i=1:n
                cl(i)=jv.get(i-1);
            end
        end
    end

    methods

        function disp(Scp) %#ok<MANU>
            fprintf('Scope\n')
        end

        %% constructors
        function Scp = Scope

            %% general stuff
            warning('off','Images:initSize:adjustingMag')
            warning('off','Images:imshow:magnificationMustBeFitForDockedFigure')

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

            % turn autofocus off
            Scp.AutoFocusType='none';

            % acquire a Z stack and do all colors each plane
            if arg.channelfirst
                for i=1:numel(dZ)
                    Scp.Z=Z0+dZ(i);
                    acqFrame(Scp,AcqData,acqname,'z',i,'savemetadata',false);
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
            Scp.autofocus

        end

        function acqFrame(Scp,AcqData,acqname,varargin)
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
            if ~isempty(cat(1,AcqData.dZ))
                baseZ=Scp.Z;
            else 
                baseZ = nan; 
            end
            % get XY to save in metadata from position list
%             XY = Scp.XY; %#ok<PROPLC>
            XY = round(Scp.Pos.List(Scp.Pos.current,:));%#ok<PROPLC>

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
                if ~TriggeredChannels(i) && length(AcqData)>1
                    Scp.updateState(AcqData(i)); % set scope using all fields of AcqData including channel, dZ, exposure etc.
                end
                Scp.TimeStamp='updateState';

                % we are not strobbing and therefore are going to either acquire one image at a time and save it or reference the previously acquried stack from Trigger channels

                %% figure out image filename to be used by MM
                % start write
                poslabel = Scp.Pos.peek;
                if ~Scp.Strobbing
                    % Add random number to filename
                    filename = sprintf('img_%s_%09g_%09g_%s_%06g.tif',poslabel,Scp.FrameCount(p),t-1,AcqData(i).Channel,round(rand*10^5));
                else %spim specific
                    % Add random number to filename
                    filename = sprintf('img_%s_%03g_Ch%d_%06g.tif',poslabel,Scp.FrameCount(p)-1,i,round(rand*10^5));
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
                    filename = fullfile(Scp.pth,acqname,filename);
                    filename = filename(1:end-4); % remote .tiff
                    filename2ds = fullfile(acqname,filename);
                    NFrames = Scp.Pos.ExperimentMetadata(Scp.Pos.current).nFrames;
                    dz = Scp.Pos.ExperimentMetadata(Scp.Pos.current).dz;
                    Scp.ZStage.Velocity = Scp.imagingVelocity;%Scp.imagingVelocity;
                    Scp.ZStage.moveWithDelay(dz*NFrames);
                    tic;
                    Scp.snapSeqDatastore(Scp.pth,filename2ds,NFrames)
                    Scp.ZStage.Velocity = 10;
                    Scp.goto(Scp.Pos.peek,Scp.Pos);
                    [dX,dY,dZ] = parseShiftFile(Scp);
                    Scp.X = Scp.X+dX;
                    Scp.Y = Scp.Y+dY;
                    Scp.Z = Scp.Z+dZ;

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
                    elseif AcqData(i).Delay>0
                        % Set Auto Shutter Off
                        Scp.mmc.setAutoShutter(0);
                        % Open Shutter (Auto Shutter must be off)
                        Scp.mmc.setShutterOpen(1);
                        % Delay to account for shutter opening
                        pause(AcqData(i).Delay*0.001)
                        % Acquire Image
                        img = Scp.snapImage;
                        % Close Shutter
                        Scp.mmc.setShutterOpen(0);
                        % Set Auto Shutter Off
                        Scp.mmc.setAutoShutter(1);
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
                Zformd=baseZ; % for record keeping
                if ~isempty(AcqData(i).dZ) && AcqData(i).dZ~=0 % only move if dZ was not empty;
                    Scp.Z=baseZ;
                end

                %% deal with metadata of scope parameters
                if isempty(arg.refposname)

                    if isa(Scp,'HypeScope')
                        pos = Scp.Pos.peek;
                        grp = pos; %hypescope hack
                    else
                        pos = Scp.Pos.peek;
                        grp = Scp.Pos.peek('group',true); % the position group name, e.g. the well
                    end

                else
                    grp = 'RefPoints';
                    pos = arg.refposname;
                end
                try
                    Scp.TempHumiditySensor = Scp.TempHumiditySensor.updateStatus();
                    temperature = Scp.TempHumiditySensor.temp;
                    humidity = Scp.TempHumiditySensor.humidity;
                catch
                    temperature = '0';
                    humidity = '0';
                end

                [~,xy_before_transform] = Scp.Pos.getPositionFromLabel(Scp.Pos.peek);
                ix(i) = Scp.MD.addNewImage(filename,'Scope',class(Scp),'FlatField',Scp.CurrentFlatFieldConfig,'Position',pos,'group',grp,'acq',acqname,'frame',t,'TimestampImage',T(i),'XY',XY,'PixelSize',Scp.PixelSize,'PlateType',Scp.Chamber.type,'Z',Zformd,'Zindex',arg.z,'XYbeforeTransform',xy_before_transform,'Temperature',temperature,'Humidity',humidity); %#ok<PROPLC>
%                 ix(i) = Scp.MD.addNewImage(filename,'Scope',class(Scp),'FlatField',Scp.CurrentFlatFieldConfig,'Position',pos,'group',grp,'acq',acqname,'frame',t,'TimestampImage',T(i),'XY',XY,'PixelSize',Scp.PixelSize,'PlateType',Scp.Chamber.type,'Z',Zformd,'Zindex',arg.z,'XYbeforeTransform',xy_before_transform); %#ok<PROPLC>
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

        %% snapSeq using datastore on the SSD
        function snapSeqDatastore(Scp,pth,filename,NFrames)
            store = Scp.studio.data().createMultipageTIFFDatastore([pth filesep filename],false,false);
            %Scp.studio.displays().manage(store);
            %Scp.studio.displays().createDisplay(store);
            builder = Scp.studio.data().getCoordsBuilder().z(0).channel(0).stagePosition(0);
            curFrame = 0;
            Scp.mmc.startSequenceAcquisition(NFrames, 0, false);
            tToc = toc;
            pause(0.4-tToc);
            toc;
            while((Scp.mmc.getRemainingImageCount()>0) || (Scp.mmc.isSequenceRunning(Scp.mmc.getCameraDevice())))
                if (Scp.mmc.getRemainingImageCount()>0)
                    timg = Scp.mmc.popNextTaggedImage();
                    img = Scp.studio.data().convertTaggedImage(timg, builder.time(curFrame).build(),'');
                    store.putImage(img);
                    curFrame=curFrame+1;
                    clear timg;
                    Scp.mmc.getRemainingImageCount();
                else
                    Scp.mmc.sleep(min(Scp.Exposure,10));
                end
            end

            while store.getNumImages<NFrames %fix annoying -1 problem - AOY
                timg = Scp.mmc.getTaggedImage;
                curFrame=curFrame+1;
                img = Scp.studio.data().convertTaggedImage(timg, builder.time(curFrame).build(),'');
                store.putImage(img);
                clear timg;
            end

            Scp.mmc.stopSequenceAcquisition();
            store.close();
            clear store;
            fprintf('OK\n')
        end

        function plotTimeStamps(Scp)
            %%
            figure,
            Tall = Scp.TimeStamp(:,2);
            Tall = cat(1,Tall{:});
            Tall = Tall-Tall(1);
            Tall=Tall*24*3600;
            stem(diff(Tall)), set(gca,'xtick',1:numel(Tall),'xticklabel',Scp.TimeStamp(2:end,1))
        end

        function doFlatFieldForAcqDataWithUserConfirmation(Scp,AcqData)
            %%
            for i=1:numel(AcqData)
                Scp.Channel=AcqData(i).Channel;
                Scp.Exposure=AcqData(i).Exposure;
                %                 flt = createFlatFieldImage(Scp,'filter',true,'iter',5,'assign',true);
                flt = createFlatFieldImage(Scp,'filter',true,'iter',5,'assign',true,'meanormedian','median','xymove',0.1,'open',strel('disk',250),'gauss',fspecial('gauss',150,75));
                Scp.snapImage;
                figure(321)
                imagesc(flt);
                reply = input('Did the flatfield work? Y/N [Y]: ', 's');
                if isempty(reply)
                    reply = 'Y';
                end
                ok=strcmp('Y',reply);
                if ~ok
                    error('There was an error in flatfield - please do it again');
                end

            end
        end

        function saveFlatFieldsInPlace(Scp,AcqData)
            for i=1:numel(AcqData)
                if ~AcqData(i).Triggered
                    Scp.updateState(AcqData(i));
                end
                try
                    flt = getFlatFieldImage(Scp);
                    filename = sprintf('flt_%s.tif',Scp.CurrentFlatFieldConfig);
                catch
                    warning('Flat field failed with channel %s, error message %s, moving on...',Scp.Channel,e.message);
                    flt=ones([Scp.Height Scp.Width]);
                    filename=sprintf('flt_%s.tif',AcqData(i).Channel);
                end


                %% save that channel to drive outside of metadata
                imwrite(uint16(mat2gray(flt)*2^16),fullfile(Scp.pth,filename));
            end
        end

        % get the flat field for current configuration
        function flt = getFlatFieldImage(Scp,varargin)

            try
                arg.flatfieldconfig = char(Scp.mmc.getCurrentConfig('FlatField'));
                arg.x1p5 = 0;
                arg = parseVarargin(varargin,arg);
                fltname = arg.flatfieldconfig;
                assert(isfield(Scp.FlatFields,fltname),'Missing Flat field')
                flt = Scp.FlatFields.(fltname);
                if Scp.Optovar==1.5
                    fltbig = imresize(flt,1.5);
                    flt = imcrop(fltbig,[504 512 fliplr(size(img))]);
                    flt = flt(2:end,2:end);
                end
                flt = imresize(flt,[Scp.Width Scp.Height]);
            catch e
                warning('Flat field failed with channel %s, error message %s, moving on...',Scp.Channel,e.message);
                flt=ones([Scp.Width Scp.Height]);
            end
        end

        function  img = doFlatFieldCorrection(Scp,img,varargin)
            arg.offset = 100;
            arg.percenttozeros = 0.05;
            arg = parseVarargin(varargin,arg);

            flt = getFlatFieldImage(Scp,varargin);
            img = (img-arg.offset/2^Scp.BitDepth)./flt+arg.offset/2^Scp.BitDepth;
            img(flt<arg.percenttozeros) = prctile(img(unidrnd(numel(img),10000,1)),1); % to save time, look at random 10K pixels and not all of them...
            % deal with artifacts
            img(img<0)=0;
            img(img>1)=1;
        end

        function acqname = initAcq(Scp,AcqData,varargin)

            arg.baseacqname='acq';
            arg.show=Scp.acqshow;
            arg.save=Scp.acqsave;
            arg.closewhendone=false;
            arg = parseVarargin(varargin,arg);

            switch arg.show
                case 'multi'
                    arg.show = true;
                case 'single'
                    arg.show = false;
                case 'channel'
                    arg.show = false;
                    sz = size(imresize(zeros(Scp.Height,Scp.Width),Scp.Stk.resize));
                    Scp.Stk.data = zeros([sz Scp.Tpnts.N]);
                case 'hybe'
                    arg.show = false;
                    arg.acqshow = false;
                case 'none'
                    arg.show = false;
                otherwise
                    error('Requested image display mechanism is wrong');
            end

            %% fill in empty Position, Timepoints
            if isempty(Scp.Tpnts)
                Scp.Tpnts = Timepoints;
                Scp.Tpnts.initAsNow;
            end

            if isempty(Scp.Pos)
                Scp.Pos = Positions;
                Scp.Pos.Labels = {'here'};
                Scp.Pos.List = Scp.XY;
                Scp.Pos.Group = {'here'};
            end

            Scp.FrameCount = zeros(Scp.Pos.N,1);

            %% update FrameID and create
            Scp.frameID = Scp.frameID+1;
            acqname = [arg.baseacqname '_' num2str(Scp.frameID)];

            %% set up the MM acqusition
            if Scp.MMversion < 2
                Scp.studio.openAcquisition(acqname,Scp.pth,Scp.Tpnts.num, length(AcqData), 1,Scp.Pos.N,arg.show,arg.save)
            end
            Scp.openAcq{end+1}=acqname;
            %             DataManager = Scp.studio.data;
            %             acqpth = fullfile(Scp.pth,acqname);
            %             Scp.CurrentDatastore = DataManager.createSinglePlaneTIFFSeriesDatastore(acqpth);


            %% Init Metadata criterias
            Scp.MD = Metadata(fullfile(Scp.pth,acqname),acqname);
            Scp.MD.Description = Scp.ExperimentDescription;

        end

        %         function ver = get.MMversion(Scp)
        %             %%
        %             try
        %                 verstr = Scp.studio.getVersion;
        %             catch
        %                 verstr = Scp.studio.getVersion;
        %             end
        %             prts = regexp(char(verstr),'\.','split');
        %             ver = str2double([prts{1} '.' prts{2}]);
        %         end

        function acquire(Scp,AcqData,varargin)

            %% parse optional input arguments
            arg.baseacqname='acq';
            arg.show=Scp.acqshow;
            arg.save=Scp.acqsave;
            arg.closewhendone=false;
            arg.type = 'time(site)';
            arg.func = [];
            arg.acqname = '';
            arg.dz=[];
            arg.metadata=true;
            arg.channelfirst = true; % used for Z stack
            arg.dooncepertimepoint = {};
            arg.calibrate = false;
            arg.autoshutter = true;
            arg.continousimaging = false;
            %arg.delay = false;
            arg = parseVarargin(varargin,arg);


            %% Init Acq
            if isempty(arg.acqname)
                acqname = Scp.initAcq(AcqData,arg);
            else
                acqname = arg.acqname;
            end

            if ~isempty(Scp.shiftfilepath)
                Scp.initShiftFile
            end

            if Scp.Strobbing
                Scp.prepareProcessingFilesBefore(AcqData);
            end

            %% start camera (if asked for and only single channel)
            if arg.continousimaging && length(AcqData)==1 && AcqData(1).Exposure<100
                Scp.ContinousImaging = true; 
                Scp.mmc.stopSequenceAcquisition()
                Scp.mmc.startContinuousSequenceAcquisition(0)
            end
            % update state to the first acqdata in case tehre is only one
            % channel and then we won't update this in acqFrame to save
            % time
            Scp.updateState(AcqData(1))

            %% Add channel sequence to trigger device (if any)
            Scp.setTriggerChannelSequence(AcqData);

            %% save all flat-field images
            for i=1:numel(AcqData)
                if ~AcqData(i).Triggered
                    Scp.updateState(AcqData(i));
                end
                try
                    flt = getFlatFieldImage(Scp);
                    filename = sprintf('flt_%s.tif',Scp.CurrentFlatFieldConfig);
                catch
                    flt=ones([Scp.Height Scp.Width]);
                    filename=sprintf('flt_%s.tif',AcqData(i).Channel);
                end


                %% save that channel to drive outside of metadata
                imwrite(uint16(mat2gray(flt)*2^16),fullfile(Scp.pth,filename));
            end

            %% set up acq function
            if isempty(arg.func)
                if isempty(arg.dz)
                    arg.func = @() acqFrame(Scp,AcqData,acqname);
                else
                    if arg.calibrate
                        arg.func = @() acqZcalibration(Scp, AcqData, acqname, arg.dz, 'channelfirst', arg.channelfirst);
                    else
                        arg.func = @() acqZstack(Scp,AcqData,acqname,arg.dz,'channelfirst',arg.channelfirst,'autoshutter',arg.autoshutter);
                    end
                end
            end

            %% start a mutli-time / Multi-position / Multi-Z acquisition
            switch arg.type
                case 'time(site)'
                    func = @() multiSiteAction(Scp,arg.func);
                    if ~isempty(arg.dooncepertimepoint)
                        func = [arg.dooncepertimepoint {func}];
                    end
                    multiTimepointAction(Scp,func);
                case 'site(time)'
                    func = @() multiTimepointAction(Scp,arg.func);
                    multiSiteAction(Scp,func);
            end
            if arg.metadata && ~isempty(Scp.MD.ImgFiles)
                Scp.MD.saveMetadata(fullfile(Scp.pth,acqname));
            end

            if arg.continousimaging
                Scp.mmc.stopSequenceAcquisition()
                Scp.ContinousImaging = false; 
            end

        end

        function initShiftFile(Scp)
            if ~isempty(Scp.shiftfilepath)
                shiftfilename = fullfile(Scp.shiftfilepath,'shiftfile.txt');
                fprintf('Init shift file at %s\n',shiftfilename); % still advance the position list
                fid = fopen(shiftfilename, 'wt' );
                fprintf( fid, '%s\n', 'dX=0');
                fprintf( fid, '%s\n', 'dY=0');
                fprintf( fid, '%s', 'dZ=0');
                fclose(fid);
            else
                fprintf('Please add path to Scp.shiftfilepath\n')
            end
        end
        function [dX,dY,dZ] = parseShiftFile(Scp)
            if ~isempty(Scp.shiftfilepath)
                shiftfilename = fullfile(Scp.shiftfilepath,'shiftfile.txt');
                fid = fopen(shiftfilename, 'r' );
                tline = fgetl(fid);
                while ischar(tline)
                    [~,eind] = regexp(tline,'dX=');
                    if ~isempty(eind)
                        dX = str2double(tline(eind+1:end));
                    end
                    [~,eind] = regexp(tline,'dY=');
                    if ~isempty(eind)
                        dY = str2double(tline(eind+1:end));
                    end
                    [~,eind] = regexp(tline,'dZ=');
                    if ~isempty(eind)
                        dZ = str2double(tline(eind+1:end));
                    end
                    tline = fgetl(fid);
                end
                fclose(fid);
            else
                dX=0;
                dY=0;
                dZ=0;
            end

        end

        function logError(Scp,msg,varargin)
            T = cell2table(Scp.TimeStamp,'VariableNames',{'What','When'});
            filename=fullfile(Scp.ErrorLogPth,sprintf('ScopeTimestamps_%s.csv',datestr(now,30)));
            writetable(T,filename);
            fid=fopen(fullfile(Scp.ErrorLogPth,'ErrorMessages.txt'),'a');
            fprintf(fid,'Time: %s Message %s\n',datestr(now,30),msg);
            fclose(fid);
        end

        function unloadAll(Scp)
            Scp.mmc.unloadAllDevices;
            Scp.mmc=[];
            Scp.studio=[];
        end

        function FlatFieldConfig = get.CurrentFlatFieldConfig(Scp)
            FlatFieldConfig = char(Scp.mmc.getCurrentConfig('FlatField'));
        end

        function set.Username(Scp,username)
            Scp.Username=username;
        end

        function set.Dataset(Scp,Dataset)

            %% set Dataset
            Scp.Dataset=Dataset;

            %% clear everything but Scp
            evalin('base','keep Scp');
            %% init timestamp

            Scp.TimeStamp = 'reset';
        end

        function pth = get.pth(Scp)
            if isempty(Scp.Username) || isempty(Scp.Project) || isempty(Scp.Dataset)
                errordlg('Please define Username, Project and Dataset');
                error('Please define Username, Project and Dataset');
            end
            pth = fullfile(Scp.basePath,Scp.Username,Scp.Project,[Scp.Dataset '_' datestr(floor(Scp.TimeStamp{1,2}),'yyyymmmdd')]);
            if ~exist(pth,'dir')
                mkdir(pth)
            end
        end

        function relpth = get.relpth(Scp)
            if isempty(Scp.Username) || isempty(Scp.Project) || isempty(Scp.Dataset)
                errordlg('Please define Username, Project and Dataset');
                error('Please define Username, Project and Dataset');
            end
            relpth = fullfile(Scp.Username,Scp.Project,[Scp.Dataset '_' datestr(now,'yyyymmmdd')]);
        end


        %% "Abstract" methods that have to be overloaded before use.
        function Texpose = lightExposure(Scp,ExcitationPosition,Time,varargin) %#ok<INUSD,STOUT>
            error('Not implemented in Scope - overload to use!')
        end

        function AcqData = optimizeChannelOrder(Scp,AcqData)  %#ok<INUSD>
            error('Not implemented in Scope - overload to use!')
        end

        function [z,s]=autofocus(Scp,AcqData) %#ok<STOUT,INUSD>
            error('Not implemented in Scope - overload to use!')
        end

        %% Accesory functions
        function plotTempHumodity(Scp,fig)
            if nargin==1
                fig=figure;
            end
            T=Scp.TempLog;
            H=Scp.HumidityLog;
            Tmin=min([T(:,1); H(:,1)]);
            figure(fig)
            plot(T(:,1)-Tmin,T(:,2),H(:,1)-Tmin,H(:,2))
        end

        function multiSiteAction(Scp,func)
            % func is a function that gets one input - an index in the
            % Scp.Pos postion list

            % init Pos to make sure that next is well defined at the first
            % potision
            Scp.Pos.init;
            Scp.SkipCounter=Scp.SkipCounter+1;

            %% Multi-position loop
            for j=1:Scp.Pos.NVis

                %% get Skip value
                skp = Scp.Pos.getSkipForNextPosition;
                if Scp.SkipCounter>1 && mod(Scp.SkipCounter,skp) % if we get a value different than 0 it means that this could be skipped
                    fprintf('Skipping position %s, counter at %g\n',Scp.Pos.next,Scp.SkipCounter); % still advance the position list
                    continue %skip the goto and func calls
                end

                %% adjust position shift
                [dX,dY,dZ] = Scp.parseShiftFile;
                if dX>Scp.XYpercision
                    Scp.X = Scp.X+dX;
                end
                if dY>Scp.XYpercision
                    Scp.Y = Scp.Y+dY;
                end
                if dZ>Scp.Zpercision
                    Scp.Z = Scp.Z+dZ;
                end

                %% goto position
                Scp.goto(Scp.Pos.next,Scp.Pos);

                %% perfrom action
                if iscell(func)
                    for i=1:numel(func)
                        func{i}();
                    end
                else
                    func();
                end
            end
        end

        function multiTimepointAction(Scp,func)

            Scp.Tpnts.start(10); % start in 1 sec delay
            Tnxt = Scp.Tpnts.next;
            %                 Tindx = Scp.Tpnts.current
            while ~isempty(Tnxt)
                %% prompt status
                fprintf('\nTask %g out of %g.\n Time till end: %s\n',Scp.Tpnts.current,Scp.Tpnts.N,datestr(Scp.Tpnts.Tabs(end)/3600/24-now,13))
                fprintf('\n');
                % run whatever function asked for.
                if iscell(func)
                    for i=1:numel(func)
                        func{i}();
                    end
                else
                    func();
                end

                Tpeek = Scp.Tpnts.peek;
                Tnxt = Scp.Tpnts.next;
                if isempty(Tnxt), continue, end
                % if there is some time till end of task - wait for it...
                if now*24*3600 < Tpeek
                    fprintf('Pause time till end of task: %s\n',datestr(Tpeek/3600/24-now,13));
                    while now*24*3600<Tpeek
                        fprintf('\b\b\b\b\b\b\b\b%s',datestr(Tpeek/3600/24-now,13))
                        pause(0.1)
                    end
                end

            end
        end

        function saveFlatFieldStack(Scp,varargin)
            response = questdlg('Do you really want to save FlatField to drive (it will override older FlatField data!!!','Warning - about to overwrite data');
            if strcmp(response,'Yes')
                FlatField=Scp.FlatFields;  %#ok<NASGU>
                save(Scp.FlatFieldsFileName,'FlatField');
            end
        end

        function loadFlatFields(Scp)
            s = load(Scp.FlatFieldsFileName);
            Scp.FlatFields = s.FlatField;
        end

        function [flt,stk] = createFlatFieldImage(Scp,varargin)

            %%
            arg.iter = 10;
            arg.channel = Scp.Channel;
            arg.exposure = Scp.Exposure;
            arg.assign = true;
            arg.filter = false;
            arg.meanormedian = 'mean';
            arg.xymove = 0.1;
            arg.open=strel('disk',50);
            arg.gauss=fspecial('gauss',75,25);
            arg.cameraoffset = 3841.4;
            % will try to avoid saturation defined as pixel =0 (MM trick or
            % by the function handle in arg.saturation.
            arg.saturation = @(x) x>20000/2^16; % to disable use: @(x) false(size(x));
            arg = parseVarargin(varargin,arg);

            Scp.CorrectFlatField = 0;

            XY0 = Scp.XY;

            Scp.Channel = arg.channel;
            Scp.Exposure = arg.exposure;
            stk = zeros(Scp.Height,Scp.Width,arg.iter);
            for i=1:arg.iter
                if arg.iter>1
                    Scp.XY=XY0+randn(1,2)*Scp.Width.*Scp.PixelSize*arg.xymove;
                end
                Scp.mmc.waitForSystem;
                %%
                img = Scp.snapImage;
                iter=0;
                while nnz(img==0) > 0.01*numel(img) || nnz(arg.saturation(img)) > 0.01*numel(img)
                    Scp.Exposure = Scp.Exposure./2;
                    img = Scp.snapImage;
                    iter=iter+1;
                    if iter>10, error('Couldn''t get exposure lower enough to match saturation conditions, dilute dye'); end
                end
                img = medfilt2(img); %remove spots that are up to 50 pixel dize
                stk(:,:,i) = img;
            end

            switch arg.meanormedian
                case 'mean'
                    flt = nanmean(stk,3);
                case 'median'
                    flt = nanmedian(stk,3);
            end
            if arg.filter
                msk = flt>prctile(img(:),5);
                flt = imopen(flt,arg.open);
                flt(~msk)=nan;
                flt = imfilter(flt,arg.gauss,'symmetric');
            end
            flt = flt-arg.cameraoffset/2^Scp.BitDepth;
            flt = flt./nanmean(flt(:));

            %% assign to FlatField
            if arg.assign
                Scp.FlatFields.(char(Scp.mmc.getCurrentConfig('FlatField')))=flt;
            end

            Scp.CorrectFlatField = 1;

        end

        function plotAFcurve(Scp,~)
            if ~strcmp(Scp.AutoFocusType,'software')
                warning('Can only plot AF curve in software mode')
                return
            end
            S=Scp.AFscr(:,2);

            nrmscr=mat2gray(S);
            f = fit(Scp.AFgrid(:),nrmscr(:),'gauss1');
            Zfine=linspace(min(Scp.AFgrid(:)),max(Scp.AFgrid(:)),10000);
            scrfit = feval(f,Zfine);
            [~,mi]=max(scrfit);
            Zfcs=Zfine(mi);

            figure(arg.fig)
            clf
            [~,ordr]=sort(Scp.AFgrid);
            plot(Scp.AFgrid(ordr),mat2gray(S(ordr)),'.',Zfine,scrfit,'-b',[Zfcs Zfcs],[0 1],'--r');

        end

        function lbl = whereami(Scp)
            d=distance(Scp.XY',[Scp.Chamber.Xcenter(:) Scp.Chamber.Ycenter(:)]');
            [~,mi]=min(d);
            lbl = Scp.Chamber.Wells(mi);
        end

        function goto(Scp,label,Pos,varargin)

            Scp.TimeStamp = 'startmove';
            arg.plot = Scp.plotPlate;
            arg.single = true;
            arg.feature='';
            arg = parseVarargin(varargin,arg);

            if nargin==2 || isempty(Pos) % no position list provided
                Pos  = Scp.createPositions('tmp',true,'prefix','');
                single = arg.single;
            else
                if ~isa(Pos,'Positions')
                    Pos = Scp.Pos;
                end
                single = false;
            end

            if isempty(arg.feature)
                xyz = Pos.getPositionFromLabel(label);
            else
                AllFeatureNames = {Scp.Chamber.Features.Name};
                assert(ismember(arg.feature,AllFeatureNames),'Selected feature not define in plate configuration')
                AllFeatureXY = cat(1,Scp.Chamber.Features.XY);
                xyz = AllFeatureXY(ismember(AllFeatureNames,arg.feature),:);
                label = arg.feature;
            end
            if isempty(xyz)
                error('Couldn''t find position with label %s',label);
            end
            fprintf('Moved to position: %s\n',label)
            if strcmp(Pos.axis{1},'XY')
                Scp.XY=xyz;
            else
                for i=1:length(Pos.axis)
                    switch Pos.axis{i}
                        case 'X'
                            Scp.X=xyz(i);
                        case 'Y'
                            Scp.Y=xyz(i);
                        case 'Z'
                            Scp.Z=xyz(i);
                        case 'Angle'
                            Scp.Angle=xyz(i);
                    end
                end
            end

            % update display (unless low overhead is enabled)
            if ~Scp.reduceAllOverheadForSpeed && arg.plot
                plot(Pos,Scp,'fig',Scp.Chamber.Fig.fig,'label',label,'single',single);
            end

            %pause(1);
            Scp.TimeStamp = 'endmove';
            ifMulti = regexp(label,'_');
            if ifMulti
                label = label(1:ifMulti(1)-1);
            end
%             if ~Scp.Strobbing
%                 err =~strcmp(Scp.whereami,label); %return err=1 if end position doesnt match label
%                 if err
%                     warning('stage position doesn`t match label')
%                 end
%             end
        end

        function when = getTimeStamp(Scp,what)
            ix = ismember(Scp.TimeStamp(:,1),what);
            if ~any(ix)
                when=nan;
                return
            end
            when = cat(1,Scp.TimeStamp{ix,2});
            when=when-Scp.TimeStamp{1,2};
            when=when*24*60*60;
        end

        function updateState(Scp,AcqData)

            %% set AcqData to the one that is being used
            assert(isa(AcqData, 'AcquisitionData'), 'AcqData is not of AcquisitionData class');
            Scp.AcqData = AcqData;

            %% change the scope state to be what is required by AcqData
            % change channel (only if needed othwise it will time out)
            if ~strcmp(Scp.Channel,AcqData.Channel)
                Scp.Channel=AcqData.Channel;
            end

            %% exposure
            Scp.Exposure=AcqData.Exposure;

            %% dZ option between channels
            if ~isempty(AcqData.dZ) && AcqData.dZ~=0
                fprintf('dZ\n');
                Scp.Z=Scp.Z+AcqData.dZ;
            end
        end

        function xy=rc2xy(Scp,rc,varargin)
            % convert a row, colum indexing of an image acquired at curret
            % XY (or user supplied) to XY stage coordinates of that image;

            % parse inputs
            arg.xy=Scp.XY;
            arg.pixelsize=Scp.PixelSize;
            arg.cameratranspose = false; % false means that image colums are X stage, false it is Y
            arg.cameradirection=[1 1]; % YX if positive movements in stage result in positive coordinate change of control point then this is 1 otherwise -1 because movements in images are in opposite direction on the stage
            arg.camera_angle = Scp.CameraAngle;
            arg = parseVarargin(varargin,arg);
            rc=rc-[Scp.Width Scp.Height]/2;
            rc = rc*[cosd(arg.camera_angle) sind(arg.camera_angle); [-1*sind(arg.camera_angle) cosd(arg.camera_angle)]];
            if ~arg.cameratranspose
                xy(1)=rc(2)*arg.pixelsize*arg.cameradirection(1)+arg.xy(1);
                xy(2)=rc(1)*arg.pixelsize*arg.cameradirection(2)+arg.xy(2);
            else
                xy(1)=rc(1)*arg.pixelsize*arg.cameradirection(2)+arg.xy(1);
                xy(2)=rc(2)*arg.pixelsize*arg.cameradirection(1)+arg.xy(2);
            end

        end

        function moveByStageAFrame(Scp,direction,overlap)
            if nargin==2
                overlap=1;
            end
            frmX = Scp.mmc.getPixelSizeUm*Scp.Width*overlap;
            frmY = Scp.mmc.getPixelSizeUm*Scp.Height*overlap;
            switch direction
                case 'north'
                    dxdy=[0 1];
                case 'south'
                    dxdy=[0 -1];
                case 'west'
                    dxdy=[1 0];
                case 'east'
                    dxdy=[-1 0];
                case 'northeast'
                    dxdy=[-1 1];
                case 'northwest'
                    dxdy=[1 1];
                case 'southeast'
                    dxdy=[-1 -1];
                case 'southwest'
                    dxdy=[1 -1];
                otherwise
                    dxdy=[0 0];
                    warning('Unrecognized direction - not moving'); %#ok<*WNTAG>
            end
            Scp.XY=[Scp.X+dxdy(1)*frmX Scp.Y+dxdy(2)*frmY];
        end

        function Pos = createPositionFromMM(Scp,varargin)
            arg.updateScp = true;
            arg.labels={};
            arg.groups={};
            arg.axis={'XY'};
            arg.message = 'Please click when you finished marking position';
            arg.experimentdata=struct([]);
            arg.postype = 'standard';
            arg = parseVarargin(varargin,arg);

            if Scp.MMversion < 1.5
                Scp.studio.showXYPositionList;
                uiwait(msgbox(arg.message))
                PL = Scp.studio.getPositionList;
            else
                arg.message = ['Please open up position dialog in MM',newline,'Tools>Stage Position List',newline,'Click OK when Done'];
                PLM = Scp.studio.getPositionListManager;
                PL = PLM.getPositionList;
                PLM.setPositionList(PL);
                uiwait(msgbox(arg.message))
                PL = PLM.getPositionList;
            end

            switch arg.postype
                case 'standard'
                    Pos = Positions(PL,'axis',arg.axis);
                case 'relative'
                    Pos = RelativePositions(PL,'axis',arg.axis);
                case 'beads'
                    Pos = RelativePositionsUsingBeads(PL,'axis',arg.axis);
            end
            if ~isempty(arg.labels)
                Pos.Labels = arg.labels;
                if isempty(arg.groups)
                    Pos.Group=arg.labels;
                end
            end
            if ~isempty(arg.groups)
                Pos.Group=arg.groups;
            end
            if ~isempty(arg.experimentdata)
                Pos.addMetadata(Pos.Labels,[],[],'experimentdata',arg.experimentdata);
            end
            if arg.updateScp
                Scp.Pos = Pos;
            end
        end

        function set.Pos(Scp,Pos)
            % make sure Pos is of the right type;
            assert(isempty(Pos) || isa(Pos,'Positions'));
            Scp.Pos = Pos;
        end

        function createPositionFromDraw(Scp,varargin)
            arg.acqdata = AcquisitionData;
            arg.acqdata(1).Channel = 'DeepBlue';
            arg.acqdata(1).Exposure = 50; %
            arg.stitched_pixel_size = 10;
            arg.input_pixel_size = 0.326;
            arg.output_pixel_size = 0.103;
            arg.rotate = 90; % 90,180,270
            arg.background = false;
            arg.flip = 2; %dim
            arg.x = 1; %dim
            arg.y = 2; %dim
            arg.image_thresh = 0;
            arg.small_object_thesh = 500;
            args.dialate_size = 75;
            arg.acq_name = '';
            arg.overlap = 0;
            arg = parseVarargin(varargin,arg);
            if isempty(arg.acq_name)
                %% Create Positions
                Scp.createPositionFromMM();
                %Scp.Pos.optimizeOrder;
                %% Acquire Low Mag
                %Scp.AutoFocusType = 'none';
                Scp.acquire(arg.acqdata,'autoshutter', true)
                %% Load Images and Coordinates
                listing = dir(Scp.pth);
                for i=1:length(listing)
                    if contains(listing(i).name,'acq')
                        acq_name = listing(i).name;
                    end
                end
            else
                acq_name = arg.acq_name;
            end
            md = Metadata(Scp.pth);
            [Images, idxes] = md.stkread('Channel', arg.acqdata(1).Channel, 'acq', acq_name, 'flatfieldcorrection', false);
            disp(size(Images))
            disp(size(idxes))
            XY_Cell = md.getSpecificMetadataByIndex('XY', idxes);
            XY_Cell = cell2mat(XY_Cell);
            %% Stitch
            x = arg.x;
            y = arg.y;
            border = 3000; %um
            xy_min = min(XY_Cell)-border;
            xy_max = max(XY_Cell)+border;
            x_range = linspace(xy_min(x),xy_max(x)+1,round((1+xy_max(x)-xy_min(x))/arg.stitched_pixel_size));
            y_range = linspace(xy_min(y),xy_max(y)+1,round((1+xy_max(y)-xy_min(y))/arg.stitched_pixel_size));
            stitched = zeros(length(x_range(:)),length(y_range(:)));
            for i=1:size(Images,3)
                img_xy = XY_Cell(i,:);
                img = Images(:,:,i);
                if arg.background
                    img = imgaussfilt(img-imgaussfilt(img,100),5); % To make features more visible % Move from hard code
                end
                % Correct Orientation
                if arg.rotate~=0
                    img = imrotate(img,arg.rotate);
                end
                if arg.flip~=0
                    img = flip(img,arg.flip);
                end
                % Resize Image
                shape = round(size(img)*arg.input_pixel_size/arg.stitched_pixel_size);
                img = imresize(img,shape);
                %populate
                x_lower_bound = round((img_xy(x)-xy_min(x))/arg.stitched_pixel_size)+1-(shape(x)/2);
                x_upper_bound = round((img_xy(x)-xy_min(x))/arg.stitched_pixel_size)+(shape(x)/2);
                y_lower_bound = round((img_xy(y)-xy_min(y))/arg.stitched_pixel_size)+1-(shape(y)/2);
                y_upper_bound = round((img_xy(y)-xy_min(y))/arg.stitched_pixel_size)+(shape(y)/2);
                old_img = stitched(x_lower_bound:x_upper_bound,y_lower_bound:y_upper_bound);
                merge = cat(3,old_img,img);
                merge = max(merge,[],3);
                stitched(x_lower_bound:x_upper_bound,y_lower_bound:y_upper_bound) = merge;
            end
            stitched = stitched-prctile(stitched(:),50);
            stitched(stitched<0) = 0;
            %             imshow(imadjust(stitched));
            if arg.image_thresh>0
                totMask = stitched>arg.image_thresh;
                % Fill Holes
                totMask = imfill(totMask,'holes');
                % Remove Small Objects
                totMask = bwareaopen(totMask,arg.small_object_thesh);
                % Dialate
                SE = offsetstrel('ball',args.dialate_size,args.dialate_size);
                totMask = imdilate(totMask,SE);

                %% Find ROI By Binarizing Stitched
            else
                satisfied = false;
                while ~satisfied
                    %% Find ROI
                    message = ['Instructions:',newline,'Draw a ROI',newline,'Double Click on line',newline,'Repeat for all ROI',newline,'To Exit: Click on empty space',newline,'double click on same empty space to exit'];
                    h = msgbox(message);
                    set(h,'Position',[350 550 250 100])
                    Image = stitched;
                    figure(89) % Add instructions here
                    imshow(imadjust(Image))
                    title('Draw ROI')
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
                    answer = questdlg(['Are you happy with your drawing skills?',newline,'If Position Is not Good Click Hide'], ...
                        'Happy?', ...
                        'Yes','No','No');
                    switch answer
                        case 'Yes'
                            satisfied = true;
                    end
                end
            end
            % Downsample with max so that each pixel is the size of a image
            % Adjust for overlap
            arg.output_pixel_size = arg.output_pixel_size*(1-arg.overlap);
            % Dialate to ensure you capture everything
            SE = strel("disk",args.dialate_size,8);
            totMask = imdilate(totMask,SE);
            % in output magnification
            OutputImageSize = round((size(Images,1:2)*arg.output_pixel_size)/arg.stitched_pixel_size);
            % causing weird rounding issue?
            Blocks = imresize(totMask,[round(size(totMask,x)/OutputImageSize(y)),round(size(totMask,y)/OutputImageSize(x))],"nearest","Antialiasing",false);
            [row,column,~] = find(Blocks==1);
            % Now go back to stage coordinates
            output_x_range = linspace(xy_min(x),xy_max(x)+1,size(Blocks,x));
            output_y_range = linspace(xy_min(y),xy_max(y)+1,size(Blocks,y));
            pos_x_coords = output_x_range(row);
            pos_y_coords = output_y_range(column);
            % These look good!
            Coordinates = (vertcat(pos_x_coords,pos_y_coords)');
            p = Positions;
            for i = 1:size(Coordinates, 1)
                p.add(Coordinates(i, :), strcat('Pos', num2str(i)));
            end
            Scp.Pos = p;
            figure(3)
            imshow(imadjust(Image));
            hold('on');
            scatter((column-1)*size(Image,y)/size(Blocks,y),(row)*size(Image,x)/size(Blocks,x),7.5*size(Image,x)/size(Blocks,x),'s','R');
            hold('off')
        end

        %% Create Positions via Plate or MM (done outside of Function)
        function Scp = filterPositionsByDraw(Scp,varargin)
            arg.acqdata = AcquisitionData;
            arg.acqdata(1).Channel = 'DeepBlue';
            arg.acqdata(1).Exposure = 10; %
            arg.stitched_pixel_size = 10;
            arg.pixel_size = 0.490;
            arg.rotate = 90;
            arg.background = false;
            arg.flip = 0; %dim
            arg.border = 500;
            arg.thresh = 0;
            arg.x = 1; %dim
            arg.y = 2; %dim
            arg.verbose=true;
            arg.acq_name = '';
            arg.groups = true;
            arg = parseVarargin(varargin,arg);

            if isempty(arg.acq_name)
                %% Acquire Low Mag
                %Scp.AutoFocusType = 'none';
                Scp.acquire(arg.acqdata,'autoshutter', false)
                %% Load Images and Coordinates
                listing = dir(Scp.pth);
                for i=1:length(listing)
                    if contains(listing(i).name,'acq')
                        acq_name = listing(i).name;
                    end
                end
            else
                acq_name = arg.acq_name;
            end

            %% Load and Stitch
            md = Metadata(Scp.pth);
            [Images, idxes] = md.stkread('acq', acq_name, 'flatfieldcorrection', false);
            XY_Cell = md.getSpecificMetadataByIndex('XY', idxes);
            Posnames_Cell = md.getSpecificMetadataByIndex('Position', idxes);
            stitched = Scp.stitch(Images,XY_Cell, ...
                'pixel_size',arg.pixel_size, ...
                'rotate',arg.rotate, ...
                'flip',arg.flip, ...
                'border',arg.border, ...
                'x',arg.x, ...
                'y',arg.y);
            if arg.verbose
                figure(10)
                imshow(imadjust(stitched))
            end
            %% Draw Masks
            mask = Scp.drawMask(stitched);
            if arg.verbose
                figure(11)
                imshow(mask)
            end
            %% Label mask
            labelMask = bwlabel(mask);
            %% Hide Positions and Relabel
            keepers = zeros(size(Images,3),1);
            updated_posnames = cell(size(Images,3),1);
            x = arg.x;
            y = arg.y;
            XY_coordinates = round((cell2mat(XY_Cell)-min(cell2mat(XY_Cell)))/10)+1;
            XY_Limits = max(XY_coordinates)+arg.border;

            for i=1:size(Images,3)
                img_coordinates = XY_coordinates(i,:);
                img = Images(:,:,i);
                % Correct Orientation
                if arg.rotate~=0
                    img = imrotate(img,arg.rotate);
                end
                if arg.flip~=0
                    img = flip(img,arg.flip);
                end
                % Resize Image
                shape = round(size(img)*arg.pixel_size/arg.stitched_pixel_size)-1;
                %populate
                x_lower_bound = img_coordinates(x);
                x_upper_bound = x_lower_bound+shape(x);
                y_lower_bound = img_coordinates(y);
                y_upper_bound = y_lower_bound+shape(y);
                old_img = labelMask(x_lower_bound:x_upper_bound,y_lower_bound:y_upper_bound);
                if max(max(old_img(:)))>0
                    keepers(i) = 1;
                else
                    stitched(x_lower_bound:x_upper_bound,y_lower_bound:y_upper_bound) = 0;
                    keepers(i) = 0;
                end
                % Update name
                posname = Posnames_Cell{i};
                if contains(posname,'-Pos')
                    posname = strsplit(posname,'-Pos');
                elseif contains(posname,'_site')
                    posname = strsplit(posname,'_site');
                else
                    posname = {'unknown',posname};
                end
                updated_posnames{i} = ['Well',posname{1},'-Section',int2str(max(old_img(:))),'-Pos',posname{2}];
            end
            good_posnames = Posnames_Cell(keepers==1);
            good_updated_posnames = updated_posnames(keepers==1);
            Scp.Pos.Hidden = zeros(length(Scp.Pos.Labels),1);
            hidden = Scp.Pos.Hidden;
            updated_Pos_Labels = Scp.Pos.Labels;
            for i=1:size(Scp.Pos.Labels,1)
                m = strcmp(good_posnames,Scp.Pos.Labels(i));
                if any(m)
                    updated_Pos_Labels{i} = good_updated_posnames{m};
                else
                    hidden(i) = 1;
                end
            end
            Scp.Pos.Labels = updated_Pos_Labels;
            Scp.Pos.Hidden = hidden;
            if arg.verbose
                figure(12)
                imshow(imadjust(stitched))
            end
        end

        function stitched = stitch(Scp,Images,XY_Cell,varargin)
            arg.stitched_pixel_size = 10;
            arg.pixel_size = 0.490;
            arg.rotate = 90;
            arg.background = false;
            arg.flip = 0; %dim
            arg.x = 1; %dim
            arg.y = 2; %dim
            arg.border = 500;
            arg = parseVarargin(varargin,arg);
            x = arg.x;
            y = arg.y;
            XY_coordinates = round((cell2mat(XY_Cell)-min(cell2mat(XY_Cell)))/10)+1;
            XY_Limits = max(XY_coordinates)+arg.border;
            stitched = zeros(XY_Limits(x),XY_Limits(y));
%             f = waitbar(0, 'Starting');
            for i=1:size(Images,3)
%                 waitbar(i/size(Images,3), f, sprintf('Progress: %d %%', floor(i/size(Images,3)*100)));
                img_coordinates = XY_coordinates(i,:);
                img = Images(:,:,i);
%                 %%
%                 img = img-mean(img(:));
%                 img = img/std(img(:));
                %%
                % Correct Orientation
                if arg.rotate~=0
                    img = imrotate(img,arg.rotate);
                end
                if arg.flip~=0
                    img = flip(img,arg.flip);
                end
                % Resize Image
                shape = round(size(img)*arg.pixel_size/arg.stitched_pixel_size)-1;
                img = imresize(img,shape+1);

                %populate
                x_lower_bound = img_coordinates(x);
                x_upper_bound = x_lower_bound+shape(x);
                y_lower_bound = img_coordinates(y);
                y_upper_bound = y_lower_bound+shape(y);
                old_img = stitched(x_lower_bound:x_upper_bound,y_lower_bound:y_upper_bound);
                merge = cat(3,old_img,img);
                merge = max(merge,[],3);
                stitched(x_lower_bound:x_upper_bound,y_lower_bound:y_upper_bound) = merge;
            end
        end

        function mask = drawMask(Scp,Image,varargin)
            arg.remove_borders = true;
            arg = parseVarargin(varargin,arg);
            if arg.remove_borders
                final_mask = zeros(size(Image));
            end
            satisfied = false;
            while ~satisfied
                % Find ROI
                message = ['Instructions:',newline,'Draw a ROI',newline,'Double Click on line',newline,'Repeat for all ROI',newline,'To Exit: Click on empty space',newline,'double click on same empty space to exit'];
                h = msgbox(message);
                set(h,'Position',[350 550 250 100])
                figure(89) % Add instructions here
                imshow(imadjust(Image))
                title('Draw ROI')
                mask = false(size(Image));
                h = imfreehand(gca); setColor(h,'red');
                position = wait(h);
                BW = createMask(h);
                while sum(BW(:)) > 10 % less than 10 pixels is considered empty mask
                    mask = mask | BW;
                    h = imfreehand(gca); setColor(h,'red');
                    position = wait(h);
                    BW = createMask(h);
                end
                answer = questdlg(['Are you happy with your drawing skills?',newline,'If Position Is not Good Click Hide'], ...
                    'Happy?', ...
                    'Yes','No','No');
                switch answer
                    case 'Yes'
                        satisfied = true;
                end
            end
        end


        function imageRefPoint(Scp,Label,RefAcqData,varargin)
            % make sure MD already exist
            % make sure Pos exist and is relative
            arg.move = true;
            arg = parseVarargin(varargin,arg);
            assert(isa(Scp.Pos,'RelativePositions'),'Can only add reference if Pos class is relative')

            if arg.move
                % save current positions
                XYcurr=Scp.XY;
                Zcurr=Scp.Z;

                % goto the XYZ of the last entry for that Position
                coord = getRefPoint(Scp.Pos,Label,'last');
                Scp.XY=coord(1:2);
                Scp.Z=coord(3);
            end

            if isempty(Scp.MD)
                Scp.initAcq(RefAcqData)
            end

            acqFrame(Scp,RefAcqData,Scp.MD.acqname,'t',numel(Scp.Pos.RefFeatureTimestamps),'refposname',Label)

            if arg.move
                Scp.XY=XYcurr;
                Scp.Z=Zcurr;
            end
        end

        function addPosReference(Scp,Label,funcXY,funcZ)
            % method to add a reference for all positions.
            % it gets as input two function handles for XY,Z

            % check that Pos is relative position
            assert(isa(Scp.Pos,'RelativePositions'),'Can only add reference if Pos class is relative')

            % save current positions
            XYcurr=Scp.XY;
            Zcurr=Scp.Z;

            % goto the XYZ of the last entry for that Position
            coord = getRefPoint(Scp.Pos,Label,'last');
            Scp.XY=coord(1:2);
            Scp.Z=coord(3);

            XYfeature = funcXY();
            Zfeature = funcZ();

            Scp.Pos.addRefPoint(Label,[XYfeature Zfeature]);

            Scp.XY=XYcurr;
            Scp.Z=Zcurr;

        end

        function [Pos,Xwell,Ywell] = createPositions(Scp,varargin)
            
            Plt = Scp.Chamber;
            Scp.currentAcq=Scp.currentAcq+1;
            arg.msk = true(Plt.sz);
            arg.wells = Plt.Wells;
            arg.axis={'XY'};
            arg.sitesperwell = [1 1]; % [x y]
            arg.alignsites = 'center';
            arg.sitesshape = 'grid';
            arg.spacing = 1; % percent of frame size
            arg.xrange = []; % determine sites based on range to image
            arg.yrange = [];
            arg.pixelsize = Scp.PixelSize; % um or nm
            arg.tmp = false;
            arg.experimentdata = [];
            arg.prefix = 'acq';
            arg.postype = 'standard';
            arg.optimize = false;
            arg.skip=[];
            arg.relative = false;
            arg.imagewelloverlap=[];
            arg.manualoverride = false;
            arg.enforceplatingdensity=Scp.EnforcePlatingDensity;
            arg = parseVarargin(varargin,arg);

            %Input cleansing
            if arg.pixelsize<=0
                error('Pixel size must be greater than zero.')
            end
            %% create relative grid per well
            frm = [arg.pixelsize*Scp.Width ...
                arg.pixelsize*Scp.Height];
            ttl = [frm(1)*arg.spacing*arg.sitesperwell(1) ...
                frm(2)*arg.spacing*arg.sitesperwell(2)]; %#ok<NASGU>
            dlta = [frm(1)*arg.spacing frm(2)*arg.spacing];

            [Xwell,Ywell] = meshgrid(cumsum(repmat(dlta(1), 1, arg.sitesperwell(1))), ...
                cumsum(repmat(dlta(2), 1, arg.sitesperwell(2))));
            Xwell=flipud(Xwell(:)-mean(Xwell(:)));
            Ywell=Ywell(:)-mean(Ywell(:));
            if strcmp(arg.sitesshape,'circle')
                radius = mean([max(Ywell),max(Xwell)]);
                dist = sqrt(abs(Xwell).^2 + abs(Ywell).^2);
                keepers = ones(size(Xwell,1),1);
                keepers(dist>radius) = 0;
            else
                keepers = ones(size(Xwell,1),1);
            end


            %% now create grid for all wells asked for
            ixWellsToVisit = intersect(find(arg.msk),find(ismember(Plt.Wells,arg.wells)));
            Xcntr = Plt.Xcenter;
            Ycntr = Plt.Ycenter;

            %%
            if Scp.MMversion < 1.5
                PL = Scp.studio.getPositionList;
            else
                PLM = Scp.studio.getPositionListManager;
                PL = PLM.getPositionList;
            end

            switch arg.postype
                case 'standard'
                    Pos = Positions(PL,'axis',arg.axis);
                case 'relative'
                    Pos = RelativePositions(PL,'axis',arg.axis);
                case 'beads'
                    Pos = RelativePositionsUsingBeads(PL,'axis',arg.axis);
            end

            %             %% create the position list
            %             if arg.relative
            %                 Pos=RelativePositions;
            %             else
            %                 Pos=Positions;
            %             end
            Pos.axis = arg.axis;
            Pos.PlateType = Plt.type;

            %% add to the position list well by well
            for i=1:numel(ixWellsToVisit)
                %% set up labels
                WellLabels = repmat(Plt.Wells(ixWellsToVisit(i)),prod(arg.sitesperwell),1);
                if prod(arg.sitesperwell)>1
                    for j=1:arg.sitesperwell(1)
                        for k=1:arg.sitesperwell(2)
                            cnt=(j-1)*arg.sitesperwell(2)+k;
                            WellLabels{cnt}=[WellLabels{cnt} '_site' num2str(cnt) '_' num2str(j) '_' num2str(k)];
                        end
                    end
                end

                %% add relative offset within wells for sites in this well
                [dX,dY]=Plt.getWellShift(arg.alignsites);
                switch arg.alignsites
                    case 'center'
                    case 'top'
                        dY=dY+Scp.Chamber.directionXY(2)*(Scp.PixelSize*Scp.Height*arg.sitesperwell(2)*arg.spacing)/2;
                    case 'bottom'
                        dY=dY-Scp.Chamber.directionXY(2)*(Scp.PixelSize*Scp.Height*arg.sitesperwell(2)*arg.spacing)/2;
                    case 'left'
                    case 'right'
                end

                %% set up XY
                if Pos.axis{1}=='XY'
                    WellXY = [Xcntr(ixWellsToVisit(i))+Xwell+dX Ycntr(ixWellsToVisit(i))+Ywell+dY];
                elseif numel(Pos.axis)==2
                    WellXY = [Xcntr(ixWellsToVisit(i))+Xwell+dX Ycntr(ixWellsToVisit(i))+Ywell+dY];
                elseif numel(Pos.axis)==3

                    WellXY = [Xcntr(ixWellsToVisit(i))+Xwell+dX Ycntr(ixWellsToVisit(i))+Ywell+dY, repmat(Scp.Z, numel(Xwell),1)];
                end


                %% add up to long list
                Pos = add(Pos,WellXY(keepers==1,:),WellLabels(keepers==1));

            end

            %% add experiment metadata
            if ~arg.tmp
                if ~isempty(arg.experimentdata)
                    Labels = Plt.Wells;
                    Pos.addMetadata(Labels,[],[],'experimentdata',arg.experimentdata);

                    fld=fieldnames(Pos.ExperimentMetadata);
                    fld=cellfun(@(m) lower(m),fld,'Uniformoutput',0);
                    %                     if arg.enforceplatingdensity  deprecated
                    %                         assert(any(ismember(fld,'platingdensity')),'Must provide plating density in Metadata')
                    %                         pltdens=[Pos.ExperimentMetadata.PlatingDensity];
                    %                         assert(numel(pltdens)==Pos.N,'You did not provide Plating Density per position');
                    %                         assert(all(pltdens>=0),'Must provide positive value for plating density')
                    %                         assert(all(~isnan(pltdens)),'Must provide plating density to all wells')
                    %                     end
                    %
                    %                     if arg.enforceemptywell
                    %                         assert(any(ismember(fld,'emptywells')),'Must provide at least one empty well')
                    %                         emptywell = [Pos.ExperimentMetadata.EmptyWells];
                    %                         assert(numel(emptywell)==Pos.N ,'You did not provide empty well information per position');
                    %                         assert(any(emptywell),'Must provide at least one empty well in Metadata')
                    %                     end



                else
                    %assert(~arg.enforceplatingdensity,'Must provide Metadata with platedensity')
                    %assert(~arg.enforceemptywell,'Must provide Metadata with empty well information')
                end
            end



            if ~isempty(arg.skip)
                Pos.addSkip(Plt.Wells(ixWellsToVisit),arg.skip(ixWellsToVisit));
                Scp.SkipCounter=0;
            end

            if arg.optimize
                Pos.optimizeOrder;
            end

            Pos.List(:,1)=Pos.List(:,1)+Scp.dXY(1);
            Pos.List(:,2)=Pos.List(:,2)+Scp.dXY(2);


            % allow for Z correction
            if arg.manualoverride
                unqGroup=unique(Pos.Group,'stable');
                for i=1:numel(unqGroup)
                    Scp.goto(unqGroup{i});
                    Scp.whereami
                    % find Z
                    figure(419)
                    set(419,'Windowstyle','normal','toolbar','none','menubar','none','Position',[700 892 140 75],'Name','Press when done','NumberTitle','off')
                    uicontrol(419,'Style', 'pushbutton', 'String','Done','Position',[20 20 100 35],'fontsize',13,'callback',@(~,~) close(419))
                    uiwait(419);
                    if prod(arg.sitesperwell)>1
                        ix=ismember(Pos.Group,unqGroup{i});
                        Pos.List(ix,1:2)=repmat(Scp.XY,nnz(ix),1)+[Xwell Ywell];
                        Pos.List(ix,3)=Scp.Z;
                    else
                        Pos.List(i,3)=Scp.Z;
                        Pos.List(i,1:2)=Scp.XY;
                    end
                end
                Pos.axis={'X','Y','Z'};
            end

            %% unless specified otherwise update Scp
            if ~arg.tmp
                Scp.Pos = Pos;
            end

        end

        function PossChannel = getPossibleChannels(Scp)
            posschnls=Scp.mmc.getAvailableConfigs(Scp.mmc.getChannelGroup);
            PossChannel=cell(posschnls.size,1);
            for i=1:posschnls.size
                PossChannel{i}=char(posschnls.get(i-1));
            end
        end

        function img = getLastImage(Scp)
            img = Scp.mmc.getLastImage;
            img = mat2gray(img,[0 2^Scp.BitDepth]);
            img = reshape(img,[Scp.Width Scp.Height]);
        end

        function stk = snapZstack(Scp,dZ,varargin)
            arg.uselive = true;
            % during seqence acqusition the interval is simply exposure.
            % but can't be much faster then camera frame rante (~20 fps, or
            % 50msex interval
            arg.mininterval = max(Scp.Exposure,50);
            arg = parseVarargin(varargin,arg);
            currZ = Scp.Z;
            stk = zeros([Scp.Height Scp.Width length(dZ)]);

            try
                if arg.uselive
                    Scp.mmc.setAutoShutter(0);
                    Scp.mmc.setShutterOpen(1);
                    pause(arg.mininterval/1000);
                    % clear image buffer
                    Scp.mmc.clearCircularBuffer()
                    Scp.mmc.startContinuousSequenceAcquisition(arg.mininterval);

                    % logic of the loop is as follows:
                    % we need to check each time before and after the Z
                    % movement what is the camera frame coutner and only
                    % grab an image if counter increased. If not we wait
                    % till timeout.
                    % timing is done with tic/toc, might be a fancier way
                    % :)
                    for i=1:length(dZ)
                        % move stage
                        frameCounter = Scp.mmc.getRemainingImageCount();
                        Scp.Z=currZ+dZ(i);
                        strt=now;
                        while Scp.mmc.getRemainingImageCount() == frameCounter
                            pause(arg.mininterval/1000)
                            fprintf('.');
                            if now-strt>1/24/3600
                                break
                                warning('timeout during sequence acq while performing snapZstack')
                            end
                        end

                        % altenative - clear buffer before each dZ movement
                        % and get last image.
                        % grab image and adjust as needed
                        while Scp.mmc.getRemainingImageCount() ~= frameCounter
                            img=Scp.mmc.popNextImage;
                        end
                        img=Scp.convertMMimgToMatlabFormat(img);
                        if Scp.CorrectFlatField
                            img = Scp.doFlatFieldCorrection(img);
                        end
                        % store in stk
                        stk(:,:,i)=img;
                    end
                    Scp.mmc.stopSequenceAcquisition()
                end
                if arg.uselive
                    Scp.mmc.setAutoShutter(1);
                    Scp.mmc.setShutterOpen(0);
                end
                Scp.Z = currZ;
            catch
                % if there was any error return to "normal", i.e. back to Z
                % and no light and autoshutter on
                Scp.mmc.setAutoShutter(1);
                Scp.mmc.setShutterOpen(0);
                Scp.Z = currZ;
            end

        end

        function img = snapImage(Scp)
            if ismember(Scp.acqshow,{'single','channel','FLIR'})
                showImg = true;
            else
                showImg = false;
            end
            % get image from Camera
            max_iter = 5;
            iter = 1;
            completed = false;
            img=commandCameraToCapture(Scp);
            
%             while (iter<max_iter)&(completed==false)
%                 iter = iter+1;
%                 try
%                     img=commandCameraToCapture(Scp);
%                     completed = true;
%                 catch
%                     pause(0.5)
%                 end
%                 if (iter==max_iter)&(completed==false)
%                     img=commandCameraToCapture(Scp);
%                 end
%             end
            %img=Scp.convertMMimgToMatlabFormat(timg); also appeaqrs inside
            %commandCameraToCapture
            if Scp.CorrectFlatField
                img = Scp.doFlatFieldCorrection(img);
            end
            if showImg
                if Scp.MMversion < 1.5
                    if ismember(Scp.acqshow,{'single','channel'});
                        img2 = uint16(img'*2^16);
                        Scp.studio.displayImage(img2(:));
                    else ismember(Scp.acqshow,'FLIR');
                        Scp.studio.displayImage(img(:));
                    end
                else
                    timg=Scp.mmc.getTaggedImage;
                    coords = Scp.studio.data.createCoords('t=0,p=0,c=0,z=0');
                    imgtoshow = Scp.studio.data.convertTaggedImage(timg);
                    imgtoshow = imgtoshow.copyAtCoords(coords);
                    Scp.studio.live.displayImage(imgtoshow);
                end
            end
        end

        function img=commandCameraToCapture(Scp)
            if Scp.ContinousImaging 
                pause(Scp.Exposure*1.1/1000)
                % next few lines should never be called (remove?)
                while Scp.mmc.getRemainingImageCount==0
                    pause(Scp.Exposure/3000), 
                end
                timg=Scp.mmc.getLastTaggedImage;
                img=timg.pix;
            else
                %Scp.mmc.clearCircularBuffer()
                if Scp.MMversion > 1.5
                    try
                        Scp.mmc.snapImage;
                        timg=Scp.mmc.getTaggedImage;
                        img=timg.pix;
                    catch
                        Scp.mmc.clearCircularBuffer()
                        pause(1);
                        command = 'Alert : Camera Failed to Snap Image';
                        Scp.Notifications.sendSlackMessage(Scp,[Scp.Dataset,' ',command],'all',true);
                        try
                            Scp.mmc.snapImage;
                            timg=Scp.mmc.getTaggedImage;
                            img=timg.pix;
                            command = 'Camera Recovered';
                            Scp.Notifications.sendSlackMessage(Scp,[Scp.Dataset,' ',command],'all',true);
                        catch
                            Scp.mmc.clearCircularBuffer()
                            command = 'Servere Alert : Camera Did Not Recover. Placing Empty Image';
                            Scp.Notifications.sendSlackMessage(Scp,[Scp.Dataset,' ',command],'all',true);
                            img = zeros(Scp.Width * Scp.Height,1);
                        end
                    end
                else
                    Scp.mmc.snapImage;
                    img = Scp.mmc.getImage;
                end
            end
            img=Scp.convertMMimgToMatlabFormat(img);
            if Scp.CorrectFlatField
                img = Scp.doFlatFieldCorrection(img);
            end
            Scp.lastImg = img;
        end

        function img=convertMMimgToMatlabFormat(Scp,img)
            img = double(img);%AOY and Rob, fix saturation BS.
            mask = img<0;
            img(mask)=img(mask)+2^Scp.BitDepth;
            img = reshape(img,[Scp.Width Scp.Height])';
            img = mat2gray(img,[1 2^Scp.BitDepth]);
        end

        function setTriggerChannelSequence(Scp,AcqData)
            TriggeredChannels = cat(1,AcqData.Triggered);
            indx=find(TriggeredChannels);
            if isempty(indx), return, end
            import mmcorej.StrVector;
            trgrseq = StrVector();

            for i=1:numel(indx)
                % figure out what is the label of the Trigger device in
                % the Channel config
                cnfg= Scp.mmc.getConfigData(Scp.mmc.getChannelGroup,AcqData(indx(i)).Channel);
                vrbs=char(cnfg.getVerbose());
                dvc=[Scp.TriggerDeviceName ':Label='];
                strt = strfind(vrbs,dvc )+numel(dvc);
                vrbs=vrbs(strt:end);
                DeviceLabel = strtok(vrbs,'<');
                % get state of the device based on channel name
                state=Scp.mmc.getStateFromLabel(Scp.TriggerDeviceName,DeviceLabel);
                trgrseq.add(num2str(state));
            end

            Scp.mmc.setProperty(Scp.TriggerDeviceName,'Sequence','On')
            Scp.mmc.loadPropertySequence(Scp.TriggerDeviceName, 'State', trgrseq);
            Scp.mmc.startPropertySequence(Scp.TriggerDeviceName, 'State');

        end

        function stk = snapSeq(Scp,NFrames)
            timgs = cell(NFrames,1);
            Scp.mmc.clearCircularBuffer()
            Scp.mmc.startSequenceAcquisition(NFrames, 0, false);
            frame = 0;
            %exposureMs = Scp.Exposure;
            while (Scp.mmc.getRemainingImageCount() > 0 || Scp.mmc.isSequenceRunning(Scp.mmc.getCameraDevice())) && frame<NFrames+1
                if (Scp.mmc.getRemainingImageCount() > 0)
                    Scp.mmc.getRemainingImageCount();
                    if frame==0
                        Scp.mmc.popNextTaggedImage();
                        frame=frame+1;
                    else
                        timgs(frame) = Scp.mmc.popNextTaggedImage();
                        frame=frame+1;
                    end
                else
                    Scp.mmc.sleep(2);
                end
            end
            Scp.mmc.stopSequenceAcquisition();
            Scp.studio.closeAllAcquisitions;

            s = cellfun(@(x) Scp.convertMMimgToMatlabFormat(x.pix), timgs,'UniformOutput',false);
            stk = cat(3,s{:});

        end

        function img = snapImageHDR(Scp,varargin)
            N = ParseInputs('N',3,varargin);
            Scp.Exposure = Scp.Exposure/N;
            stk = Scp.snapSeq(N);
            % img = exposure_fusion_mono(cumsum(stk,3),[1 1]);
            img = blendstk(cumsum(stk,3));
            Scp.Exposure = Scp.Exposure*N;
        end

        %% get/sets
        function set.Chamber(Scp,ChamberType)
            if ~(isa(ChamberType,'Plate') || isa(ChamberType,'CustomPlate') || isa(ChamberType,'CustomPlate_v2'))
                error('Chamber must be of type Plate!')
            end
            Scp.Chamber = ChamberType;
        end

        %%  other devices not controlled via MM (TODO: maybe need to abstract this further? Roy 10/17/12)
        function Tout=get.Temperature(Scp)
            [Tout,~]=getTempAndHumidity(Scp);
        end

        function Hout=get.Humidity(Scp)
            [~,Hout]=getTempAndHumidity(Scp);
        end

        function [Tout,Hout]=getTempAndHumidity(Scp) %#ok<STOUT,MANU>
            error('Not implemented in Scope - overload to use!')
        end

        %% Image properties
        function w=get.Width(Scp)
            w=getWidth(Scp);
        end
        function w=getWidth(Scp)
            w=Scp.mmc.getImageWidth;
        end

        function h=get.Height(Scp)
            h=getHeight(Scp);
        end
        function h=getHeight(Scp)
            h=Scp.mmc.getImageHeight;
        end

        function bd=get.BitDepth(Scp)
            bd=getBitDepth(Scp);
        end

        function bd=getBitDepth(Scp)
            bd=Scp.mmc.getImageBitDepth;
        end



        %% acquisition propertoes
        function chnl = get.Channel(Scp)
            chnl = getChannel(Scp);
        end

        function chnl = getChannel(Scp)
            chnl = char(Scp.mmc.getCurrentConfig(Scp.mmc.getChannelGroup));
        end

        function set.Channel(Scp,chnl)
            %% call an external method (not get/set) so that it could be overloaded between microscopes
            setChannel(Scp,chnl)
        end

        function setChannel(Scp,chnl)

            %% do some input checking
            % is char
            if ~ischar(chnl)
                error('Channel state must be char!');
            end

            %% check if change is needed, if not return
            if strcmp(chnl,Scp.Channel)
                return
            end

            %% Change channel
            % the try-catch is a legacy from a hardware failure where
            % the scope wasn't changing on time and we had to wait
            % longer for it to do so. We decided to keep it in there
            % since it doesn't do any harm to try changing channel
            % twice with a warning done message
            try
                Scp.mmc.setConfig(Scp.mmc.getChannelGroup,chnl);
                Scp.mmc.waitForSystem();
                assert(~isempty(Scp.Channel),'error - change channel failed');
            catch e
                fprintf('failed for the first time with error message %s, trying again\n',e.message)
                Scp.mmc.setConfig(Scp.mmc.getChannelGroup,chnl);
                Scp.mmc.waitForSystem();
                disp('done')
            end

            %% update GUI if not in timeCrunchMode
            if ~Scp.reduceAllOverheadForSpeed
                Scp.studio.refreshGUIFromCache; %referesg from mmc core cache instead of doing hardware check
            end
        end

        function exptime = get.Exposure(Scp)
            exptime=getExposure(Scp);
        end

        function exptime=getExposure(Scp)
            exptime = Scp.mmc.getExposure();
            if ~isnumeric(exptime)
                exptime=str2double(exptime);
            end
        end

        function setExposure(Scp,exptime)
            % check input - real and numel==1
            if ~isreal(exptime) || numel(exptime)~=1 ||exptime <0
                error('Exposure must be a double positive scalar!');
            end
            Scp.mmc.setExposure(exptime);
        end

        function set.Exposure(Scp,exptime)
            setExposure(Scp,exptime);
        end



        function set.TimeStamp(Scp,what)
            if strcmp(what,'reset')
                Scp.TimeStamp = {'init',now};
                return
            end
            if Scp.reduceAllOverheadForSpeed
                return
            end

            % this will replace the last entry
            % ix = find(ismember(Scp.TimeStamp(:,1),what), 1);
            ix=[];
            if isempty(ix)
                Scp.TimeStamp(end+1,:)= {what,now};
            else
                Scp.TimeStamp(ix,:) = {what,now};
            end
        end

        function set.AcqData(Scp,AcqData)
            Scp.AcqData = AcqData;
        end

        function set.MD(Scp,MD)
            % set had to potential calls, where MD is a Metadata and where
            % MD is a char name of an existing Metadata. The first case
            % will add the MD to the scope possible MDs (assuming it has a
            % unique name). The second will make the MD with the acqname MD
            % be the currnet MD.
            if isempty(Scp.AllMDs)
                Scp.AllMDs = MD;
                Scp.MD = MD;
                return
            end
            CurrentMDs = {Scp.AllMDs.acqname};
            if isa(MD,'Metadata')
                % check to see if it exist in AllMDs
                ix = ismember(CurrentMDs,MD.acqname);
                if nnz(ix)==1
                    Scp.AllMDs(ix) = MD;
                else
                    Scp.AllMDs(end+1) = MD;
                end
                Scp.MD=MD;
            else
                % check to see if it exist in AllMDs
                ix = ismember(CurrentMDs,MD); % here MD is a char acqname
                if nnz(ix)==1
                    Scp.MD = Scp.AllMDs(ix);
                elseif nnz(ix)==0
                    error('Can''t set Scp'' active Metadata to %s it doesn''t exist!',MD)
                end
            end
        end

        function PixelSize = get.PixelSize(Scp)
            PixelSize = getPixelSize(Scp);
        end

        function PixelSize = getPixelSize(Scp)
            PixelSize = Scp.mmc.getPixelSizeUm;
            if Scp.Optovar==1
                PixelSize = PixelSize/0.7;
            end
        end

        function Objective = get.Objective(Scp)
            Objective = getObjective(Scp);
        end

        function Objective = getObjective(Scp)
            Objective = Scp.mmc.getProperty(Scp.DeviceNames.Objective,'Label');
            Objective = char(Objective);
        end

        function set.Objective(Scp,Objective)

            % get full name of objective from shortcut
            avaliableObj = Scope.java2cell(Scp.mmc.getAllowedPropertyValues(Scp.DeviceNames.Objective,'Label'));
            label_10xnew = avaliableObj{6};
            avaliableObj{6}='10Xnew';
            % only consider Dry objectives for Scp.set.Objective
            objIx = cellfun(@(f) ~isempty(regexp(f,Objective, 'once')),avaliableObj) & cellfun(@(m) ~isempty(m),strfind(avaliableObj,'Dry'));
            if nnz(objIx)~=1
                error('Objective %s not found or not unique',Objective);
            end
            Objective = avaliableObj(objIx);
            % if requesting current objective just return
            if strcmp(Objective, Scp.Objective)
                return
            end
            % find the offsets - first Z
            obj_old = Scp.Objective;
            ix1 = ismember(avaliableObj,obj_old); %#ok<*MCSUP>
            ix2 = ismember(avaliableObj,Objective);
            dZ = Scp.ObjectiveOffsets.Z(ix1,ix2);

            AFstatus = Scp.mmc.isContinuousFocusEnabled;
            if AFstatus
                oldAF = Scp.mmc.getProperty(Scp.DeviceNames.AFoffset,'Position');
                oldAF = str2double(char(oldAF)); %#ok<NASGU>
            end
            Scp.mmc.enableContinuousFocus(false); % turns off AF

            % escape and change objectives
            oldZ = Scp.Z;
            Scp.Z = 500;
            if strcmp(Objective,'10Xnew')
                Objective = label_10xnew;
            end
            Scp.mmc.setProperty(Scp.DeviceNames.Objective,'Label',Objective);
            Scp.mmc.waitForSystem;
            % return to the Z with offset
            Scp.Z = oldZ + dZ;

            %             if AFstatus
            %                 Scp.mmc.enableContinuousFocus(true);
            %                 dAF = Scp.ObjectiveOffsets.AF(ix1,ix2);
            %                 Scp.mmc.setProperty(Scp.DeviceNames.AFoffset,'Position',oldAF + dAF);
            %             end


        end

        %% XY positions
        function Z = get.Z(Scp)
            Z=getZ(Scp);
        end

        function Z = getZ(Scp)
            Z=Scp.mmc.getPosition(Scp.mmc.getFocusDevice);
        end

        function set.Z(Scp,Z)
            setZ(Scp,Z)
        end

        function setZ(Scp,Z)
%             currZ = Scp.Z;
%             dist = sqrt(sum((currZ-Z).^2));
%             if Scp.Zpercision >0 && dist < Scp.Zpercision
%                 fprintf('movment too small - skipping Z movement\n');
%                 return
%             end
            max_attempts = 5;
            try
                for attempt=1:max_attempts
                    if attempt>1
                        pause(attempt*5)
                        Scp.mmc.setPosition(Scp.mmc.getFocusDevice,Z-2)
                        if attempt>2
                            message = ['Stage is not able to get to this position (Z) Attempt #',int2str(attempt)];
                            Scp.Notifications.sendSlackMessage(Scp,message,'all',true);
                        end
                    end
                    Scp.mmc.setPosition(Scp.mmc.getFocusDevice,Z)
                    if Scp.checkZStage(Z)
                        break
                    end
                end
                if attempt==max_attempts
                    message = 'Stage is not able to get to this position (Z) Need Help';
                    Scp.Notifications.sendSlackMessage(Scp,message,'all',true);
                    answer = questdlg(['Stage is not able to get to this position',newline,'If Position Is not Good Click Hide'], ...
                        'Stage Needs Help', ...
                        'Okay','Hide','');
                    switch answer
                        case 'Hide'
                            Scp.Pos.Hidden(Scp.Pos.current) = 1;
                    end
                end
            catch e
                warning('failed to move Z with error: %s',e.message);
            end
        end

        function X = get.X(Scp)
            X=getX(Scp);
        end

        function X=getX(Scp)
            X=Scp.mmc.getXPosition(Scp.mmc.getXYStageDevice);
        end

        function Y=getY(Scp)
            Y=Scp.mmc.getYPosition(Scp.mmc.getXYStageDevice);
        end

        function XY=getXY(Scp)
            XY2d=Scp.mmc.getXYStagePosition(Scp.mmc.getXYStageDevice);
            XY=[XY2d.getX XY2d.getY];
        end

        function setX(Scp,X)
            setXY(Scp,[X Scp.Y])
        end

        function set.X(Scp,X)
            setX(Scp,X)
        end

        function Y = get.Y(Scp)
            Y=getY(Scp);
        end

        function set.Y(Scp,Y)
            setY(Scp,Y);
        end

        function setY(Scp,Y)
            setXY(Scp,[Scp.X Y])
        end

        function XY = get.XY(Scp)
            XY=getXY(Scp);
            XY = round(XY); % round to the closest micron...
        end

        function Mag = get.Optovar(Scp)
            Mag = getOptovar(Scp);
        end

        function Mag = getOptovar(Scp)
            % try to get Optovar stage from arduino - prompt user if
            % failed.
            switch Scp.ScopeName
                case 'None'
                    throw(MException('OptovarFetchError', 'ScopeStartup did not handle optovar'));
                case 'Zeiss_Axio_0'
                    Mag = 1;
                case 'IncuScope_0'
                    Mag = 1;
                case 'Ninja'
                    try
                        readout = Scp.mmc.getProperty('Optovar','DigitalInput');
                        readout = str2double(char(readout));
                    catch % if error assign readout to be negative
                        readout=-1;
                    end
                    if readout == 1
                        Mag = 1.5;
                    elseif readout == 0
                        Mag = 1;
                    else % could not read optovar from arduino, trying to read from previous images, if not bail out.
                        if ~isempty(Scp.MD) && ~isempty(Scp.MD.Values)
                            %                                 warning('cannot read optovar - using Metadata pixelsize')
                            pxlmd = unique(Scp.MD,'PixelSize');
                            if pxlmd == Scp.mmc.getPixelSizeUm
                                Mag=1.5;
                            else
                                Mag=1;
                            end
                        else
                            %                                 warning('Cannot read optovar, PixelSize information not accurate')
                            Mag=1;
                        end
                    end


            end

        end

        function set.XY(Scp,XY)
            setXY(Scp,XY)

        end

        function out = checkZStage(Scp,Z)
            max_time = 10; %s
            dt = 0.0;%s
            max_iter = 100;
            currZ = Scp.Z;
            dist = sqrt(sum((currZ-Z).^2));
            iter=0;
            while dist > Scp.Zpercision & iter <= max_iter
                pause(dt)
                currZ = Scp.Z;
                dist = sqrt(sum((currZ-Z).^2));
                iter=iter+1;
                if mod(iter,25)==0
%                     Scp.mmc.setPosition(Scp.mmc.getFocusDevice,Z-2)
%                     pause(1)
                    Scp.mmc.setPosition(Scp.mmc.getFocusDevice,Z)
                end
            end
            out = dist<Scp.Zpercision;
            if ~out
                disp(['Dist: ',num2str(dist)])
                disp(['Current Z: ',num2str(currZ),' Desired Z: ',num2str(Z)])
            end
        end

        function out = checkXYStage(Scp,XY)

            max_time = 10; %s
            dt = 0.0;%s
%             t_start = now; 
%             while Scp.mmc.deviceBusy('TIXYDrive') && (now-t_start)*24*3600 < max_time
%                 pause(dt)
%             end
%             out = ~Scp.mmc.deviceBusy('TIXYDrive'); 
%             return

            max_iter = 100;
            currXY = Scp.XY;
            dist = sqrt(sum((currXY(:)-XY(:)).^2));
            iter=0;
            while dist > Scp.XYpercision & iter <= max_iter
                pause(dt)
                currXY = Scp.XY;
                dist = sqrt(sum((currXY(:)-XY(:)).^2));
                iter=iter+1;
            end
            out = dist<Scp.XYpercision;
            if ~out
                disp(['Dist: ',num2str(dist)])
                disp(['Current X: ',num2str(currXY(1)),' Desired X: ',num2str(XY(1))])
                disp(['Current Y: ',num2str(currXY),' Desired Y: ',num2str(XY(2))])
            end
        end

        function setXY(Scp,XY)
%             currXY = Scp.XY;
%             dist = sqrt(sum((currXY(:)-XY(:)).^2));
%             if Scp.XYpercision >0 && dist < Scp.XYpercision
%                 fprintf('movment too small - skipping XY movement\n');
%                 return
%             end
            max_attempts = 5;
            try
                for attempt=1:max_attempts
                    if attempt>1
                        pause(attempt*30)
                        message = ['Stage is not able to get to this position (XY) Attempt #',int2str(attempt)];
                        Scp.Notifications.sendSlackMessage(Scp,message,'all',true);
                        Scp.mmc.setXYPosition(Scp.mmc.getXYStageDevice,XY(1)-50,XY(2)-50)
                    end
                    Scp.mmc.setXYPosition(Scp.mmc.getXYStageDevice,XY(1),XY(2))
                    if Scp.checkXYStage(XY)
                        break
                    end
                end
                if attempt==max_attempts
                    message = 'Stage is not able to get to this position (XY) Need Help';
                    Scp.Notifications.sendSlackMessage(Scp,message,'all',true);
                    answer = questdlg(['Stage is not able to get to this position',newline,'If Position Is not Good Click Hide'], ...
                        'Stage Needs Help', ...
                        'Okay','Hide','');
                    switch answer
                        case 'Hide'
                            Scp.Pos.Hidden(Scp.Pos.current) = 1;
                    end
                end
            catch e
                warning('failed to move XY with error: %s',e.message);
            end
        end

        %% register by previous image
        function dXY = findRegistrationXYshift(Scp,varargin)
            %% input arguments
            arg.channel = 'Yellow';
            arg.position = '';
            arg.exposure = [];
            arg.fig = 123;
            arg.help = true;
            arg.pth = '';
            arg.auto = false;
            arg.verify = true;
            arg = parseVarargin(varargin,arg);

            if isempty(arg.pth)
                error('Please provide the path to the previous dataset!!!')
            end
            if isempty(arg.position)
                error('Please provide the position you want to register')
            end
            if isempty(Scp.Pos)
                error('Please run createPosition before trying to register')
            end
            PrevMD = Metadata(arg.pth);
            LastImage = stkread(PrevMD,'Channel',arg.channel,'Position',arg.position,'specific','last');

            Scp.Channel = arg.channel;
            if ~isempty(arg.exposure)
                Scp.Exposure = arg.exposure;
            end

            if arg.auto
                % try using cross-correlation.
                img = Scp.snapImage;
                cc=normxcorr2(img,LastImage);
                [~, imax] = max(abs(cc(:)));
                imax=gather(imax);
                [ypeak, xpeak] = ind2sub(size(cc),imax(1));
                sz=size(img1);
                dy_pixel=ypeak-sz(1);
                dx_pixel=xpeak-sz(2);

            else % manually click on spots (cells or highlighter, whatever is easier...)
                success = 'No';
                Scp.goto(arg.position)
                while ~strcmp(success,'Yes')

                    img = Scp.snapImage;

                    figure(arg.fig)
                    imshowpair(imadjust(img),imadjust(LastImage));

                    if arg.help
                        disp('Click purple to green')
                        %                     uiwait(msgbox('click purple to green'))
                    end

                    [x,y] = ginput(2);
                    dx_pixel = diff(x);
                    dy_pixel = diff(y);

                    %                 success = questdlg('Success?');
                    success = input('Do you want to move on (m) try again (t) or  abort (a)? (m/t/a)','s');
                    assert(any(ismember('mta',success)),'Look what you are clicking you moron!')

                    if strcmp(success,'a')
                        return;
                    end

                    if strcmp(success,'t')
                        input('Move stage a bit and try again','s');
                    end
                    if strcmp(success,'m')
                        break % get out of the infinite while loop
                    end
                    disp('Still in While-loop')

                end
                disp('Out of while-loop')
            end
            dX_micron = dx_pixel*Scp.PixelSize;
            dY_micron = dy_pixel*Scp.PixelSize;

            if arg.verify
                XYold=Scp.XY;
                XYnew =XYold+[dX_micron dY_micron];
                Scp.XY=XYnew;
                img = Scp.snapImage;
                figure(arg.fig)
                imshowpair(imadjust(img),imadjust(LastImage));
                success = input('Do you approve? (y / n)');
                if ~strcmp(success,'y')
                    return
                end
            end

            dXY=[dX_micron dY_micron];
            Scp.dXY=dXY;

        end

        %software autofocus related stuff

        function Zfocus = ImageBasedFocusHillClimb(Scp,varargin)
            %Works pretty well with BF:
            %Scp.ImageBasedFocusHillClimb('channel','Brightfield','exposure',20,'resize',0.25,'scale',50)
            %Works really well with Hoescht:
            %Scp.ImageBasedFocusHillClimb('channel','Brightfield','exposure',20,'resize',0.25,'scale',50)

            arg.scale = ParseInputs('scale',Scp.AFparam.scale,varargin);
            arg.resize = ParseInputs('resize',Scp.AFparam.resize,varargin);
            arg.channel = ParseInputs('channel',Scp.AFparam.channel,varargin);
            arg.exposure = ParseInputs('exposure',Scp.AFparam.exposure,varargin);
            arg.verbose = ParseInputs('verbose',Scp.AFparam.verbose,varargin);


            %% Set channels and exposure
            Scp.Channel=arg.channel;
            Scp.Exposure=arg.exposure;

            Zs = [];
            Conts = [];
            if arg.verbose
                figure(157),
                set(157,'menubar','none','Name','Finding focus by contrast','NumberTitle','off')

                clf
            end
            Zinit = Scp.Z;
            dZ = 25*(6.3/Scp.Optovar)^2;
            sgn = 1;

            acc = dZ^(1/5);
            cont1=Scp.Contrast('scale',arg.scale,'resize',arg.resize);  %measure of contrast
            Zs = [Zs Scp.Z];
            Conts = [Conts cont1];

            if arg.verbose
                plot(Scp.Z,cont1,'o')
                hold all
            end
            %determine direction of motion

            Scp.Z = Scp.Z+sgn*dZ;
            cont2=Scp.Contrast('scale',arg.scale,'resize',arg.resize);

            Zs = [Zs Scp.Z];
            Conts = [Conts cont2];
            if arg.verbose
                plot(Scp.Z,cont2,'o')
            end
            if cont2<cont1
                sgn = -sgn;
                Scp.Z = Scp.Z+2*sgn*dZ;
                cont2=Scp.Contrast('scale',arg.scale,'resize',arg.resize);
                if arg.verbose
                    set(157,'menubar','none','Name','Finding focus by contrast','NumberTitle','off')
                end
                Zs = [Zs Scp.Z];
                Conts = [Conts cont2];
                if arg.verbose
                    plot(Scp.Z,cont2,'o');
                end
                if cont2<cont1
                    dZ=dZ/(acc^2);
                    Scp.Z = Zinit;%start over with smaller region
                    cont1=Scp.Contrast('scale',arg.scale,'resize',arg.resize);  %measure of contrast

                    Scp.Z = Scp.Z+sgn*dZ;
                    cont2=Scp.Contrast('scale',arg.scale,'resize',arg.resize);

                    Zs = [Zs Scp.Z];
                    Conts = [Conts cont2];
                    if arg.verbose
                        plot(Scp.Z,cont2,'o')
                    end
                    if cont2<cont1
                        sgn = -sgn;
                        Scp.Z = Scp.Z+2*sgn*dZ;
                        cont2=Scp.Contrast('scale',arg.scale,'resize',arg.resize);


                        Zs = [Zs Scp.Z];
                        Conts = [Conts cont2];
                        if arg.verbose
                            plot(Scp.Z,cont2,'o');
                            drawnow;
                        end
                    end
                    %sgn = -sgn;
                end
            end

            while dZ>1
                while cont2>=cont1
                    cont1=cont2;
                    Scp.Z = Scp.Z+sgn*dZ;
                    cont2=Scp.Contrast('scale',arg.scale,'resize',arg.resize);
                    if arg.verbose
                        figure(157);
                    end
                    Zs = [Zs Scp.Z];
                    Conts = [Conts cont2];
                    if arg.verbose
                        plot(Scp.Z,cont2,'o')
                        drawnow;
                    end

                end
                dZ = dZ/acc;
                sgn=-sgn;
                cont1=cont2;
            end

            Zfocus = mean(Zs(Conts==max(Conts)));
            Scp.Z = Zfocus;
            %Zfocus = Scp.Z+sgn*dZ*acc;
            %Scp.Z = Zinit;
        end


        function cont = Contrast(Scp,varargin)
            arg.scale = 2; % if True will acq multiple channels per Z movement.
            arg.resize =1;
            % False will acq a Z stack per color.
            arg = parseVarargin(varargin,arg);
            img=imresize(Scp.snapImage, arg.resize);
            m=img-imgaussfilt(img,arg.scale);
            m = m(200:end,200:end);
            rng=prctile(m(:),[1 99]);
            cont=rng(2)-rng(1);
        end

        function focusAdjust(Scp,varargin)
            arg.Diff = -30;
            arg.scale = 2; % if True will acq multiple channels per Z movement.
            arg.resize =1;
            arg.channel = 'DeepBlue'; % if True will acq multiple channels per Z movement.
            arg.exposure =10;
            arg = parseVarargin(varargin,arg);

            Scp.goto(Scp.Pos.Labels{1}, Scp.Pos)
            Zfocus = Scp.ImageBasedFocusHillClimb(varargin{:});

            dZ = Zfocus-Scp.Z+arg.Diff;
            Scp.Pos.List(:,3) = Scp.Pos.List(:,3)+dZ;
        end

        function dZ = findInitialFocus(Scp,varargin)
            arg.scale = 2; % if True will acq multiple channels per Z movement.
            arg.resize =1;
            arg.channel = 'DeepBlue'; % if True will acq multiple channels per Z movement.
            arg.exposure =20;

            arg = parseVarargin(varargin,arg);

            Scp.goto(Scp.Pos.Labels{1}, Scp.Pos);
            figure(445)
            set(445,'Windowstyle','normal','toolbar','none','menubar','none','Position',[700 892 300 75],'Name','Please find focus in first well','NumberTitle','off')
            uicontrol(445,'Style', 'pushbutton', 'String','Done','Position',[50 20 200 35],'fontsize',13,'callback',@(~,~) close(445))
            uiwait(445)

            dZ1 = Scp.Z-Scp.Mishor.Zpredict(Scp.XY);
            Scp.Pos.List(:,3) = Scp.Mishor.Zpredict(Scp.Pos.List(:,1:2))+dZ1;
            %ManualZ = Scp.Z;
            for i=1:Scp.Pos.N
                Scp.goto(Scp.Pos.Labels{i}, Scp.Pos);
                Zfocus = Scp.ImageBasedFocusHillClimb(varargin{:});
                if i==1
                    dZ = 0;%ManualZ-Zfocus;%difference bw what I call focus and what Mr. computer man thinks.
                end
                Scp.Pos.List(i,3) = Zfocus+dZ;
            end
        end


    end
end
