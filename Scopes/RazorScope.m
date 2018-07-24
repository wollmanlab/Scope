classdef RazorScope < Scope
   
    properties
        Angle
        Camera='Ximea';
        ZStage
        LaserTrigger = Snapper;
    end
    
    methods
        function Objective = getObjective(Scp)
            Objective = 'You Guys miss Yanfei, yet?, yes we do....';
        end
        
        function PixelSize = getPixelSize(Scp)
            %PixelSize = Scp.mmc.getPixelSizeUm;
            Mag = 14.4;
            CamPixSize = 3.45;
            Demag = 0.63;
            PixelSize = CamPixSize/Mag/Demag;
        end
               
                
        function bd=getBitDepth(Scp)
            bd=16;
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
        
        function w=getWidth(Scp)
            if ischar(Scp.Camera) && strcmp(Scp.Camera,'Zyla')
                w=getWidth@Scope(Scp); 
            else
                w=1824; 
            end
        end
        
        function h=getHeight(Scp)
            if ischar(Scp.Camera) && strcmp(Scp.Camera,'Zyla')
                h=getHeight@Scope(Scp); 
            else
                h=2736;
            end
        end
        
%         function exptime=getExposure(Scp)
%             if ischar(Scp.Camera) && strcmp(Scp.Camera,'Zyla')
%                 exptime=getExposure@Scope(Scp); 
%                 return
%             end
%            exptime=Scp.Camera.Exposure; 
%         end
%         
%         function setExposure(Scp,exptime)
%              if ischar(Scp.Camera) && strcmp(Scp.Camera,'Zyla')
%                 setExposure@Scope(Scp,exptime); 
%                 return
%             end
%             Scp.Camera.Exposure=exptime; 
%         end
        
        function setAngle(Scp,a)
            try
                Scp.mmc.setPosition(Scp.DeviceNames.AngularStage,a./1.8)
                Scp.mmc.waitForDevice(Scp.mmc.getProperty('Core','Focus'));
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
        
        function img=commandCameraToCapture(Scp)
            if ischar(Scp.Camera) && strcmp(Scp.Camera,'Zyla')
                img = commandCameraToCapture@Scope(Scp); 
            else
                assert(isa(Scp.Camera,'SpinMATLABScp'),'If camera is not Zyla, must be a SpinMATLAB object')
%                Scp.mmc.setShutterOpen(true); 
                img = Scp.Camera.snapImage(Scp,1); 
%                Scp.mmc.setShutterOpen(false); 
            end
        end
        
        
        function stk = snapSeq(Scp,nrFrames)
            if ischar(Scp.Camera) && strcmp(Scp.Camera,'Zyla')
                stk = snapSeq@Scope(Scp,nrFrames);
            else
                assert(isa(Scp.Camera,'SpinMATLABScp'),'If camera is not Zyla, must be a SpinMATLAB object')
                stk = Scp.Camera.snapImage(Scp,nrFrames,'show', false);
                stk = Scp.convertMMimgToMatlabFormat(stk);
            end
        end
        
        
        function img=convertMMimgToMatlabFormat(Scp,img)
            if ischar(Scp.Camera) && strcmp(Scp.Camera,'Zyla')
                img = convertMMimgToMatlabFormat@Scope(Scp,img);
            else
 %               img = double(img);%AOY and Rob, fix saturation BS.
 %               img(img<0)=img(img<0)+2^16;
 %               img = mat2gray(img,[1 2^16]);
            end
        end
     
        
        
        
        
        
        
        
        
        
        

        %
        %% acquisition sequences
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
            [nFrames1, dZ] = nFramesNdZ(Scp,delZ, 'crop', false);
            
            %clear MM list
            pl = Scp.studio.getPositionList;
            pl.clearAllPositions;
            
            %rotate cornea 180 degrees
            Scp.Angle = Scp.Angle+180;
            
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
            Counter =1;
            %A bit dirty, but making list of reasonable labels
            for ix=1:numel(unique(ListSide1(:,1)))
                for jx=1:numel(unique(ListSide1(:,2)))
                    Labels{Counter} = sprintf('Theta%d_X%d_Y%d',1,ix,jx);
                    Counter = Counter+1;
                end
            end
            for ix=1:numel(unique(ListSide2(:,1)))
                for jx=1:numel(unique(ListSide2(:,2)))
                    Labels{Counter} = sprintf('Theta%d_X%d_Y%d',2,ix,jx);
                    Counter = Counter+1;
                end
            end
            Pos.Labels = Labels;
            
            % create metadata containing dZ and # frames per stack on eachside
            
            ExpData= struct('nFrames', num2cell([repmat(nFrames1,1,size(ListSide1,1)) repmat(nFrames2,1,size(ListSide2,1))]),...
                'dz',num2cell([repmat(dZ,1,size(ListSide1,1)) repmat(dZ,1,size(ListSide2,1))]));
            
            Pos.ExperimentMetadata = ExpData;
            
            Scp.Pos = Pos;
        end
        
        % calculates position of tiles so that overlap is maxed while
        % capturing all positions
        function [nFrames, dZ] = nFramesNdZ(Scp,delZ, varargin)
            %nFrames is <=428
            arg.crop=true; %if true, dZ is set to 3.5um, might crop ends. If false, dZ is automatically set to fill the whole range.
            arg.dz = 3.5;
            arg = parseVarargin(varargin,arg);
            
            %crop mode/span mode
            NmaxFrames = 428;%max images per stack
            dZ = arg.dz;
            nFrames = ceil(delZ/dZ);
            if nFrames > NmaxFrames
                nFrames = NmaxFrames;
                if ~arg.crop
                    dZ = delZ/NmaxFrames;
                end
            end
            %Set exposure so that stage moves dZ during a cycle.
            Scp.ZStage.Velocity=1;
            Scp.Exposure = 1000*dZ/Scp.ZStage.VelocityUm;
        end
        
        
        % function to make minimal grid out of edge positions
        function  List = createGridPosition(Scp, XYZ)
            %X = [300 300 1200]
            %Y = [300 2600 1200]
            %Z = [1200 1100 1120]
            
            %XYZ = [X',Y',Z']
            %% input 3 positions, top, bottom, front
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













%% gui
        function LiveSnapWindow(Scp)
            global KEY_IS_PRESSED
            
            figure(477);
            set(477,'Windowstyle','normal','toolbar','none','menubar','none','Position',[100 500 250 150],'Name','Snap Snap','NumberTitle','off')
            h = uicontrol(477,'Style', 'pushbutton','Position',[50 75 150 50],'fontsize',13, 'String', 'Snap', 'callback',@(x,y) SnapCallback(x,y,Scp));
            function SnapCallback(hObject, event, Scp)
                Scp.snapImage;
            end
            
            %Live
            h = uicontrol(477,'Style', 'togglebutton','Position',[50 25 150 50],'fontsize',13, 'String', 'Live', 'Value',1,'callback',@(x,y) LiveClbk(x,y,Scp));
            KEY_IS_PRESSED = h.Value;
            function stpLiveClbk(hObject, event, Scp)
                KEY_IS_PRESSED  = 1;
                h = uicontrol(477,'Style', 'togglebutton','Position',[50 25 150 50],'fontsize',13, 'String', 'Live', 'Value',1,'callback',@(x,y) LiveClbk(x,y,Scp));
                Scp.mmc.setShutterOpen(false);
            end
            
            function LiveClbk(hObject, event, Scp)
                
                h = uicontrol(477,'Style', 'togglebutton','Position',[50 25 150 50],'fontsize',13, 'String', 'Stop', 'Value',0,'callback',@(x,y) stpLiveClbk(x,y,Scp));
                KEY_IS_PRESSED = h.Value;
                Scp.mmc.setShutterOpen(true);
                try
                    calllib('SpinnakerC_v140','spinCameraBeginAcquisition',Scp.Camera.Camera);
                    while ~KEY_IS_PRESSED
                        drawnow
                        hResultImage  =  libpointer('voidPtr');
                        calllib('SpinnakerC_v140','spinCameraGetNextImage',Scp.Camera.Camera,hResultImage);
                        hConvertedImage = libpointer('voidPtr');%This does not live on the camera
                        calllib('SpinnakerC_v140','spinImageCreateEmpty',hConvertedImage);
                        calllib('SpinnakerC_v140','spinImageConvert',hResultImage,'PixelFormat_Mono16',hConvertedImage);
                        
                        gData = libpointer('int16Ptr',zeros(Scp.Camera.Width*Scp.Camera.Height,1));
                        calllib('SpinnakerC_v140','spinImageGetData',hConvertedImage,gData);
                        Scp.studio.displayImage(gData.Value);
                        
                        calllib('SpinnakerC_v140','spinImageRelease',hResultImage);
                    end
                    
                    calllib('SpinnakerC_v140','spinCameraEndAcquisition',Scp.Camera.Camera);
                catch
                    disp('something went horribly wrong!')
                    %calllib('SpinnakerC_v140','spinImageDestroy',hConvertedImage);
                    calllib('SpinnakerC_v140','spinImageRelease',hResultImage);
                    calllib('SpinnakerC_v140','spinCameraEndAcquisition',Scp.Camera.Camera);
                end
            end
        end
        
        
        
        function ChannelsWindow(Scp)
            figure(417)
            set(417,'Windowstyle','normal','toolbar','none','menubar','none','Position',[100 688 250 75],'Name','Channels','NumberTitle','off')
            uicontrol(417,'Style','popup','String',Scp.getPossibleChannels,'Position',[50 0 150 50],'fontsize',13,'callback',@(source,~) Scp.setChannel(source.String{source.Value}));
        end
        
    end
    
end