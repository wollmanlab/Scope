classdef NinjaScope < Scope
   
    properties
       LaserVoltage = struct('name',{},'minV',[],'maxV',[]);
       OptovarStatus=[]; 
    end
    
    methods
        function Texpose = lightExposure(Scp,ExcitationPosition,Time,varargin)
            arg.units = 'seconds';
            arg.dichroic = '425LP';
            arg.shutter = 'ExcitationShutter';
            arg.cameraport = false;
            arg.stagespeed = [];
            arg.mirrorpos = 'mirror'; %added by naomi 1/27/17
            arg.move=[]; % array of nx2 of position to move between in circular fashion. relative to current position in um
            arg.movetimes = [];
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
            
            PossDACdevices = {'Arduino-405DAC', 'Arduino-660DAC'};
            %TODO read these automagically from MM (or not...)
            
            %Dirty but effective. Backwards compatibility.
            if strcmp(ExcitationPosition,'405');
                ExcitationPosition = 'Arduino-405DAC';
            elseif strcmp(ExcitationPosition,'660');
                ExcitationPosition = 'Arduino-660DAC';
            end
            
            
            if ismember(ExcitationPosition,PossExcitationWheelPos)
                shutter = 'ExcitationShutter';
                wheel = 'ExcitationWheel';
                isDAC = false;
            elseif ismember(ExcitationPosition,PossArduinoSwitchPos)
                shutter = '405LED';
                wheel = 'Arduino-Switch';
                isDAC = false;
            elseif ismember(ExcitationPosition,PossDACdevices)
                shutter = '405LED';
                wheel = ExcitationPosition;
                isDAC = true;
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
            if ~isDAC
                Scp.mmc.setProperty(wheel,'Label',ExcitationPosition)
                Scp.mmc.setShutterOpen(true);
            else
                % find which laser we are in
                %                     Vrange = nan(2,1);
                %                     Vrange(1)=Scp.LaserVoltage(ismember({Scp.LaserVoltage.name},ExcitationPosition)).minV;
                %                     Vrange(2)=Scp.LaserVoltage(ismember({Scp.LaserVoltage.name},ExcitationPosition)).maxV;
                %                     power = arg.power*range(Vrange)/100+Vrange(1);
                
                y = Scp.LaserVoltage(ismember({Scp.LaserVoltage.name},ExcitationPosition)).y;
                x = Scp.LaserVoltage(ismember({Scp.LaserVoltage.name},ExcitationPosition)).x;
                power = min(interp1(y,x,arg.power,[],'extrap'),5);
                
                Scp.mmc.setProperty(ExcitationPosition,'Volts',power)
            end
            
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
            if ~isDAC
                Scp.mmc.setShutterOpen(false);
            else
                Scp.mmc.setProperty(ExcitationPosition,'Volts',0);
            end
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
                case 'hardware'
                    %                     currXY=Scp.XY;
                    %                     if isempty(XY)
                    %                         XY = currXY;
                    %                     elseif sqrt((XY(1)-currXY(1))^2+(XY(2)-currXY(2))^2)<100
                    %                         return;
                    %                     end
                    Scp.mmc.enableContinuousFocus(true);
                    t0=now;
                    while ~Scp.mmc.isContinuousFocusLocked && (now-t0)*24*3600 < Scp.autofocusTimeout
                        pause(Scp.autofocusTimeout/1000)
                    end
                    if (now-t0)*24*3600 > Scp.autofocusTimeout
                        msgbox('Out of Focus ! watch out!!!');
                    end
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
        
        
    end
end