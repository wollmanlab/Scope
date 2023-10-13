classdef OrangeScope < Scope
   
    properties
       OptovarStatus=[];
       Notifications = Notifications;
       AF = ContrastPlaneFocus;
       TempHumiditySensor = DHT11('COM9');
       FlowData = FluidicsData;
       X_stage_max_limit = 55000;
       X_stage_min_limit = -55000;
       Y_stage_max_limit = 37500;
       Y_stage_min_limit = -37500;
       X_offset = 0; % Distance of Scp.X=0 from center of stage
       Y_offset = 0; % Distance of Scp.Y=0 from center of stage
       directionXY = [-1,1]; % double check
    end
    
    methods
        
        function Scp = OrangeScope()
            Scp@Scope();
            Scp.FlowData.device = 'OrangeFluidics';
            Scp.dXY = [Scp.X_offset Scp.Y_offset];
            %addpath('C:\Fiji.app\scripts')
            %addpath('C:\Program Files\Micro-Manager-2.0gamma')
            import mmcorej.*;
            import org.micromanager.*;
            Scp.studio = StartMMStudio('C:\Program Files\Micro-Manager-2.0gamma');
            Scp.mmc = Scp.studio.getCMMCore;
            
            Scp.ErrorLogPth='C:\GitRepos\Scope\ErrorLogs';
            
            disp('My name is Orange and I am a microscope. ')
            Scp.basePath = 'D:/Images';
            Scp.DeviceNames.Objective = 'TINosePiece';
            Scp.DeviceNames.AFoffset = 'TIPFSOffset';
            Scp.DeviceNames.LightPath = {'TILightPath','Label','Left100', 'Right100'};
            Scp.ScopeName = 'Ninja';
            Scp.mmc.setChannelGroup('Channel');
            Scp.CameraName = 'Camera';
            Scp.TriggerDeviceName='LEDarray-Switch';
            Scp.CameraAngle = 3.2857;
            %end
            
            Scp.mmc.setProperty(Scp.CameraName,'Gain-AutoOrManual','Manual');
            Scp.mmc.setProperty(Scp.CameraName,'Gain(dB)','4');
            Scp.Chamber = Plate('Costar96 (3904)');
            Scp.Chamber.x0y0 = [ 49776      -31364];
            Scp.Chamber.directionXY = [-1 1];
            Scp.AutoFocusType = 'Hardware';
            
            
            %% Flatfield
            %if strcmp(button,'Nikon')
            Scp.FlatFieldsFileName='D:\Images\FlatFieldCorrections\Flatfield.mat';
            %Scp.loadFlatFields;
            %Scp.CorrectFlatField = false;
            Scp.mmc.setProperty(Scp.DeviceNames.LightPath{1},Scp.DeviceNames.LightPath{2},Scp.DeviceNames.LightPath{4});
            Scp.Zpercision = 0.5;
            Scp.reduceAllOverheadForSpeed = 1;
            Scp.AutoFocusType='none';
            Scp.acqshow = 'single';
            Miji;
        end
        
        function Texpose = lightExposure(Scp,ExcitationPosition,Time,varargin)
            arg.units = 'seconds';
            arg.dichroic = '425LP';
            arg.shutter = 'ExcitationShutter';
            arg.cameraport = false;
            arg.stagespeed = [];
            arg.mirrorpos = 'mirror'; %added by naomi 1/27/17
            arg.move=[]; % array of nx2 of position to move between in circular fashion. relative to current position in um
            arg.movetimes = [];
            arg.objective = '20x';  % open
            arg.power=500; % percent
            arg = parseVarargin(varargin,arg);
            % switch time to seconds
            switch arg.units
                case {'msec','millisec','milliseconds'}
                    Time=Time/1000;
                case {'sec','Seconds','Sec','seconds'}
                    Time=Time*1;
                case {'minutes','Minutes','min','Min'}
                    Time=Time*60;
                case {'Hours','hours'}
                    Time=Time*3600;
            end
            % timestamp
            Scp.TimeStamp='start_lightexposure';
            
            %set objective
            old_obj = Scp.Objective;
            Scp.Objective = arg.objective;
            
            % decide based on ExcitationPosition which Shutter and Wheel to
            % use, two options are ExcitationWheel, LEDarray
            % get list of labels for ExcitationList
            lst = Scp.mmc.getStateLabels('ExcitationWheel');
            str = lst.toArray;
            PossExcitationWheelPos = cell(numel(str),1);
            for i=1:numel(str)
                PossExcitationWheelPos{i}=char(str(i));
            end
            
            lst = Scp.mmc.getStateLabels('Arduino-Switch');
            str = lst.toArray;
            PossArduinoSwitchPos = cell(numel(str),1);
            for i=1:numel(str)
                PossArduinoSwitchPos{i}=char(str(i));
            end
            
            
            %Dirty but effective. Backwards compatibility.
            %if strcmp(ExcitationPosition,'405');
            %    ExcitationPosition = 'Arduino-405DAC';
            %elseif strcmp(ExcitationPosition,'660');
            %    ExcitationPosition = 'Arduino-660DAC';
            %end
            
            
            if ismember(ExcitationPosition,PossExcitationWheelPos)
                shutter = 'ExcitationShutter';
                wheel = 'ExcitationWheel';
            elseif ismember(ExcitationPosition,PossArduinoSwitchPos)
                shutter = '405LED';
                wheel = 'Arduino-Switch';
            else
                error('Excitation position: %s does not exist in the system',ExcitationPosition)
            end
            %Dyn range
            % 405 1.7:1.8
            % 660 0.92:0.98
            Scp.mmc.setProperty('Core','Shutter',shutter)
            Scp.mmc.setProperty('Dichroics','Label',arg.dichroic)
            Scp.mmc.waitForDevice('Dichroics')
            %added by LNH 1/27/17
            Scp.mmc.setProperty('EmissionWheel','Label',arg.mirrorpos)
            
            if arg.cameraport
                Scp.mmc.setProperty(Scp.DeviceNames.LightPath{1},Scp.DeviceNames.LightPath{2},Scp.DeviceNames.LightPath{4})
            end
            
            if ~isempty(arg.move)
                curr_xy=Scp.XY;
                arg.move=arg.move+repmat(curr_xy,size(arg.move,1),1);
                Scp.XY=arg.move(1,:);
            end
            %
            Scp.mmc.setProperty(wheel,'Label',ExcitationPosition)
            Scp.mmc.setShutterOpen(true);

            
            Tstart=now;
            if isempty(arg.move)
                pause(Time)
            else %deal with stage movment
                % first adjust speed if requested
                
                if ~isempty(arg.stagespeed)
                    currspeed(1) = str2double(Scp.mmc.getProperty(Scp.mmc.getXYStageDevice,'SpeedX'));
                    currspeed(2) = str2double(Scp.mmc.getProperty(Scp.mmc.getXYStageDevice,'SpeedY'));
                    Scp.mmc.setProperty(Scp.mmc.getXYStageDevice,'SpeedX',num2str(arg.stagespeed));
                    Scp.mmc.setProperty(Scp.mmc.getXYStageDevice,'SpeedY',num2str(arg.stagespeed));
                end
                t0=now;
                cnt=0;
                % do first round no matter how time it takes.
                if ~isempty(arg.movetimes)
                    for j=1:arg.movetimes
                        for i=1:size(arg.move,1)
                            Scp.XY=arg.move(i,:);
                        end
                    end
                else
                    while (now-t0)*24*3600<Time % move time to sec
                        cnt=cnt+1;
                        continouscnt=continouscnt+1;
                        if cnt>size(arg.move,1)
                            cnt=1;
                        end
                        Scp.XY=arg.move(cnt,:);
                        cnt %#ok<NOPRT>
                    end
                end
            end
            Scp.mmc.setShutterOpen(false);

            Texpose=(now-Tstart)*24*3600;
            if arg.cameraport
                Scp.mmc.setProperty(Scp.DeviceNames.LightPath{1},Scp.DeviceNames.LightPath{2},Scp.DeviceNames.LightPath{3})
            end
            if ~isempty(arg.move)
                Scp.XY=curr_xy;
                if ~isempty(arg.stagespeed)
                    Scp.mmc.setProperty(Scp.mmc.getXYStageDevice,'SpeedX',num2str(currspeed(1)));
                    Scp.mmc.setProperty(Scp.mmc.getXYStageDevice,'SpeedY',num2str(currspeed(2)));
                end
            end
            Scp.mmc.setProperty('Core','Shutter','ExcitationShutter')
            Scp.Objective = old_obj;  % reset objective to its original position
            Scp.TimeStamp='end_lightexposure';
        end
        
        
        function AcqData = optimizeChannelOrder(Scp,AcqData)
            % TODO: optimizeChannelOrder only optimzes filter wheels - need to add dichroics etc.
            n=length(AcqData);
            stats=nan(n,3); % excitaion, emission, gain
            for i=1:n
                cnf=Scp.mmc.getConfigData('Channel',AcqData(i).Channel);
                vrbs=char(cnf.getVerbose);
                if ~isempty(regexp(vrbs,'Excitation', 'once'))
                    str=vrbs(strfind(vrbs,'Excitation:Label=')+17:end);
                    str=str(1:strfind(str,'<br>')-1);
                    stats(i,1)=Scp.mmc.getStateFromLabel('Excitation',str);
                end
                if ~isempty(regexp(char(vrbs),'Emission', 'once'))
                    str=vrbs(strfind(vrbs,'Emission:Label=')+15:end);
                    str=str(1:strfind(str,'<br>')-1);
                    stats(i,2)=Scp.mmc.getStateFromLabel('Emission',str);
                end
                stats(i,3)=AcqData(i).Gain;
            end
            
            possorders=perms(1:n);
            cst=zeros(factorial(n),1);
            for i=1:size(possorders,1)
                chngs=abs(diff(stats(possorders(i,:),:)));
                chngs(isnan(chngs))=0;
                chngs(chngs(:,3)>0,3)=1;
                cst(i)=sum(chngs(:));
            end
            [~,mi]=min(cst);
            AcqData = AcqData(possorders(mi,:));
        end
        
        function [z,s]=autofocus(Scp)
            %             persistent XY;
            z=nan;
            s=nan;
            switch lower(Scp.AutoFocusType)
                case 'none'
                    disp('No autofocus used');
                case 'nuclei'
                    [Scp.AF,Pos] = Scp.AF.findFocus(Scp);
                    Scp.Pos = Pos;
                case 'hardware'
                    [Scp.AF,Pos] = Scp.AF.findFocus(Scp);
                    Scp.Pos = Pos;
                case 'software'
                    if length(AcqData)~=1
                        error('autofocus can only get a single channel!')
                    end
                    %                     if isfield(AcqData,'ROI')
                    %                         roi=AcqData.ROI;
                    %                     end
                    % set up imaging parameters
                    if ~strcmp(Scp.Channel,AcqData.Channel)
                        Scp.Channel=AcqData.Channel;
                    end
                    Scp.Exposure=AcqData.Exposure;
                    
                    w=Scp.Width;
                    h=Scp.Height;
                    bd=Scp.BitDepth;
                    
                    % define image anlysis parameters
                    hx = fspecial('sobel');
                    hy= fspecial('sobel')';
                    
                    % Z to test on
                    Z0=Scp.Z;
                    Zv=Z0+linspace(-6,6,Scp.autogrid);
                    S=zeros(size(Zv));
                    Tlog=zeros(size(Zv));
                    
                    % open shutter
                    Scp.mmc.setAutoShutter(0)
                    Scp.mmc.setShutterOpen(1)
                    
                    % run a Z scan
                    for i=1:length(Zv)
                        tic
                        Scp.Z=Zv(i);
                        Scp.mmc.snapImage;
                        imgtmp=Scp.mmc.getImage;
                        img=reshape(single(imgtmp)./(2^bd),w,h)';
                        gx=imfilter(img,hx);
                        gy=imfilter(img,hy);
                        S(i)=mean(hypot(gx(:),gy(:)));
                        Tlog(i)=now;
                    end
                    % close shutter
                    Scp.mmc.setShutterOpen(0)
                    Scp.mmc.setAutoShutter(1)
                    
                    f=@(p,x) exp(-(x-p(1)).^2./2/p(2).^2);
                    p0=[Z0 1.5];
                    opt=optimset('Display','off');
                    p=lsqcurvefit(f,p0,Zv,mat2gray(S),[min(Zv) 0.5],[max(Zv) 2.5],opt);
                    z=p(1);
                    s=interp1(Zv,S,z);
                    
                    % clear ROI if it was used
                    Scp.mmc.clearROI;
                    
                    Scp.AFscr=S;
                    Scp.AFgrid=Zv;
                    
                    % move to the new Z
                    Scp.Z=z;
                    
                    
                    % update the log
                    Scp.AFlog.Z=[Scp.AFlog.Z(:); Zv(:)];
                    Scp.AFlog.Time=[Scp.AFlog.Time(:); Tlog(:)];
                    Scp.AFlog.Score=[Scp.AFlog.Score(:); S(:)];
                    Scp.AFlog.Type=[Scp.AFlog.Type; repmat({'Scan'},length(Zv),1)];
                    Scp.AFlog.Channel=[Scp.AFlog.Channel; repmat({AcqData.Channel},length(Zv),1)];
                otherwise
                    error('Please define type of autofocus (as None if none exist)')
            end
            
        end
        
        function Mag = getOptovar(Scp)
            % if Optovar is set - return it's value. 
            if ~isempty(Scp.OptovarStatus)
                Mag = Scp.OptovarStatus; 
                return
            end
            
            % if we are here, optovar status is unknown
            try
                readout = Scp.mmc.getProperty('Optovar','DigitalInput');
                readout = str2double(char(readout));
                if readout == 1
                    Mag = 1.5;
                elseif readout == 0
                    Mag = 1;
                end
            catch % if error get user input on Optovar
                button = questdlg('What is the optovar position?','set optovar','1','1.5','1');  
                Mag = str2double(button); 
            end
            Scp.OptovarStatus=Mag; 
        end
        
        function GUIPFS(Scp)
            %%
            figure(468)
            set(468,'position',[400 600 300 50],'toolbar','none','dockcontrol','off','menubar','none','Name','AutoFocus','NumberTitle','off');
            sliderpos=str2double(Scp.mmc.getProperty('TIPFSOffset','Position'));
            h = uicontrol(468,'Style','slider','Min',0,'Max',1000,'Units','normalized','Value',sliderpos,'Position',[0 0 1 1],'SliderStep',[0.0001 0.001]);
            addlistener(h,'Value','PostSet',@slidercallback);
            
            function slidercallback(~,~)
                sliderpos = get(h,'Value');
                Scp.mmc.setProperty('TIPFSOffset','Position',num2str(sliderpos))
            end
            
        end
        
%         function img = snapImage(Scp)
%             img = snapImage@Scope(Scp);
%             img = flipud(img);
%             img = fliplr(img);
%         end

    end
end