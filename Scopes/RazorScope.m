classdef RazorScope < Scope
    
    properties
        Angle
        Camera='Ximea';
        ZStage
        LaserTrigger;
        refImage;
        dZ;
    end
    
    properties (Dependent)
        imagingVelocity;
    end
    
    
    methods
        function vel = get.imagingVelocity(Scp)
            vel = find(1000*Scp.dZ./Scp.ZStage.Vlist>=10,1,'last');
        end
        
        
        
        
        function autofocus(Scp)
        end
        
        function Objective = getObjective(Scp)
            Objective = 'Nikon CFI 16X 0.8NA';
        end
        
        function PixelSize = getPixelSize(Scp)
            %PixelSize = Scp.mmc.getPixelSizeUm;
            Binning = str2double(Scp.mmc.getProperty('Ximea','Binning'));
            Mag = 14.4;
            CamPixSize = 3.45;
            Demag = 0.63;
            PixelSize = Binning*CamPixSize/Mag/Demag;
        end
        
        
        function bd=getBitDepth(Scp)
            bd=str2double(Scp.mmc.getProperty('Ximea','Device output data bit depth'));
        end
        
        function Mag = getOptovar(Scp)
            Mag = 1;
        end
        
        function Angle = get.Angle(Scp)
            Angle = getAngle(Scp);
        end
        
        function set.Angle(Scp,Angle)
            setAngle(Scp,Angle);
        end
        
        function setAngle(Scp,a)
            try
                Scp.mmc.setPosition(Scp.DeviceNames.AngularStage,a./1.8)
                Scp.mmc.waitForDevice(Scp.DeviceNames.AngularStage);
            catch e
                warning('failed to move angular stage with error: %s',e.message);
            end
        end
        
        function Angle = getAngle(Scp)
            Angle=Scp.mmc.getPosition(Scp.DeviceNames.AngularStage)*1.8;
        end
        
        function goto(Scp,label,Pos,varargin)
            goto@Scope(Scp,label,Pos,'plot',false)
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
                Scp.mmc.setProperty('Emission','State',0);
                Scp.mmc.waitForSystem();
                Scp.mmc.setConfig(Scp.mmc.getChannelGroup,chnl);
                Scp.mmc.waitForSystem();
                disp('done')
            end
            
            %% update GUI if not in timeCrunchMode
            if ~Scp.reduceAllOverheadForSpeed
                Scp.studio.refreshGUI;
            end
        end
        
        %         function img=commandCameraToCapture(Scp)
        %             if ischar(Scp.Camera) && strcmp(Scp.Camera,'Zyla')
        %                 img = commandCameraToCapture@Scope(Scp);
        %             else
        %                 assert(isa(Scp.Camera,'SpinMATLABScp'),'If camera is not Zyla, must be a SpinMATLAB object')
        % %                Scp.mmc.setShutterOpen(true);
        %                 img = Scp.Camera.snapImage(Scp,1);
        % %                Scp.mmc.setShutterOpen(false);
        %             end
        %         end
        
        
        %         function stk = snapSeq(Scp,nrFrames)
        %             if ischar(Scp.Camera) && strcmp(Scp.Camera,'Zyla')
        %                 stk = snapSeq@Scope(Scp,nrFrames);
        %             else
        %                 assert(isa(Scp.Camera,'SpinMATLABScp'),'If camera is not Zyla, must be a SpinMATLAB object')
        %                 stk = Scp.Camera.snapImage(Scp,nrFrames,'show', false);
        %                 stk = Scp.convertMMimgToMatlabFormat(stk);
        %             end
        %         end
        
        
        %         function img=convertMMimgToMatlabFormat(Scp,img)
        %             if ischar(Scp.Camera) && strcmp(Scp.Camera,'Zyla')
        %                 img = convertMMimgToMatlabFormat@Scope(Scp,img);
        %             else
        %  %               img = double(img);%AOY and Rob, fix saturation BS.
        %  %               img(img<0)=img(img<0)+2^16;
        %  %               img = mat2gray(img,[1 2^16]);
        %             end
        %         end
        
        function setRefImage(Scp,AcqData,ind)
            refImgInd = ind;
            Scp.Channel = AcqData(1).Channel;
            Scp.goto(Scp.Pos.Labels{refImgInd}, Scp.Pos); %go to first position
            ref = Scp.snapImage;
            [ref,~] = perdecomp(ref);
            Scp.refImage = ref;%snap an image
        end
        
        function DriftAdjust(Scp,AcqData, ind)
            refImgInd = ind;
            ref = Scp.refImage;
            Scp.Channel = AcqData(1).Channel;
            Scp.goto(Scp.Pos.Labels{refImgInd}, Scp.Pos); %go to first position
            
            img = Scp.snapImage;%snap an image
            [img,~] = perdecomp(img); %nonlazy way of dealing with cross
            imXcorr = convnfft(ref-mean(ref(:)),rot90(img,2)-mean(img(:)),'same');%compare image to input ref
            imXcorr(size(img,1)/2, size(img,2)/2) =imXcorr(size(img,1)/2-1, size(img,2)/2-1) ; %lazy way to avoid point artifact
            [maxY, maxX] = find(imXcorr == max(imXcorr(:)));%find displacement
            
            dY = maxY-size(img,1)/2;
            dX = maxX-size(img,2)/2;
                        
            dY = dY(1);
            dX = dX(1);
            
            dy1 = dY;
            dx1 = dX;
            
            Scp.Pos.List(:,1) = Scp.Pos.List(:,1)-dX; %update position list
            Scp.Pos.List(:,2) = Scp.Pos.List(:,2)-dY; %update position list
            Scp.goto(Scp.Pos.Labels{refImgInd}, Scp.Pos); %take new ref for next r0und
            
            img = Scp.snapImage;%snap an image
            [img,~] = perdecomp(img); %nonlazy way of dealing with cross
            imXcorr = convnfft(ref-mean(ref(:)),rot90(img,2)-mean(img(:)),'same');%compare image to input ref
            imXcorr(size(img,1)/2, size(img,2)/2) =imXcorr(size(img,1)/2-1, size(img,2)/2-1) ; %lazy way to avoid point artifact
            [maxY, maxX] = find(imXcorr == max(imXcorr(:)));%find displacement
            
            dY = maxY-size(img,1)/2;
            dX = maxX-size(img,2)/2;
            
            
            dY = dY(1)
            dX = dX(1)
            
            dy1 = dy1+dY;
            dx1 = dx1+dX;
            
            Scp.Pos.List(:,1) = Scp.Pos.List(:,1)-dX; %update position list
            Scp.Pos.List(:,2) = Scp.Pos.List(:,2)-dY; %update position list
            Scp.goto(Scp.Pos.Labels{refImgInd}, Scp.Pos); 
            
            %ref = Scp.snapImage;
        end
        
        %
        %% acquisition sequences
        
        function [nFrames, dZ] = createCorneaQuadrants(Scp)
            %open empty position list with 4 axes
            nFrames = zeros(4,1);
            ListSide = cell(4,1);
            
            Pos = Positions([],'axis',{'X', 'Y','Z','Angle'});
            %clear MM list
            
            %create grid over cornea quadrant
            for i=1:4
                pl = Scp.studio.getPositionList;
                pl.clearAllPositions;
                
                Scp.studio.showPositionList;
                Scp.createPositionFromMM('axis', {'X' 'Y' 'Z'}, 'message', 'please mark top and edge of cornea');
                ListSide{i} = Scp.createGridPosition(Scp.Pos.List);
                Angle1 = Scp.Angle;
                ListSide{i} = [ListSide{i}, repmat(Angle1,size(ListSide{i},1),1)];
                
                %find # of Z stacks to take. Maxed at 428. Could either crop or
                %strech Z steps using varargin in nFramesNdZ
                figure(469)
                set(469,'Windowstyle','normal','toolbar','none','menubar','none','Position',[700 892 300 75],'Name','Please move to top Z position','NumberTitle','off')
                uicontrol(469,'Style', 'pushbutton', 'String','Done','Position',[100 20 100 35],'fontsize',13,'callback',@(~,~) close(469))
                uiwait(469);
                delZ = Scp.Z-min(ListSide{i}(:,3));
                if i==1;
                    [nFrames(i), dZ] = nFramesNdZ(Scp,delZ, 'crop', false, 'dZ', Scp.dZ);
                else
                    [nFrames(i), ~] = nFramesNdZ(Scp,delZ, 'crop', true, 'dZ', dZ);
                end
                %Rotate 90 deg
                Scp.Angle = Scp.Angle+90;
                clear pl;
            end
            %%
            %merge all to one list
            Pos.List = cell2mat(ListSide);
            
            % Make position labels and metadata
            Labels = {};
            Groups = {};
            Tiles = {};
            Counter =1;
            
            for i=1:size(ListSide,1)
                if ~isempty(ListSide{i})
                    for ix=1:numel(unique(ListSide{i}(:,1)))
                        for jx=1:numel(unique(ListSide{i}(:,2)))
                            Labels{Counter} = sprintf('Theta%03d_X%d_Y%d_tile%02d',90*(i-1),ix,jx,Counter-1);
                            Groups{Counter} = sprintf('Theta_%03d',mod(round(ListSide{i}((ix-1)*numel(unique(ListSide{i}(:,2)))+jx,4)),360));
                            Tiles{Counter} = num2str(Counter-1);
                            Counter = Counter+1;
                        end
                    end
                end
            end
            
            %Populate Position fields
            Pos.Labels = Labels;
            Pos.Group = Groups;
            % create metadata containing dZ and # frames per stack on eachside
            frmVec = [];
            for i=1:size(ListSide,1)
                frmVec = [frmVec repmat(nFrames(i),1,size(ListSide{i},1))];
            end
            ExpData= struct('nFrames', num2cell(frmVec),'dz',num2cell(repmat(dZ,1,size(Pos.List,1))),'Tile',Tiles);
            
            Pos.ExperimentMetadata = ExpData;
            
            Scp.Pos = Pos;
        end
        
        
        
        
        
        function [nFrames, dZ] = createCorneaHalves(Scp)
            %open empty position list with 4 axes
            nFrames = zeros(2,1);
            ListSide = cell(2,1);
            
            Pos = Positions([],'axis',{'X', 'Y','Z','Angle'});
            %clear MM list
            
            %create grid over cornea quadrant
            for i=1:2
                pl = Scp.studio.getPositionList;
                pl.clearAllPositions;
                
                Scp.studio.showPositionList;
                Scp.createPositionFromMM('axis', {'X' 'Y' 'Z'}, 'message', 'please mark top, bottom and edge of cornea');
                ListSide{i} = Scp.createGridPosition(Scp.Pos.List);
                Angle1 = Scp.Angle;
                ListSide{i} = [ListSide{i}, repmat(Angle1,size(ListSide{i},1),1)];
                
                %find # of Z stacks to take. Maxed at 428. Could either crop or
                %strech Z steps using varargin in nFramesNdZ
                figure(469)
                set(469,'Windowstyle','normal','toolbar','none','menubar','none','Position',[700 892 300 75],'Name','Please move to top Z position','NumberTitle','off')
                uicontrol(469,'Style', 'pushbutton', 'String','Done','Position',[100 20 100 35],'fontsize',13,'callback',@(~,~) close(469))
                uiwait(469);
                delZ = Scp.Z-min(ListSide{i}(:,3));
                if i==1;
                    [nFrames(i), dZ] = nFramesNdZ(Scp,delZ, 'crop', false, 'dZ', Scp.dZ);
                else
                    [nFrames(i), ~] = nFramesNdZ(Scp,delZ, 'crop', true, 'dZ', dZ);
                end
                %Rotate 90 deg
                Scp.Angle = Scp.Angle+90;
                clear pl;
            end
            %%
            %merge all to one list
            Pos.List = cell2mat(ListSide);
            
            % Make position labels and metadata
            Labels = {};
            Groups = {};
            Tiles = {};
            Counter =1;
            
            for i=1:size(ListSide,1)
                if ~isempty(ListSide{i})
                    for ix=1:numel(unique(ListSide{i}(:,1)))
                        for jx=1:numel(unique(ListSide{i}(:,2)))
                            Labels{Counter} = sprintf('Theta%03d_X%d_Y%d_tile%02d',90*(i-1),ix,jx,Counter-1);
                            Groups{Counter} = sprintf('Theta_%03d',mod(round(ListSide{i}((ix-1)*numel(unique(ListSide{i}(:,2)))+jx,4)),360));
                            Tiles{Counter} = num2str(Counter-1);
                            Counter = Counter+1;
                        end
                    end
                end
            end
            
            %Populate Position fields
            Pos.Labels = Labels;
            Pos.Group = Groups;
            % create metadata containing dZ and # frames per stack on eachside
            frmVec = [];
            for i=1:size(ListSide,1)
                frmVec = [frmVec repmat(nFrames(i),1,size(ListSide{i},1))];
            end
            ExpData= struct('nFrames', num2cell(frmVec),'dz',num2cell(repmat(dZ,1,size(Pos.List,1))),'Tile',Tiles);
            
            Pos.ExperimentMetadata = ExpData;
            
            Scp.Pos = Pos
        end
        
        
        
        function [Pos, ExpData] = createStackPositions(Scp)
            %open empty position list with 4 axes
            nFrames = [];
            ListSide = {};
            
            Pos = Positions([],'axis',{'X', 'Y','Z','Angle'})
            %clear MM list
            
            %create grid over cornea quadrant
            for i=1
                pl = Scp.studio.getPositionList;
                pl.clearAllPositions;
                
                Scp.studio.showPositionList;
                P1 = Scp.createPositionFromMMNoSet('axis', {'X' 'Y' 'Z'}, 'message', 'please mark edges of specimen or single position');
                ListSide{i} = Scp.createGridPosition(P1.List);
                Angle1 = Scp.Angle;
                ListSide{i} = [ListSide{i}, repmat(Angle1,size(ListSide{i},1),1)];
                
                %find # of Z stacks to take. Maxed at 428. Could either crop or
                %strech Z steps using varargin in nFramesNdZ
                figure(469)
                set(469,'Windowstyle','normal','toolbar','none','menubar','none','Position',[700 892 300 75],'Name','Please move to top Z position','NumberTitle','off')
                uicontrol(469,'Style', 'pushbutton', 'String','Done','Position',[100 20 100 35],'fontsize',13,'callback',@(~,~) close(469))
                uiwait(469);
                delZ = Scp.Z-min(ListSide{i}(:,3));
                if i==1;
                    [nFrames(i), dZ] = nFramesNdZ(Scp,delZ, 'crop', false, 'dZ', Scp.dZ);
                else
                    [nFrames(i), ~] = nFramesNdZ(Scp,delZ, 'crop', true, 'dZ', dZ);
                end
                %Rotate 90 deg
                clear pl;
            end
            %%
            %merge all to one list
            Pos.List = cell2mat(ListSide);
            
            % Make position labels and metadata
            Labels = {};
            Groups = {};
            Tiles = {};
            Counter =1;
            
            for i=1:size(ListSide,1)
                if ~isempty(ListSide{i})
                    for ix=1:numel(unique(ListSide{i}(:,1)))
                        for jx=1:numel(unique(ListSide{i}(:,2)))
                            Labels{Counter} = sprintf('Theta%03d_X%d_Y%d_tile%02d',mod(round(ListSide{i}((ix-1)*numel(unique(ListSide{i}(:,2)))+jx,4)),360),ix,jx,Counter-1);
                            Groups{Counter} = sprintf('Theta_%03d',mod(round(ListSide{i}((ix-1)*numel(unique(ListSide{i}(:,2)))+jx,4)),360));
                            Tiles{Counter} = num2str(Counter-1);
                            Counter = Counter+1;
                        end
                    end
                end
            end
            
            %Populate Position fields
            Pos.Labels = Labels;
            Pos.Group = Groups;
            % create metadata containing dZ and # frames per stack on eachside
            frmVec = [];
            for i=1:size(ListSide,1)
                frmVec = [frmVec repmat(nFrames(i),1,size(ListSide{i},1))];
            end
            ExpData= struct('nFrames', num2cell(frmVec),'dz',num2cell(repmat(dZ,1,size(Pos.List,1))),'Tile',Tiles);
            
            Pos.ExperimentMetadata = ExpData;
            
            %Scp.Pos = Pos;
        end
        
        
        
        
        
        
        
        
        
        function [nFrames1, nFrames2, dZ] = createCorneaPositions(Scp)
            %open empty position list with 4 axes
            Pos = Positions([],'axis',{'X', 'Y','Z','Angle'})
            %clear MM list
            pl = Scp.studio.getPositionList;
            pl.clearAllPositions;
            %create grid over whole cornea
            Scp.createPositionFromMM('axis', {'X' 'Y' 'Z'}, 'message', 'please mark top, bottom and edge of cornea');
            ListSide1 = Scp.createGridPosition(Scp.Pos.List);
            Angle1 = Scp.Angle;
            ListSide1 = [ListSide1, repmat(Angle1,size(ListSide1,1),1)];
            
            
            %find # of Z stacks to take. Maxed at 428. Could either crop or
            %strech Z steps using varargin in nFramesNdZ
            figure(469)
            set(469,'Windowstyle','normal','toolbar','none','menubar','none','Position',[700 892 300 75],'Name','Please move to top Z position','NumberTitle','off')
            uicontrol(469,'Style', 'pushbutton', 'String','Done','Position',[100 20 100 35],'fontsize',13,'callback',@(~,~) close(469))
            uiwait(469);
            delZ = Scp.Z-min(ListSide1(:,3));
            [nFrames1, dZ] = nFramesNdZ(Scp,delZ, 'crop', false, 'dZ', Scp.dZ);
            
            %clear MM list
            pl = Scp.studio.getPositionList;
            pl.clearAllPositions;
            Scp.studio.showPositionList
            %rotate cornea 180 degrees
            Scp.Angle = Scp.Angle+90;
            
            %repeat other side
            Scp.createPositionFromMM('axis', {'X' 'Y' 'Z'}, 'message', 'please mark top, bottom and edge of cornea');
            ListSide2 = Scp.createGridPosition(Scp.Pos.List);
            Angle2 = Scp.Angle;
            ListSide2 = [ListSide2, repmat(Angle2,size(ListSide2,1),1)];
            pl = Scp.studio.getPositionList;
            pl.clearAllPositions;
            
            figure(469)
            set(469,'Windowstyle','normal','toolbar','none','menubar','none','Position',[700 892 300 75],'Name','Please move to top Z position','NumberTitle','off')
            uicontrol(469,'Style', 'pushbutton', 'String','Done','Position',[100 20 100 35],'fontsize',13,'callback',@(~,~) close(469))
            uiwait(469);
            
            delZ = Scp.Z-min(ListSide2(:,3));
            [nFrames2, dZ] = nFramesNdZ(Scp,delZ, 'crop', true, 'dZ', dZ);
            pl = Scp.studio.getPositionList;
            pl.clearAllPositions;
            % merge list
            Pos.List = [ListSide1; ListSide2]
            
            Labels = {};
            Groups = {};
            Tiles = {};
            Counter =1;
            %A bit dirty, but making list of reasonable labels
            for ix=1:numel(unique(ListSide1(:,1)))
                for jx=1:numel(unique(ListSide1(:,2)))
                    Labels{Counter} = sprintf('Theta%03d_X%d_Y%d_tile%02d',0,ix,jx,Counter-1);
                    Groups{Counter} = 'Cornea';
                    Tiles{Counter} = num2str(Counter-1);
                    Counter = Counter+1;
                end
            end
            for ix=1:numel(unique(ListSide2(:,1)))
                for jx=1:numel(unique(ListSide2(:,2)))
                    Labels{Counter} = sprintf('Theta%03d_X%d_Y%d_tile%02d',180,ix,jx,Counter-1);
                    Groups{Counter} = 'Cornea';
                    Tiles{Counter} = num2str(Counter-1);
                    Counter = Counter+1;
                end
            end
            Pos.Labels = Labels;
            Pos.Group = Groups;
            % create metadata containing dZ and # frames per stack on eachside
            
            ExpData= struct('nFrames', num2cell([repmat(nFrames1,1,size(ListSide1,1)) repmat(nFrames2,1,size(ListSide2,1))]),...
                'dz',num2cell([repmat(dZ,1,size(ListSide1,1)) repmat(dZ,1,size(ListSide2,1))]),'Tile',Tiles);
            
            Pos.ExperimentMetadata = ExpData;
            
            Scp.Pos = Pos;
        end
        
        
        
        
        
        
        
        
        
        
        % calculates position of tiles so that overlap is maxed while
        % capturing all positions
        function [nFrames, dZ] = nFramesNdZ(Scp,delZ, varargin)
            %nFrames is <=428
            arg.crop=true; %if true, dZ is set to 2.93um, might crop ends. If false, dZ is automatically set to fill the whole range.
            arg.dz = 3;
            arg = parseVarargin(varargin,arg);
            
            %crop mode/span mode
            NmaxFrames = 4*428;%max images per stack
            dZ = arg.dz;
            nFrames = ceil(delZ/dZ);
            if nFrames > NmaxFrames
                nFrames = NmaxFrames;
                if ~arg.crop
                    dZ = delZ/NmaxFrames;
                end
            end
            %Set exposure so that stage moves dZ during a cycle.
            Scp.ZStage.Velocity=Scp.imagingVelocity;
            Scp.Exposure = 1000*dZ/Scp.ZStage.VelocityUm;
        end
        
        
        % function to make minimal grid out of edge positions
        function  List = createGridPosition(Scp, XYZ)
            %X = [300 300 1200]
            %Y = [300 2600 1200]
            %Z = [1200 1100 1120]
            
            %XYZ = [X',Y',Z']
            %% input 3 positions, top, bottom, front
            if size(XYZ,1)==1
                List = XYZ;
                return;
            end
            
            X = XYZ(:,1);
            Y = XYZ(:,2);
            
            %% Calculate # of stacks, and position of the stacks in X,Y. Take overlap>20%
            xDistance = max(X)-min(X);
            yDistance = max(Y)-min(Y);
            cameraXFieldOfView = Scp.PixelSize * Scp.Width;
            cameraYFieldOfView = Scp.PixelSize * Scp.Height;
            fieldOverlap = 0.2; %minimal overlap: fraction by which each field should overlap with neighbor. #position is minimized -> Overlap is maximized
            effectiveXFieldOfView = cameraXFieldOfView * (1 - fieldOverlap);%=step size X?
            effectiveYFieldOfView = cameraYFieldOfView * (1 - fieldOverlap);%=step size Y?
            nFieldsX = ceil(1+xDistance / effectiveXFieldOfView);
            nFieldsY = ceil(1+yDistance / effectiveYFieldOfView);
            disp(['Images per strip:' num2str(nFieldsX*nFieldsY)]);
            
            
            Ygrd = linspace(min(Y),max(Y),nFieldsY); %grid positions
            Xgrd = linspace(min(X),max(X),nFieldsX);
            
            Xpos = reshape(repmat(Xgrd,length(Ygrd),1),[],1); %full list of XY Positions
            Ypos = reshape(repmat(Ygrd',length(Xgrd),1),[],1);
            
            List = [Xpos, Ypos];
            
            Scp.Chamber.numOfsubChambers = nFieldsX*nFieldsY;
            Scp.Chamber.sz = [nFieldsX, nFieldsY];
            Scp.Chamber.Xcenter = Xpos;
            Scp.Chamber.Ycenter = Ypos;
            
            %% If we care about Z position
            %% Calculate plane positions sit on and make Z interpolation function
            if size(XYZ,1)==3
            elseif size(XYZ,1)==2
                XYZ(3,:) = [XYZ(1,1), XYZ(2,2), mean(XYZ(:,3))];
            else
                error('to create a grid you need 2 or 3 positions')
            end
            
            if size(XYZ,2)==3
                Z = XYZ(:,3);
                dXYZ = XYZ-repmat(XYZ(3,:),3,1);
                pNorm = cross(dXYZ(1,:),dXYZ(2,:))./norm(cross(dXYZ(1,:),dXYZ(2,:)));
                zInterp = @(x,y) -((pNorm(1:2)*([x,y]-XYZ(3,1:2))')/pNorm(3))+XYZ(3,3);
                
                Zpos = zeros(size(Xpos));
                for i=1:length(Zpos)
                    Zpos(i) = zInterp(Xpos(i), Ypos(i));
                end
                List = [Xpos, Ypos, Zpos];
            end
        end
        %
        %
        
%         %% gui
%         function LiveSnapWindow(Scp)
%             global KEY_IS_PRESSED
%             
%             figure(477);
%             set(477,'Windowstyle','normal','toolbar','none','menubar','none','Position',[100 500 250 150],'Name','Snap Snap','NumberTitle','off')
%             h = uicontrol(477,'Style', 'pushbutton','Position',[50 75 150 50],'fontsize',13, 'String', 'Snap', 'callback',@(x,y) SnapCallback(x,y,Scp));
%             function SnapCallback(hObject, event, Scp)
%                 Scp.snapImage;
%             end
%             
%             %Live
%             h = uicontrol(477,'Style', 'togglebutton','Position',[50 25 150 50],'fontsize',13, 'String', 'Live', 'Value',1,'callback',@(x,y) LiveClbk(x,y,Scp));
%             KEY_IS_PRESSED = h.Value;
%             function stpLiveClbk(hObject, event, Scp)
%                 KEY_IS_PRESSED  = 1;
%                 h = uicontrol(477,'Style', 'togglebutton','Position',[50 25 150 50],'fontsize',13, 'String', 'Live', 'Value',1,'callback',@(x,y) LiveClbk(x,y,Scp));
%                 Scp.mmc.setShutterOpen(false);
%             end
%             
%             function LiveClbk(hObject, event, Scp)
%                 
%                 h = uicontrol(477,'Style', 'togglebutton','Position',[50 25 150 50],'fontsize',13, 'String', 'Stop', 'Value',0,'callback',@(x,y) stpLiveClbk(x,y,Scp));
%                 KEY_IS_PRESSED = h.Value;
%                 Scp.mmc.setShutterOpen(true);
%                 try
%                     calllib('SpinnakerC_v140','spinCameraBeginAcquisition',Scp.Camera.Camera);
%                     while ~KEY_IS_PRESSED
%                         drawnow
%                         hResultImage  =  libpointer('voidPtr');
%                         calllib('SpinnakerC_v140','spinCameraGetNextImage',Scp.Camera.Camera,hResultImage);
%                         hConvertedImage = libpointer('voidPtr');%This does not live on the camera
%                         calllib('SpinnakerC_v140','spinImageCreateEmpty',hConvertedImage);
%                         calllib('SpinnakerC_v140','spinImageConvert',hResultImage,'PixelFormat_Mono16',hConvertedImage);
%                         
%                         gData = libpointer('int16Ptr',zeros(Scp.Camera.Width*Scp.Camera.Height,1));
%                         calllib('SpinnakerC_v140','spinImageGetData',hConvertedImage,gData);
%                         Scp.studio.displayImage(gData.Value);
%                         
%                         calllib('SpinnakerC_v140','spinImageRelease',hResultImage);
%                     end
%                     
%                     calllib('SpinnakerC_v140','spinCameraEndAcquisition',Scp.Camera.Camera);
%                 catch
%                     disp('something went horribly wrong!')
%                     %calllib('SpinnakerC_v140','spinImageDestroy',hConvertedImage);
%                     calllib('SpinnakerC_v140','spinImageRelease',hResultImage);
%                     calllib('SpinnakerC_v140','spinCameraEndAcquisition',Scp.Camera.Camera);
%                 end
%             end
%         end
        
        
        
        function ChannelsWindow(Scp)
            figure(417)
            set(417,'Windowstyle','normal','toolbar','none','menubar','none','Position',[100 688 250 75],'Name','Channels','NumberTitle','off')
            uicontrol(417,'Style','popup','String',Scp.getPossibleChannels,'Position',[50 0 150 50],'fontsize',13,'callback',@(source,~) Scp.setChannel(source.String{source.Value}));
        end
        
        
        
        
%        function prepareProcessingFiles(Scp)           
%             procDirName = [Scp.MD.pth '/Processing'];
%             if ~isdir(procDirName)
%                 mkdir(procDirName);
%             end
%             masterFileName = fullfile(procDirName,'master');
%             fid = fopen(masterFileName, 'wt' );
%             fprintf( fid, '%s\n', 'basedirfrom="/RazorScopeData/RazorScopeImages"');
%             fprintf( fid, '%s\n', 'basedirto="/RazorScopeData/RazorScopeSets"');
%             fprintf( fid, '%s\n\n', 'repodir="/home/wollmanlab/Documents/Repos/bigstitchparallel"');
%             
%             fprintf( fid, '%s\n', 'xmljobs_export="/Processing/xmljobs"');
%             fprintf( fid, '%s\n', 'hdf5jobs_export="/Processing/hdf5jobs"');
%             fprintf( fid, '%s\n', 'shiftjobs_export="/Processing/shiftjobs"');
%             fprintf( fid, '%s\n', 'optjobs_export="/Processing/optjobs"');
%             fprintf( fid, '%s\n', 'beadsjobs_export="/Processing/beadsjobs"');
%             fprintf( fid, '%s\n', 'ICPjobs_export="/Processing/ICPjobs"');
%             fprintf( fid, '%s\n', 'Multiviewjobs_export="/Processing/multiviewjobs"');
%             fprintf( fid, '%s\n', 'Stabilizejobs_export="/Processing/stabilizejobs"');
%             fprintf( fid, '%s\n', 'fusejobs_export="/Processing/fusejobs"');
%             fprintf( fid, '%s\n\n', 'fused_dir="/Fused"');
%             
%             pth = Scp.MD.pth;
%             pth = pth(strfind(Scp.MD.pth,Scp.Username)-1:end);
%             pth = strrep(pth,'\','/');
%             fprintf( fid, 'pth="%s"\n\n', pth);
%             
%             nTimePoint = numel(Scp.MD.unique('frame'));
%             nChannels = numel(Scp.MD.unique('Channel'));
%             nTiles = numel(Scp.MD.unique('Tile'));
%             nAngles = numel(Scp.MD.unique('group'));
%             
%             unqPos = unique(Scp.Pos.Group);         
%             fixPos = 0;
%             for i=1:numel(unqPos)-1
%                 fixPos = [fixPos sum(strcmp(unqPos{i},Scp.Pos.Group))];
%             end
%             fixPos = mat2str(fliplr(fixPos));
%             fixPos = fixPos(2:end-1);
%             nPos = 1;
%             
%             fprintf( fid, 'timepoints="%d"\n',nTimePoint );
%             fprintf( fid, 'channels="%d"\n', nChannels);
%             fprintf( fid, 'tiles="%d"\n', nTiles);
%             fprintf( fid, 'angles="%d"\n', nAngles);
%             fprintf( fid, 'pos="%d"\n\n', nPos);
%             fprintf( fid, 'fixPos="%s"\n\n', fixPos);
%             
%             zAspect = Scp.MD.unique('dz')./Scp.MD.unique('PixelSize');
%             fprintf( fid, 'zAspect="%.2f"\n', zAspect);
%             fclose(fid);
%             
%             
%           
%             
%             
%            %make steps file 
%             procDirName = [Scp.MD.pth '/Processing'];
%             if ~isdir(procDirName)
%                 mkdir(procDirName);
%             end
%             
%             pth = Scp.MD.pth;
%             pth = pth(strfind(Scp.MD.pth,Scp.Username)-1:end);
%             pth = strrep(pth,'\','/')
%             
%             nChannels = numel(Scp.MD.unique('Channel'));
%       
%             repoDir = '/home/wollmanlab/Documents/Repos/bigstitchparallel';
%             FullPathOnAnalysisBox = ['/RazorScopeData/RazorScopeImages' pth];
%             FullPathSetsOnAnalysisBox = ['/RazorScopeData/RazorScopeSets' pth];
%             MasterFileNameOnAnalysisBox = [FullPathOnAnalysisBox '/Processing/master'];
%             
%             stepsFileName = fullfile(procDirName,'steps');
%             fid = fopen(stepsFileName, 'wt' );
%             
%             fprintf( fid, 'Open terminal window and run:\n\n');
%             fprintf( fid, 'cd "%s"\n\n', repoDir);
%             %fprintf( fid, './MakeXMLDatasetJobSets.sh "%s"\n', MasterFileNameOnAnalysisBox);
%             %fprintf( fid, '%s/Processing/xmljobs/DefineXML.job\n\n', FullPathOnAnalysisBox);
%             %fprintf( fid, 'This will take some time, so go rest and do some productive things.\n\n');
%             %fprintf( fid, 'Next, run:\n\n');
%             fprintf( fid, './MakeHDFExportJobsSets.sh "%s"\n', MasterFileNameOnAnalysisBox);
%             fprintf( fid, 'parallel --memfree -24G --load 90%% --delay 10 -j16 --retry-failed < %s/Processing/hdf5jobs/commands.txt\n\n', FullPathOnAnalysisBox);
%             fprintf( fid, 'This will take some time, so go rest and do some productive things.\n\n');
%             fprintf( fid, 'Once this is done, the dataset is now saved in HDF5 format.\n\n\nOpen the set using BigStitcher to make sure everything is fine and delete the Tiffs. Time to start aligning!\n\n' );
%             %     fprintf( fid, 'First, we need to move the tiles to their location from the Tile Configuration File.\nUnfortunately this hasn`t been implemented in batch mode yet. Open BigStitcher and load the dataset.\nRight-click on any stack and select `Arrange Views-->Read Locations From File` etc. \n' );
%             
%             fprintf( fid, 'First, we need to move the tiles to their location from the Tile Configuration File.\n');
%             fprintf( fid, 'cd "%s"\n\n', repoDir);
%             
%             fprintf( fid, './MakeLoadConfig.sh "%s"\n', MasterFileNameOnAnalysisBox);
%             fprintf( fid, '%s/Processing/LoadTileConfig.job\n\n', FullPathSetsOnAnalysisBox);
%             fprintf( fid, 'Next, we calculate the shifts between tiles using cross-correlation.\n');
% 
%             fprintf( fid, './MakeCalculateShiftJobs.sh "%s"\n', MasterFileNameOnAnalysisBox);
%             fprintf(fid, 'parallel --memfree -24G --load 90%% --delay 5 -j8 --retry-failed < %s/Processing/shiftjobs/commands.txt\n\n', FullPathSetsOnAnalysisBox);
%             
%             fprintf( fid, 'Filter links and apply shifts using global optimization.\n');
% 
%             fprintf( fid, './MakeFilterAndOptimizeJobs.sh "%s"\n', MasterFileNameOnAnalysisBox);
%             fprintf(fid, 'parallel --memfree -24G --load 90%% --delay 5 -j8 --retry-failed < %s/Processing/shiftjobs/commands.txt\n\n', FullPathSetsOnAnalysisBox);
%                       
%             
%             fprintf( fid, 'Merge the files created by different processes.\n');
% 
%             fprintf( fid, '%s/Processing/MergeXMLs.sh\n\n', FullPathSetsOnAnalysisBox);
% 
%             fprintf( fid, 'Find interest points for the next steps.\n');
%             
%             fprintf( fid, './MakeFindPointsJobs.sh "%s"\n', MasterFileNameOnAnalysisBox);
%             fprintf(fid, 'parallel --memfree -24G --load 90%% --delay 5 -j12 --retry-failed < %s/Processing/beadsjobs/commands.txt\n\n', FullPathSetsOnAnalysisBox);
%             fprintf( fid, '%s/Processing/MergeXMLs.sh\n', FullPathSetsOnAnalysisBox);
%             %fprintf( fid, '%s/Processing/beadsjobs/commands.sh\n\n', FullPathSetsOnAnalysisBox);
%             
%              if nChannels>1 %ICP refinement for chromatic aberations
%                 fprintf( fid, 'Since we have more than 1 channel, we want to fix some "chromatic aberations".\n\n');
%                 fprintf( fid, 'cd "%s"\n', repoDir);
%                 fprintf( fid, './MakeICPJobs.sh "%s"\n', MasterFileNameOnAnalysisBox);
% %                fprintf( fid, '%s/Processing/ICPjobs/commands.sh\n\n', FullPathSetsOnAnalysisBox);
%                 fprintf(fid, 'parallel --memfree -24G --load 90%% --delay 5 -j16 --retry-failed < %s/Processing/ICPjobs/commands.txt\n\n', FullPathSetsOnAnalysisBox);
%                 fprintf( fid, '%s/Processing/MergeXMLs.sh\n', FullPathSetsOnAnalysisBox);
%              end      
%             
%             
%             fprintf( fid, 'At this point, we`ve finished stitching all the tiles together. We still need to stitch the different angles.\n' );
%             fprintf( fid, 'Open Fiji and open the set with BigStitcher. Make sure that tile registration looks ok.\n' );
%             fprintf( fid, 'Now, align the first timepoint using the BDV GUI. Make sure everything looks right.\n' );
%             fprintf( fid, 'save and close Fiji.\n\n' );
%             fprintf( fid, 'We align iteratively by inhereting all the previous transformations.\n\n' );
%             fprintf( fid, 'cd "%s"\n', repoDir);
%             fprintf( fid, './MakeMultiviewPropJobs.sh "%s"\n', MasterFileNameOnAnalysisBox);
%             fprintf( fid, '%s/Processing/multiviewjobs/MultiviewProp.job\n\n', FullPathSetsOnAnalysisBox);
%             
% 
%             
%             fprintf( fid, 'Fix drift.\n\n' );
%             fprintf( fid, './MakeStabilizeJobs.sh "%s"\n', MasterFileNameOnAnalysisBox);
%             fprintf( fid, '%s/Processing/stabilizejobs/commands.sh\n\n', FullPathSetsOnAnalysisBox);
%             
%             fclose(fid);
%             
%             
%             
%             
%             %make initial xml
%             ImageSize = [Scp.Width Scp.Height];
%             
%             xmlFileName = fullfile(Scp.MD.pth,'Processing','dataset.xml');
%             fid = fopen( xmlFileName, 'wt' );
%             fprintf( fid, '%s\n', '<?xml version="1.0" encoding="UTF-8"?>');
%             fprintf( fid, '%s\n', '<SpimData version="0.2">');
%             fprintf( fid, '%s\n', '  <BasePath type="relative">.</BasePath>');
%             fprintf( fid, '%s\n', '  <SequenceDescription>');
%             fprintf( fid, '%s\n', '    <ImageLoader format="spimreconstruction.filelist">');
%             fprintf( fid, '%s\n', '      <imglib2container>ArrayImgFactory</imglib2container>');
%             fprintf( fid, '%s\n', '      <ZGrouped>false</ZGrouped>');
%             fprintf( fid, '%s\n', '      <files>');
%             
%             
%             
%             Tiles = Scp.MD.unique('Tile');
%             Tiles = sort(str2double(Tiles));
%             Channels = Scp.MD.unique('Channel');
%             frames = Scp.MD.unique('frame');
%             for indFrame = 1:numel(frames)
%                 for indCh=1:numel(Channels)
%                     for indTile=1:numel(Tiles)
%                         filename = Scp.MD.getImageFilenameRelative({'frame', 'Channel', 'Tile'},{frames(indFrame),Channels(indCh),num2str(Tiles(indTile))});
%                         filename = strrep(filename,'\','/');
%                         viewsetup = (indCh-1)*numel(Tiles)+indTile-1;
%                         fprintf( fid, '%s%d%s%d%s\n', '        <FileMapping view_setup="',viewsetup,'" timepoint="',frames(indFrame)-1,'" series="0" channel="0">');
%                         fprintf( fid, '%s%s%s\n', '          <file type="relative">../',filename,'</file>');
%                         fprintf( fid, '%s\n', '        </FileMapping>');
%                     end
%                 end
%             end
%             fprintf( fid, '%s\n', '      </files>');
%             fprintf( fid, '%s\n', '    </ImageLoader>');
%             fprintf( fid, '%s\n', '    <ViewSetups>');
%             
%             angles = [];
%             dZratio = Scp.MD.unique('dz')./Scp.MD.unique('PixelSize');
%             nZs = Scp.MD.getSpecificMetadata('nFrames','frame',1,'sortby','Channel');
%             Positions = Scp.MD.getSpecificMetadata('Position','frame',1,'sortby','Channel');
%             
%             for indCh=1:numel(Channels)
%                 for indTile=1:numel(Tiles)
%                     viewsetup = (indCh-1)*numel(Tiles)+indTile-1;
%                     nZ = nZs{viewsetup+1};
%                     Position = Positions{viewsetup+1};
%                     ptrn='Theta';
%                     wherestheta = regexp(Position,ptrn);
%                     angle = str2double(Position(wherestheta+length(ptrn):wherestheta+length(ptrn)+2));
%                     angles = [angles angle];
%                     fprintf( fid, '%s\n', '      <ViewSetup>');
%                     fprintf( fid, '%s%d%s\n', '        <id>',viewsetup,'</id>');
%                     fprintf( fid, '%s%d%s\n', '        <name>',viewsetup,'</name>');
%                     fprintf( fid, '%s%d %d %d%s\n', '        <size>',ImageSize(1),ImageSize(2) ,nZ,'</size>');
%                     fprintf( fid, '%s\n', '        <voxelSize>');
%                     fprintf( fid, '%s\n', '          <unit>pixels</unit>');
%                     fprintf( fid, '%s%.1f %.1f %.2f%s\n', '          <size>',1,1,dZratio,'</size>');
%                     fprintf( fid, '%s\n', '        </voxelSize>');
%                     fprintf( fid, '%s\n', '        <attributes>');
%                     fprintf( fid, '%s\n', '          <illumination>0</illumination>');
%                     fprintf( fid, '%s%d%s\n', '          <channel>',indCh,'</channel>');
%                     fprintf( fid, '%s%d%s\n', '          <tile>',indTile-1,'</tile>');
%                     fprintf( fid, '%s%.0f%s\n', '          <angle>',angle,'</angle>');
%                     fprintf( fid, '%s\n', '        </attributes>');
%                     fprintf( fid, '%s\n', '      </ViewSetup>');
%                     
%                 end
%             end
%             angles = unique(angles);
%             
%             fprintf( fid, '%s\n', '      <Attributes name="illumination">');
%             fprintf( fid, '%s\n', '        <Illumination>');
%             fprintf( fid, '%s\n', '          <id>0</id>');
%             fprintf( fid, '%s\n', '          <name>0</name>');
%             fprintf( fid, '%s\n', '        </Illumination>');
%             fprintf( fid, '%s\n', '      </Attributes>');
%             
%             
%             fprintf( fid, '%s\n', '      <Attributes name="channel">');
%             for indCh=1:numel(Channels)
%                 fprintf( fid, '%s\n', '        <Channel>');
%                 fprintf( fid, '%s%d%s\n', '          <id>',indCh,'</id>');
%                 fprintf( fid, '%s%d%s\n', '          <name>',indCh,'</name>');
%                 fprintf( fid, '%s\n', '        </Channel>');
%             end
%             fprintf( fid, '%s\n', '      </Attributes>');
%             
%             fprintf( fid, '%s\n', '      <Attributes name="tile">');
%             for indTile=1:numel(Tiles)
%                 fprintf( fid, '%s\n', '        <Tile>');
%                 fprintf( fid, '%s%d%s\n', '          <id>',indTile-1,'</id>');
%                 fprintf( fid, '%s%d%s\n', '          <name>',indTile-1,'</name>');
%                 fprintf( fid, '%s\n', '        </Tile>');
%             end
%             fprintf( fid, '%s\n', '      </Attributes>');
%             
%             fprintf( fid, '%s\n', '      <Attributes name="angle">');
%             for i=1:numel(angles)
%                 fprintf( fid, '%s\n', '        <Angle>');
%                 fprintf( fid, '%s%d%s\n', '          <id>',angles(i),'</id>');
%                 fprintf( fid, '%s%d%s\n', '          <name>',angles(i),'</name>');
%                 fprintf( fid, '%s\n', '        </Angle>');
%             end
%             fprintf( fid, '%s\n', '      </Attributes>');
%             fprintf( fid, '%s\n', '    </ViewSetups>');
%             fprintf( fid, '%s\n', '    <Timepoints type="range">');
%             fprintf( fid, '%s%d%s\n', '      <first>',min(frames)-1,'</first>');
%             fprintf( fid, '%s%d%s\n', '      <last>',max(frames)-1,'</last>');
%             fprintf( fid, '%s\n', '    </Timepoints>');
%             
%             fprintf( fid, '%s\n', '    <MissingViews />');
%             fprintf( fid, '%s\n', '  </SequenceDescription>');
%             
%             
%             
%             fprintf( fid, '%s\n', '  <ViewRegistrations>');
%             for indFrame = 1:numel(frames)
%                 for indCh=1:numel(Channels)
%                     for indTile=1:numel(Tiles)
%                         viewsetup = (indCh-1)*numel(Tiles)+indTile-1;
%                         fprintf( fid, '%s%d%s%d%s\n', '    <ViewRegistration timepoint="',frames(indFrame)-1,'" setup="',viewsetup,'">');
%                         fprintf( fid, '%s\n', '      <ViewTransform type="affine">');
%                         fprintf( fid, '%s\n', '        <Name>calibration</Name>');
%                         fprintf( fid, '%s %.2f %s\n', '        <affine>1.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0',dZratio,'0.0</affine>');
%                         fprintf( fid, '%s\n', '      </ViewTransform>');
%                         fprintf( fid, '%s\n', '    </ViewRegistration>');
%                     end
%                 end
%             end
%             fprintf( fid, '%s\n', '  </ViewRegistrations>');
%             fprintf( fid, '%s\n', '  <ViewInterestPoints />');
%             fprintf( fid, '%s\n', '  <BoundingBoxes />');
%             fprintf( fid, '%s\n', '  <PointSpreadFunctions />');
%             fprintf( fid, '%s\n', '  <StitchingResults />');
%             fprintf( fid, '%s\n', '  <IntensityAdjustments />');
%             fprintf( fid, '%s\n', '</SpimData>');
%             
%             
%             
%             fclose(fid);
%             
%             
%             
%         end
%         
%         
%         
%         
        
        
        
        
        function prepareProcessingFilesBefore(Scp, AcqData)
            
            procDirName = [Scp.MD.pth '/Processing'];
            if ~isdir(procDirName)
                mkdir(procDirName);
            end
            masterFileName = fullfile(procDirName,'master');
            fid = fopen(masterFileName, 'wt' );
            fprintf( fid, '%s\n', 'basedirfrom="/RazorScopeData/RazorScopeImages"');
            fprintf( fid, '%s\n', 'basedirto="/RazorScopeData/RazorScopeSets"');
            fprintf( fid, '%s\n\n', 'repodir="/home/wollmanlab/Documents/Repos/bigstitchparallel"');
            
            fprintf( fid, '%s\n', 'xmljobs_export="/Processing/xmljobs"');
            fprintf( fid, '%s\n', 'hdf5jobs_export="/Processing/hdf5jobs"');
            fprintf( fid, '%s\n', 'shiftjobs_export="/Processing/shiftjobs"');
            fprintf( fid, '%s\n', 'optjobs_export="/Processing/optjobs"');
            fprintf( fid, '%s\n', 'beadsjobs_export="/Processing/beadsjobs"');
            fprintf( fid, '%s\n', 'ICPjobs_export="/Processing/ICPjobs"');
            fprintf( fid, '%s\n', 'Multiviewjobs_export="/Processing/multiviewjobs"');
            fprintf( fid, '%s\n', 'Stabilizejobs_export="/Processing/stabilizejobs"');
            fprintf( fid, '%s\n', 'Finalrefinejobs_export="/Processing/finalrefinejobs"');
            
            fprintf( fid, '%s\n', 'fusejobs_export="/Processing/fusejobs"');
            fprintf( fid, '%s\n\n', 'fused_dir="/Fused"');
            
            pth = Scp.MD.pth;
            pth = pth(strfind(Scp.MD.pth,Scp.Username)-1:end);
            pth = strrep(pth,'\','/');
            fprintf( fid, 'pth="%s"\n\n', pth);
            
            if isa(Scp.Tpnts,'Timepoints')
                nTimePoint = Scp.Tpnts.num;
            else
                nTimePoint=1;
            end
            
            nChannels = numel(AcqData);
            nTiles = Scp.Pos.N;
            nAngles = numel(unique(Scp.Pos.Group));
            
            unqPos = unique(Scp.Pos.Group);         
            fixPos = 0;
            for i=1:numel(unqPos)-1
                fixPos = [fixPos sum(strcmp(unqPos{i},Scp.Pos.Group))];
            end
            fixPos = mat2str(fliplr(fixPos));
            fixPos = fixPos(2:end-1);
            nPos = 1;
            
            fprintf( fid, 'timepoints="%d"\n',nTimePoint );
            fprintf( fid, 'channels="%d"\n', nChannels);
            fprintf( fid, 'tiles="%d"\n', nTiles);
            fprintf( fid, 'angles="%d"\n', nAngles);
            fprintf( fid, 'pos="%d"\n\n', nPos);
            fprintf( fid, 'fixPos="%s"\n\n', fixPos);
            
            zAspect = unique(Scp.Pos.ExperimentMetadata(1).dz)./Scp.PixelSize;
            fprintf( fid, 'zAspect="%.2f"\n', zAspect);
            fclose(fid);
            
            
          
            
            
           %make steps file 
            %procDirName = [Scp.MD.pth '/Processing'];
            %if ~isdir(procDirName)
            %    mkdir(procDirName);
            %end
            
            pth = Scp.MD.pth;
            pth = pth(strfind(Scp.MD.pth,Scp.Username)-1:end);
            pth = strrep(pth,'\','/')
            
%            nChannels = numel(Scp.MD.unique('Channel'));
            nChannels =     numel(AcqData);
      
            repoDir = '/home/wollmanlab/Documents/Repos/bigstitchparallel';
            FullPathOnAnalysisBox = ['/RazorScopeData/RazorScopeImages' pth];
            FullPathSetsOnAnalysisBox = ['/RazorScopeData/RazorScopeSets' pth];
            MasterFileNameOnAnalysisBox = [FullPathOnAnalysisBox '/Processing/master'];
            
            stepsFileName = fullfile(procDirName,'steps');
            fid = fopen(stepsFileName, 'wt' );
            
            fprintf( fid, 'As soon as anything appears on the analysis machine, Open terminal window and run:\n\n');
            %fprintf( fid, 'cd "%s"\n\n', repoDir);
            %fprintf( fid, './MakeXMLDatasetJobSets.sh "%s"\n', MasterFileNameOnAnalysisBox);
            %fprintf( fid, '%s/Processing/xmljobs/DefineXML.job\n\n', FullPathOnAnalysisBox);
            %fprintf( fid, 'This will take some time, so go rest and do some productive things.\n\n');
            %fprintf( fid, 'Next, run:\n\n');
            fprintf( fid, '%s/OTFConvertToHDF5.sh "%s"\n\n', repoDir ,MasterFileNameOnAnalysisBox);
            
            fprintf( fid, 'This will take some time, so go rest and do some productive things.\n\n');
            fprintf( fid, 'Once this is done, the dataset is saved in HDF5 format.\n\n\nOpen the set using BigStitcher to make sure everything is fine and delete the Tiffs. Time to start aligning!\n\n' );
            %     fprintf( fid, 'First, we need to move the tiles to their location from the Tile Configuration File.\nUnfortunately this hasn`t been implemented in batch mode yet. Open BigStitcher and load the dataset.\nRight-click on any stack and select `Arrange Views-->Read Locations From File` etc. \n' );
            
            fprintf( fid, 'First, we need to move the tiles to their location from the Tile Configuration File.\n');
            %fprintf( fid, 'cd "%s"\n\n', repoDir);
            
            fprintf( fid, '%s/loadTileConfig.sh "%s"\n\n',repoDir, MasterFileNameOnAnalysisBox);
            %fprintf( fid, '%s/Processing/LoadTileConfig.job\n\n', FullPathSetsOnAnalysisBox);
            fprintf( fid, 'Next, we stitch tiles using cross-correlation.\n');

            fprintf( fid, '%s/stitchTiles.sh "%s"\n\n',repoDir, MasterFileNameOnAnalysisBox);
            %fprintf(fid, 'parallel --memfree -24G --load 90%% --delay 5 -j8 --retry-failed < %s/Processing/shiftjobs/commands.txt\n\n', FullPathSetsOnAnalysisBox);
            
            %fprintf( fid, 'Filter links and apply shifts using global optimization.\n');

            %fprintf( fid, './MakeFilterAndOptimizeJobs.sh "%s"\n', MasterFileNameOnAnalysisBox);
            %fprintf(fid, 'parallel --memfree -24G --load 90%% --delay 5 -j8 --retry-failed < %s/Processing/shiftjobs/commands.txt\n\n', FullPathSetsOnAnalysisBox);
                      
            
            %fprintf( fid, 'Merge the files created by different processes.\n');

            %fprintf( fid, '%s/Processing/MergeXMLs.sh\n\n', FullPathSetsOnAnalysisBox);

            fprintf( fid, 'Find interest points for the next steps.\n');
            
            fprintf( fid, '%s/findBeads.sh "%s"\n\n',repoDir, MasterFileNameOnAnalysisBox);
            %fprintf(fid, 'parallel --memfree -24G --load 90%% --delay 5 -j12 --retry-failed < %s/Processing/beadsjobs/commands.txt\n\n', FullPathSetsOnAnalysisBox);
            %fprintf( fid, '%s/Processing/MergeXMLs.sh\n', FullPathSetsOnAnalysisBox);
            %fprintf( fid, '%s/Processing/beadsjobs/commands.sh\n\n', FullPathSetsOnAnalysisBox);
            
             if nChannels>1 %ICP refinement for chromatic aberations
                fprintf( fid, 'Since we have more than 1 channel, we want to fix some "chromatic aberations".\n\n');
                fprintf( fid, '%s/fixChromaticAbberations.sh "%s"\n\n',repoDir, MasterFileNameOnAnalysisBox);
%                fprintf( fid, '%s/Processing/ICPjobs/commands.sh\n\n', FullPathSetsOnAnalysisBox);
                %fprintf(fid, 'parallel --memfree -24G --load 90%% --delay 5 -j16 --retry-failed < %s/Processing/ICPjobs/commands.txt\n\n', FullPathSetsOnAnalysisBox);
                %fprintf( fid, '%s/Processing/MergeXMLs.sh\n', FullPathSetsOnAnalysisBox);
             end      
            
            
            fprintf( fid, 'At this point, we`ve finished stitching all the tiles together. We still need to stitch the different angles.\n' );
            fprintf( fid, 'Open Fiji and open the set with BigStitcher. Make sure that tile registration looks ok.\n' );
            fprintf( fid, 'Now, align the first timepoint using the BDV GUI. Make sure everything looks right.\n' );
            fprintf( fid, 'save and close Fiji.\n\n' );
            fprintf( fid, 'We align iteratively by inhereting all the previous transformations.\n\n' );
            %fprintf( fid, 'cd "%s"\n', repoDir);
            fprintf( fid, '%s/MultiviewReconstruct.sh "%s"\n\n',repoDir, MasterFileNameOnAnalysisBox);
            %fprintf( fid, '%s/Processing/multiviewjobs/MultiviewProp.job\n\n', FullPathSetsOnAnalysisBox);
            

            
            fprintf( fid, 'Fix drift.\n\n' );
            fprintf( fid, '%s/driftCorrection.sh "%s"\n\n', repoDir, MasterFileNameOnAnalysisBox);
            %fprintf( fid, '%s/Processing/stabilizejobs/commands.sh\n\n', FullPathSetsOnAnalysisBox);
            fprintf( fid, '%s/finalRefinement.sh "%s"\n\n', repoDir, MasterFileNameOnAnalysisBox);
            
            
            fprintf( fid, 'Finally, fuse dataset.\n\n' );
            fprintf( fid, '%s/Fuse.sh "%s"\n\n', repoDir, MasterFileNameOnAnalysisBox);
            
            fclose(fid);
            
            
            
            
            %make initial xml
            ImageSize = [Scp.Width Scp.Height];
            xmlFileName = fullfile(procDirName,'dataset.xml');
            fid = fopen( xmlFileName, 'wt' );
            
            filesToJobsDictionary = fullfile(procDirName,'filesToJobsDictionary.txt');
            fidFTJ = fopen( filesToJobsDictionary, 'wt' );
            
            
            fprintf( fid, '%s\n', '<?xml version="1.0" encoding="UTF-8"?>');
            fprintf( fid, '%s\n', '<SpimData version="0.2">');
            fprintf( fid, '%s\n', '  <BasePath type="relative">.</BasePath>');
            fprintf( fid, '%s\n', '  <SequenceDescription>');
            fprintf( fid, '%s\n', '    <ImageLoader format="spimreconstruction.filelist">');
            fprintf( fid, '%s\n', '      <imglib2container>ArrayImgFactory</imglib2container>');
            fprintf( fid, '%s\n', '      <ZGrouped>false</ZGrouped>');
            fprintf( fid, '%s\n', '      <files>');
            
            
            
            %Tiles = Scp.MD.unique('Tile');
            %Tiles = sort(str2double(Tiles));
            Tiles = 0:Scp.Pos.N-1;
            %Channels = Scp.MD.unique('Channel');
            Channels = {AcqData.Channel}';
            %frames = Scp.MD.unique('frame');
            if isa(Scp.Tpnts,'Timepoints')
                frames = 1:Scp.Tpnts.N;
            else
                frames=1;
            end
            counter=1;
            for indFrame = 1:numel(frames)
                for indCh=1:numel(Channels)
                    for indTile=1:numel(Tiles)
                        
                        filename = sprintf('img_%s_%03g_Ch%d_000.tif',Scp.Pos.Labels{indTile},indFrame-1,indCh);
                        fprintf(fidFTJ, '%d\t%s\n' ,counter,filename(1:end-4));

                        filename = [filename(1:end-4) '/MMStack.ome.tif'];                      
                        %filename = Scp.MD.getImageFilenameRelative({'frame', 'Channel', 'Tile'},{frames(indFrame),Channels(indCh),num2str(Tiles(indTile))});
                        filename = strrep(filename,'\','/');
                        counter = counter+1;
                        viewsetup = (indCh-1)*numel(Tiles)+indTile-1;
                        fprintf( fid, '%s%d%s%d%s\n', '        <FileMapping view_setup="',viewsetup,'" timepoint="',frames(indFrame)-1,'" series="0" channel="0">');
                        fprintf( fid, '%s%s%s\n', '          <file type="relative">../',filename,'</file>');
                        fprintf( fid, '%s\n', '        </FileMapping>');
                    end
                end
            end
            fprintf( fid, '%s\n', '      </files>');
            fprintf( fid, '%s\n', '    </ImageLoader>');
            fprintf( fid, '%s\n', '    <ViewSetups>');
            
            fclose(fidFTJ);
            
            angles = [];
            dZratio = unique(Scp.Pos.ExperimentMetadata(1).dz)./Scp.PixelSize;
           %nZs = Scp.MD.getSpecificMetadata('nFrames','frame',1,'sortby','Channel');
            
            nZs = {Scp.Pos.ExperimentMetadata.nFrames}';
            %Positions = Scp.MD.getSpecificMetadata('Position','frame',1,'sortby','Channel');
            Positions = Scp.Pos.Labels';
            for indCh=1:numel(Channels)
                for indTile=1:numel(Tiles)
                    viewsetup = (indCh-1)*numel(Tiles)+indTile-1;
                    nZ = nZs{indTile};
                    Position = Positions{indTile};
                    ptrn='Theta';
                    wherestheta = regexp(Position,ptrn);
                    angle = str2double(Position(wherestheta+length(ptrn):wherestheta+length(ptrn)+2));
                    angles = [angles angle];
                    fprintf( fid, '%s\n', '      <ViewSetup>');
                    fprintf( fid, '%s%d%s\n', '        <id>',viewsetup,'</id>');
                    fprintf( fid, '%s%d%s\n', '        <name>',viewsetup,'</name>');
                    fprintf( fid, '%s%d %d %d%s\n', '        <size>',ImageSize(1),ImageSize(2) ,nZ,'</size>');
                    fprintf( fid, '%s\n', '        <voxelSize>');
                    fprintf( fid, '%s\n', '          <unit>pixels</unit>');
                    fprintf( fid, '%s%.1f %.1f %.2f%s\n', '          <size>',1,1,dZratio,'</size>');
                    fprintf( fid, '%s\n', '        </voxelSize>');
                    fprintf( fid, '%s\n', '        <attributes>');
                    fprintf( fid, '%s\n', '          <illumination>0</illumination>');
                    fprintf( fid, '%s%d%s\n', '          <channel>',indCh,'</channel>');
                    fprintf( fid, '%s%d%s\n', '          <tile>',indTile-1,'</tile>');
                    fprintf( fid, '%s%.0f%s\n', '          <angle>',angle,'</angle>');
                    fprintf( fid, '%s\n', '        </attributes>');
                    fprintf( fid, '%s\n', '      </ViewSetup>');
                    
                end
            end
            angles = unique(angles);
            
            fprintf( fid, '%s\n', '      <Attributes name="illumination">');
            fprintf( fid, '%s\n', '        <Illumination>');
            fprintf( fid, '%s\n', '          <id>0</id>');
            fprintf( fid, '%s\n', '          <name>0</name>');
            fprintf( fid, '%s\n', '        </Illumination>');
            fprintf( fid, '%s\n', '      </Attributes>');
            
            
            fprintf( fid, '%s\n', '      <Attributes name="channel">');
            for indCh=1:numel(Channels)
                fprintf( fid, '%s\n', '        <Channel>');
                fprintf( fid, '%s%d%s\n', '          <id>',indCh,'</id>');
                fprintf( fid, '%s%d%s\n', '          <name>',indCh,'</name>');
                fprintf( fid, '%s\n', '        </Channel>');
            end
            fprintf( fid, '%s\n', '      </Attributes>');
            
            fprintf( fid, '%s\n', '      <Attributes name="tile">');
            for indTile=1:numel(Tiles)
                fprintf( fid, '%s\n', '        <Tile>');
                fprintf( fid, '%s%d%s\n', '          <id>',indTile-1,'</id>');
                fprintf( fid, '%s%d%s\n', '          <name>',indTile-1,'</name>');
                fprintf( fid, '%s\n', '        </Tile>');
            end
            fprintf( fid, '%s\n', '      </Attributes>');
            
            fprintf( fid, '%s\n', '      <Attributes name="angle">');
            for i=1:numel(angles)
                fprintf( fid, '%s\n', '        <Angle>');
                fprintf( fid, '%s%d%s\n', '          <id>',angles(i),'</id>');
                fprintf( fid, '%s%d%s\n', '          <name>',angles(i),'</name>');
                fprintf( fid, '%s\n', '        </Angle>');
            end
            fprintf( fid, '%s\n', '      </Attributes>');
            fprintf( fid, '%s\n', '    </ViewSetups>');
            fprintf( fid, '%s\n', '    <Timepoints type="range">');
            fprintf( fid, '%s%d%s\n', '      <first>',min(frames)-1,'</first>');
            fprintf( fid, '%s%d%s\n', '      <last>',max(frames)-1,'</last>');
            fprintf( fid, '%s\n', '    </Timepoints>');
            
            fprintf( fid, '%s\n', '    <MissingViews />');
            fprintf( fid, '%s\n', '  </SequenceDescription>');
            
            
            
            fprintf( fid, '%s\n', '  <ViewRegistrations>');
            for indFrame = 1:numel(frames)
                for indCh=1:numel(Channels)
                    for indTile=1:numel(Tiles)
                        viewsetup = (indCh-1)*numel(Tiles)+indTile-1;
                        fprintf( fid, '%s%d%s%d%s\n', '    <ViewRegistration timepoint="',frames(indFrame)-1,'" setup="',viewsetup,'">');
                        fprintf( fid, '%s\n', '      <ViewTransform type="affine">');
                        fprintf( fid, '%s\n', '        <Name>calibration</Name>');
                        fprintf( fid, '%s %.2f %s\n', '        <affine>1.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0',dZratio,'0.0</affine>');
                        fprintf( fid, '%s\n', '      </ViewTransform>');
                        fprintf( fid, '%s\n', '    </ViewRegistration>');
                    end
                end
            end
            fprintf( fid, '%s\n', '  </ViewRegistrations>');
            fprintf( fid, '%s\n', '  <ViewInterestPoints />');
            fprintf( fid, '%s\n', '  <BoundingBoxes />');
            fprintf( fid, '%s\n', '  <PointSpreadFunctions />');
            fprintf( fid, '%s\n', '  <StitchingResults />');
            fprintf( fid, '%s\n', '  <IntensityAdjustments />');
            fprintf( fid, '%s\n', '</SpimData>');
            
            
            
            fclose(fid);
            
            
            
        end
        
        
        
    end
    
end