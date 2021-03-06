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
        TempHumiditySensor 
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
        AFparam=struct('scale',2,'resize',1,'channel','DeepBlue','exposure',10); 
        
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
        
        %% Magnification
        Optovar = 1;
        
        EnforcePlatingDensity = true;
        
        %% Live shift adjust
        shiftfilepath =[];
                
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
        MMversion
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
            
            run('ScopeStartup')
        end
        
        function acqZstack(Scp,AcqData,acqname,dZ,varargin)
            disp('starting z stack')
            % acqZstack acquires a whole Z stack
            arg.channelfirst = true; % if True will acq multiple channels per Z movement.
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
                    for i=1:numel(dZ)
                        Scp.Z=Z0+dZ(i);
                        acqFrame(Scp,AcqData(j),acqname,'z',i,'savemetadata',false);
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
                % use createFlatFieldImage with defaults beside increase
                % iterations
                flt = createFlatFieldImage(Scp,'filter',true,'iter',30,'assign',true,'meanormedian','mean','gauss', fspecial('gauss',30,3));
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
            flt = flt';
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
        
        function ver = get.MMversion(Scp)
            %%
            try
                verstr = Scp.studio.getVersion;
            catch
                verstr = Scp.studio.getVersion;
            end
            prts = regexp(char(verstr),'\.','split');
            ver = str2double([prts{1} '.' prts{2}]);
        end
        
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
                    warning('Flat field failed with channel %s, error message %s, moving on...',Scp.Channel,e.message);
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
                        arg.func = @() acqZstack(Scp,AcqData,acqname,arg.dz,'channelfirst',arg.channelfirst);
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
            
            disp('I`m done now. Thank you.')
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
             warning('Not implemented in Scope - overload to use!')
        end
        
        function [z,s]=autofocus(Scp) %#ok<STOUT,INUSD>
            warning('Not implemented in Scope - overload to use!')
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
                
                %% goto position
                Scp.goto(Scp.Pos.next,Scp.Pos);
                
                %% adjust position shift
                
                

                [dX,dY,dZ] = Scp.parseShiftFile;        
                Scp.X = Scp.X+dX;
                Scp.Y = Scp.Y+dY;
                Scp.Z = Scp.Z+dZ;
                
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
                msk = flt>prctile(img(:),2);
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
            if arg.plot %Scp.reduceAllOverheadForSpeed &&
                plot(Pos,Scp,'fig',Scp.Chamber.Fig.fig,'label',label,'single',single);
            end
            Scp.TimeStamp = 'endmove';
            ifMulti = regexp(label,'_');
            if ifMulti
            label = label(1:ifMulti(1)-1);
            end
            if ~Scp.Strobbing
                err =~strcmp(Scp.whereami,label); %return err=1 if end position doesnt match label
                if err
                    warning('stage position doesn`t match label')
                end
            end
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
            arg.cameradirection=[1 1]; % when I move positive in X do the columns (row if transpose) move up or down
            arg.camera_angle = Scp.CameraAngle;
            arg = parseVarargin(varargin,arg); 
            rc=rc-[Scp.Height Scp.Width]/2;
            rc = rc*[[cosd(arg.camera_angle), -1*sind(arg.camera_angle)]; [sind(arg.camera_angle), cosd(arg.camera_angle)]];
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
        
        
        function Pos = createPositionFromMMNoSet(Scp,varargin)
            arg.labels={};
            arg.groups={};
            arg.axis={'XY'};
            arg.message = 'Please click when you finished marking position';
            arg.experimentdata=struct([]);
            arg = parseVarargin(varargin,arg);
            if Scp.MMversion < 1.5
                Scp.studio.showXYPositionList; %Alon
            else
                Scp.studio.showPositionList;
            end
            uiwait(msgbox(arg.message))
            Pos = Positions(Scp.studio.getPositionList,'axis',arg.axis);
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
                Pos.addMetadata(Scp.Pos.Labels,[],[],'experimentdata',arg.experimentdata);
            end
        end
        
        
        function createPositionFromMM(Scp,varargin)
            arg.labels={};
            arg.groups={};
            arg.axis={'XY'};
            arg.message = 'Please click when you finished marking position';
            arg.experimentdata=struct([]);
            arg = parseVarargin(varargin,arg);
            if Scp.MMversion < 1.5
                Scp.studio.showXYPositionList; %Alon
            else
                Scp.studio.showPositionList;
            end
            uiwait(msgbox(arg.message))
            Scp.Pos = Positions(Scp.studio.getPositionList,'axis',arg.axis);
            if ~isempty(arg.labels)
                Scp.Pos.Labels = arg.labels;
                if isempty(arg.groups)
                    Scp.Pos.Group=arg.labels;
                end
            end
            if ~isempty(arg.groups)
                Scp.Pos.Group=arg.groups;
            end
            if ~isempty(arg.experimentdata)
                Scp.Pos.addMetadata(Scp.Pos.Labels,[],[],'experimentdata',arg.experimentdata);
            end
        end
       
        function set.Pos(Scp,Pos)
            % make sure Pos is of the right type;
            assert(isempty(Pos) || isa(Pos,'Positions'));
            Scp.Pos = Pos;
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
            
            
            %% now create grid for all wells asked for
            ixWellsToVisit = intersect(find(arg.msk),find(ismember(Plt.Wells,arg.wells)));
            Xcntr = Plt.Xcenter;
            Ycntr = Plt.Ycenter;
            
            %% create the position list
            if arg.relative
                Pos=RelativePositions;
            else
                Pos=Positions;
            end
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
                Pos = add(Pos,WellXY,WellLabels);
                
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
                unqGroup=unique(Pos.Group,'stable'); %added 'stable' to prevent flips
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
        
        function img = snapImage(Scp)
            if ismember(Scp.acqshow,{'single','channel','FLIR'})
                showImg = true; 
            else
                showImg = false; 
            end
            % get image from Camera
            img=commandCameraToCapture(Scp); 
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
           if Scp.MMversion > 1.5 
                Scp.mmc.snapImage;
                timg=Scp.mmc.getTaggedImage;
                img=timg.pix;
           else
               try %added a try catch to *try* and fix the empty buffer issue.
                   %trying this. AOY
                   while Scp.mmc.getRemainingImageCount()
                       Scp.mmc.popNextTaggedImage();
                   end
                   Scp.mmc.snapImage;
                   img = Scp.mmc.getImage;
               catch
                   pause(.005);
                   img = Scp.mmc.getImage;
                   if isequal(img,Scp.lastImg)
                     Scp.mmc.snapImage;
                     img = Scp.mmc.getImage;
                   end
               end
           end
            Scp.lastImg = img;
            img=Scp.convertMMimgToMatlabFormat(img);
            
            if Scp.CorrectFlatField
                img = Scp.doFlatFieldCorrection(img);
            end
        end
        
        function img=convertMMimgToMatlabFormat(Scp,img)
            img = double(img);%AOY and Rob, fix saturation BS.
            img(img<0)=img(img<0)+2^Scp.BitDepth;
            img = reshape(img,[Scp.Width Scp.Height])';
            img = mat2gray(img,[1 2^Scp.BitDepth]);
        end
        
        function setTriggerChannelSequence(Scp,AcqData)
            TriggeredChannels = cat(1,AcqData.Triggered);
            indx=find(TriggeredChannels);
            if isempty(indx), return, end
            %import mmcorej.StrVector;
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
                Scp.studio.refreshGUI;
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
            avaliableObj{6}='20Xnew';
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
            %             if Z>25 || Z<0
            %                 fprintf('goal %f current %f\n',Z,Scp.Z);
            %                 warndlg('Z requeste4d out of piezo range, adjust manually!');
            %             end
            try
                Scp.mmc.setPosition(Scp.mmc.getFocusDevice,Z)
                Scp.mmc.waitForDevice(Scp.mmc.getProperty('Core','Focus'));
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
        
        function setX(Scp,X)
            Scp.mmc.setXYPosition(Scp.mmc.getXYStageDevice,X,Scp.Y)
            Scp.mmc.waitForDevice(Scp.mmc.getProperty('Core','XYStage'));
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
            Scp.mmc.setXYPosition(Scp.mmc.getXYStageDevice,Scp.X,Y)
            Scp.mmc.waitForDevice(Scp.mmc.getProperty('Core','XYStage'));
        end
        
        function XY = get.XY(Scp)
            XY(1)=getX(Scp);
            XY(2)=getY(Scp);
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
        
        function setXY(Scp,XY)
            currXY = Scp.XY;
            dist = sqrt(sum((currXY(:)-XY(:)).^2));
            if Scp.XYpercision >0 && dist < Scp.XYpercision
                fprintf('movment too small - skipping XY movement\n');
                return
            end
            
            Scp.mmc.setXYPosition(Scp.mmc.getXYStageDevice,XY(1),XY(2))
            Scp.mmc.waitForDevice(Scp.mmc.getProperty('Core','XYStage'));
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
            
            
            %% Set channels and exposure
            Scp.Channel=arg.channel;
            Scp.Exposure=arg.exposure;
            
            Zs = [];
            Conts = [];
            
            figure(157),
            set(157,'menubar','none','Name','Finding focus by contrast','NumberTitle','off')
            
            clf
            
            Zinit = Scp.Z;
            dZ = 25*(6.3/Scp.Optovar)^2;
            sgn = 1;

            acc = dZ^(1/5);
            cont1=Scp.Contrast('scale',arg.scale,'resize',arg.resize);  %measure of contrast
            Zs = [Zs Scp.Z];
            Conts = [Conts cont1];
            
            plot(Scp.Z,cont1,'o')
            hold all
            
            %determine direction of motion
            
            Scp.Z = Scp.Z+sgn*dZ;
            cont2=Scp.Contrast('scale',arg.scale,'resize',arg.resize);
            
            Zs = [Zs Scp.Z];
            Conts = [Conts cont2];
            
            plot(Scp.Z,cont2,'o')
            
            if cont2<cont1
                sgn = -sgn;
                Scp.Z = Scp.Z+2*sgn*dZ;
                cont2=Scp.Contrast('scale',arg.scale,'resize',arg.resize);
                set(157,'menubar','none','Name','Finding focus by contrast','NumberTitle','off')
                
                Zs = [Zs Scp.Z];
                Conts = [Conts cont2];
                
                plot(Scp.Z,cont2,'o');
                if cont2<cont1
                    dZ=dZ/(acc^2);
                    Scp.Z = Zinit;%start over with smaller region
                    cont1=Scp.Contrast('scale',arg.scale,'resize',arg.resize);  %measure of contrast
                    
                    Scp.Z = Scp.Z+sgn*dZ;
                    cont2=Scp.Contrast('scale',arg.scale,'resize',arg.resize);
                    
                    Zs = [Zs Scp.Z];
                    Conts = [Conts cont2];
                    
                    plot(Scp.Z,cont2,'o')
                    if cont2<cont1
                        sgn = -sgn;
                        Scp.Z = Scp.Z+2*sgn*dZ;
                        cont2=Scp.Contrast('scale',arg.scale,'resize',arg.resize);
                        
                        
                        Zs = [Zs Scp.Z];
                        Conts = [Conts cont2];
                        
                        plot(Scp.Z,cont2,'o');
                        drawnow;
                    end
                    %sgn = -sgn;
                end
            end
            
            while dZ>1
                while cont2>=cont1
                    cont1=cont2;
                    Scp.Z = Scp.Z+sgn*dZ;
                    cont2=Scp.Contrast('scale',arg.scale,'resize',arg.resize);
                    figure(157);
                    
                    Zs = [Zs Scp.Z];
                    Conts = [Conts cont2];
                    
                    plot(Scp.Z,cont2,'o')
                    drawnow;

                end
                dZ = dZ/acc;
                sgn=-sgn;
                cont1=cont2;
            end
            
            Zfocus = mean(Zs(Conts==max(Conts)));
            
            %Zfocus = Scp.Z+sgn*dZ*acc;
            Scp.Z = Zinit;
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
