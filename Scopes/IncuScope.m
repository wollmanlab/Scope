classdef IncuScope < Scope
    % Version 0.2
    % Generalization of the Scope class to allow reusing code on muliple scopes
    % Created by Roy Wollman - 10/17/12
    
    
    properties
        SHT15port = serial('COM10','baudrate',9600);
        ASI = ASIcontroller;
        DichroicsPerChannel;
        Mishor;
    end
    
    %% Methods
    methods
        function Objective = getObjective(Scp)
            Objective = '10X 0.45NA';
        end
        
        function PixelSize = getPixelSize(Scp)
            %PixelSize = Scp.mmc.getPixelSizeUm;
            Mag = 8;
            CamPixSize = 3.45;
            BinnningFactor = str2double(Scp.mmc.getProperty(Scp.CameraName,'Binning'));
            PixelSize = BinnningFactor*CamPixSize/Mag;
        end
        
        function Mag = getOptovar(Scp)
            %regexp(Scp.Objective,'X')
            Mag=str2double(Scp.Objective(1:regexp(Scp.Objective,'X')-1));
            Mag=Mag*0.8;
        end
    
        
        function setChannel(Scp,chnl)
            Scp.initTempHumSenor;
            if strcmp(chnl,'Brightfield')
                % do this
                Scp.mmc.setProperty('Core','AutoShutter', '0')
                Scp.mmc.setProperty('ExShutter','State', '0')
                fwrite(Scp.SHT15port,'bright ,100')
            else
                % make sure brightfield if off
                Scp.mmc.setProperty('Core','AutoShutter', '1')
                fwrite(Scp.SHT15port,'bright ,0')
            end
            % figure out what dichroic we need and move there.
            %Scp.ASI.moveASI('F',Scp.DichroicsPerChannel.(chnl));
            
            % set Em/Ex using MM
            setChannel@Scope(Scp,chnl)
            
        end
        
        function ChannelsWindow(Scp)
            figure(417)
            set(417,'Windowstyle','normal','toolbar','none','menubar','none','Position',[863 892 250 75],'Name','Channels','NumberTitle','off')
            %uicontrol(469,'Style', 'pushbutton', 'String','Done','Position',[20 20 100 35],'fontsize',13,'callback',@(~,~) close(469))
            uicontrol(417,'Style','popup','String',Scp.getPossibleChannels,'Position',[50 0 150 50],'fontsize',13,'callback',@(source,~) Scp.setChannel(source.String{source.Value}));
        end
        
        function [Tout,Hout]=getTempAndHumidity(Scp)
            Scp.initTempHumSenor;
            fwrite(Scp.SHT15port,'printth')
            tline = fgetl(Scp.SHT15port);
            prts =regexp(tline,'/','split');
            Tout=str2double(prts{1});
            Hout=str2double(prts{2});
            Scp.TempLog=[Scp.TempLog; now Tout];
            % update logs
            Scp.HumidityLog=[Scp.HumidityLog; now Hout];
        end
        
        function initTempHumSenor(Scp)
            if strcmp(get(Scp.SHT15port,'status'),'closed')
                fopen(Scp.SHT15port);
            end
        end
        
        %             % XY axis are fli
        function setX(Scp,X)
            %                 Scp.ASI.moveASI('Y',X);
            Scp.mmc.setXYPosition(Scp.mmc.getXYStageDevice,Scp.Y,X)
            Scp.mmc.waitForDevice(Scp.mmc.getProperty('Core','XYStage'));
        end
        %
        function setY(Scp,Y)
            %                 Scp.ASI.moveASI('X',Y);
            Scp.mmc.setXYPosition(Scp.mmc.getXYStageDevice,Y,Scp.X)
            Scp.mmc.waitForDevice(Scp.mmc.getProperty('Core','XYStage'));
        end
        %
        %              function setZ(Scp,Z)
        % %                 Scp.ASI.moveASI('Z',Z);
        %                  Scp.mmc.setXYPosition(Scp.mmc.getXYStageDevice,Y,Scp.X)
        %                  Scp.mmc.waitForDevice(Scp.mmc.getProperty('Core','XYStage'));
        %              end
        %
        function X=getX(Scp)
            %                 X = Scp.ASI.whereAmI('Y');
            X=Scp.mmc.getYPosition(Scp.mmc.getXYStageDevice);
            %
        end
        function Y=getY(Scp)
            Y=Scp.mmc.getXPosition(Scp.mmc.getXYStageDevice);
            %                  Y = Scp.ASI.whereAmI('X');
        end
        %
        %             function Z=getZ(Scp)
        %                 %Y=Scp.mmc.getXPosition(Scp.mmc.getXYStageDevice);
        %                 Z = Scp.ASI.whereAmI('Z');
        %             end
        %
        function setXY(Scp,XY)
            currXY = Scp.XY;
            dist = sqrt(sum((currXY-XY).^2));
            if Scp.XYpercision >0 && dist < Scp.XYpercision
                fprintf('movment too small - skipping XY movement\n');
                return
            end
            %                 Scp.ASI.moveASI('XY',XY([2,1]));
            %                 %Scp.setX(XY(1));
            %                 %Scp.setY(XY(2));
            Scp.mmc.setXYPosition(Scp.mmc.getXYStageDevice,XY(2),XY(1))
            Scp.mmc.waitForDevice(Scp.mmc.getProperty('Core','XYStage'));
        end
        
        function logError(Scp,msg,varargin)
            Scp.DieOnError=false;
            logError@Scope(Scp,msg)
            Scp.resetASI;
        end
        
        
        function fltname = getFlatFieldName(Scp)
            fltname=Scp.Channel;
        end
        
        
        function [z,s]=autofocus(Scp)
            z=nan;
            s=nan;
            switch lower(Scp.AutoFocusType)
                case 'none'
                    disp('No autofocus used');
                case 'hardware'
                    disp('autofocus using crisp');
                    Scp.studio.autofocusNow();
                case 'plane'
                    if isempty(Scp.Mishor)
                        error('Plane has not been initialized.');
                    end
                    zOffset = Scp.Pos.getzOffset;
                    z = Scp.Mishor.Zpredict(Scp.XY)+zOffset;
                    Scp.Z = z;
                    fprintf('I autofocused! moved to %.2f \n',z);
                case 'software'
                    Zfocus = Scp.ImageBasedFocusHillClimb('channel',AcqData.Channel,'exposure',AcqData.Exposure);
                    Scp.Z=Zfocus;
                otherwise
                    error('Please define type of autofocus (as None if none exist)')
            end
            
        end
        
        %             function Zfocus = ImageBasedFocusHillClimb(Scp,varargin)
        %                 %Works pretty well with BF:
        %                 %Scp.ImageBasedFocusHillClimb('channel','Brightfield','exposure',20,'resize',0.25,'scale',50)
        %                 %Works really well with Hoescht:
        %                 %Scp.ImageBasedFocusHillClimb('channel','Brightfield','exposure',20,'resize',0.25,'scale',50)
        %
        %                 arg.scale = Scp.AFparam.scale; % if True will acq multiple channels per Z movement.
        %                 arg.resize =Scp.AFparam.resize;
        %                 arg.channel = Scp.AFparam.channel; % if True will acq multiple channels per Z movement.
        %                 arg.exposure =Scp.AFparam.exposure;
        %                 % False will acq a Z stack per color.
        %                 arg = parseVarargin(varargin,arg);
        %                 %% Set channels and exposure
        %                 Scp.Channel=arg.channel;
        %                 Scp.Exposure=arg.exposure;
        %
        %
        %                 figure(157),
        %                 set(157,'menubar','none','Name','Finding focus by contrast','NumberTitle','off')
        %
        %                 clf
        %
        %                 Zinit = Scp.Z;
        %                 dZ = 50;
        %                 sgn = 1;
        %                 acc = 50^(1/5);
        %                 cont1=Scp.Contrast('scale',arg.scale,'resize',arg.resize);  %measure of contrast
        %                 plot(Scp.Z,cont1,'o')
        %                 hold all
        %
        %                 %determine direction of motion
        %
        %                 Scp.Z = Scp.Z+sgn*dZ;
        %                 cont2=Scp.Contrast('scale',arg.scale,'resize',arg.resize);
        %                 plot(Scp.Z,cont2,'o')
        %
        %                 if cont2<cont1
        %                     sgn = -sgn;
        %                     Scp.Z = Scp.Z+2*sgn*dZ;
        %                     cont2=Scp.Contrast('scale',arg.scale,'resize',arg.resize);
        %                     set(157,'menubar','none','Name','Finding focus by contrast','NumberTitle','off')
        %                     plot(Scp.Z,cont2,'o');
        %                     if cont2<cont1
        %                         dZ=dZ/(acc^2);
        %                         Scp.Z = Zinit;%start over with smaller region
        %                         cont1=Scp.Contrast('scale',arg.scale,'resize',arg.resize);  %measure of contrast
        %
        %                         Scp.Z = Scp.Z+sgn*dZ;
        %                         cont2=Scp.Contrast('scale',arg.scale,'resize',arg.resize);
        %                         plot(Scp.Z,cont2,'o')
        %                         if cont2<cont1
        %                             sgn = -sgn;
        %                             Scp.Z = Scp.Z+2*sgn*dZ;
        %                             cont2=Scp.Contrast('scale',arg.scale,'resize',arg.resize);
        %                             plot(Scp.Z,cont2,'o');
        %                         end
        %                         %sgn = -sgn;
        %                     end
        %                 end
        %
        %                 while dZ>1
        %                     while cont2>=cont1
        %                         cont1=cont2;
        %                         Scp.Z = Scp.Z+sgn*dZ;
        %                         cont2=Scp.Contrast('scale',arg.scale,'resize',arg.resize);
        %                         figure(157);
        %                         plot(Scp.Z,cont2,'o')
        %                     end
        %                     dZ = dZ/acc;
        %                     sgn=-sgn;
        %                     cont1=cont2;
        %                 end
        %                 Zfocus = Scp.Z+sgn*dZ*acc;
        %                 Scp.Z = Zinit;
        %             end
        %
        %
        %
        %
        %             function cont = Contrast(Scp,varargin)
        %                 arg.scale = 2; % if True will acq multiple channels per Z movement.
        %                 arg.resize =1;
        %                 % False will acq a Z stack per color.
        %                 arg = parseVarargin(varargin,arg);
        %                 img=imresize(Scp.snapImage, arg.resize);
        %                 m=img-imgaussfilt(img,arg.scale);
        %                 m = m(200:end,200:end);
        %                 rng=prctile(m(:),[1 99]);
        %                 cont=rng(2)-rng(1);
        %             end
        %
        %             function focusAdjust(Scp,varargin)
        %                 arg.Diff = 0;
        %                 arg.scale = 2; % if True will acq multiple channels per Z movement.
        %                 arg.resize =1;
        %                 arg.channel = 'DeepBlue'; % if True will acq multiple channels per Z movement.
        %                 arg.exposure =10;
        %                 arg = parseVarargin(varargin,arg);
        %
        %                Scp.goto(Scp.Pos.Labels{1}, Scp.Pos)
        %                Zfocus = Scp.ImageBasedFocusHillClimb(varargin{:});
        %
        %                dZ = Zfocus-Scp.Z+arg.Diff;
        %                Scp.Pos.List(:,3) = Scp.Pos.List(:,3)+dZ;
        %             end
        %
        %             function dZ = findInitialFocus(Scp,varargin)
        %                 arg.scale = 2; % if True will acq multiple channels per Z movement.
        %                 arg.resize =1;
        %                 arg.channel = 'DeepBlue'; % if True will acq multiple channels per Z movement.
        %                 arg.exposure =20;
        %
        %                 arg = parseVarargin(varargin,arg);
        %
        %                 Scp.goto(Scp.Pos.Labels{1}, Scp.Pos)
        %                 figure(445)
        %                 set(445,'Windowstyle','normal','toolbar','none','menubar','none','Position',[700 892 300 75],'Name','Please find focus in first well','NumberTitle','off')
        %                 uicontrol(445,'Style', 'pushbutton', 'String','Done','Position',[50 20 200 35],'fontsize',13,'callback',@(~,~) close(445))
        %                 uiwait(445)
        %                 Scp.Pos.List(:,3) = Scp.Z;
        %                 ManualZ = Scp.Z;
        %                 for i=1:Scp.Pos.N
        %                     Scp.goto(Scp.Pos.Labels{i}, Scp.Pos)
        %                     Zfocus = Scp.ImageBasedFocusHillClimb(varargin{:});
        %                     if i==1
        %                         dZ = ManualZ-Zfocus;%difference bw what I call focus and what Mr. computer man thinks.
        %                     end
        %                     Scp.Pos.List(i,3) = Zfocus+dZ;
        %                 end
        %             end
        %
        
    end
end
