classdef ZincuScope < Scope
    
    properties
        OptovarStatus=[];
        Stepsize = 2;
    end
    
    methods
        
        function PixelSize = getPixelSize(Scp)
            %PixelSize = Scp.mmc.getPixelSizeUm;
            CamPixSize = 3.45;
            PixelSize = CamPixSize/Scp.getOptovar;
        end
        
        
        function Mag = getOptovar(Scp)
            Mag=10;
            Mag=Mag*0.63;
        end
        
        
        
        function setObjective(Scp,Objective)
            
            % get full name of objective from shortcut
            avaliableObj = Scp.java2cell(Scp.mmc.getAllowedPropertyValues(Scp.DeviceNames.Objective,'Label'));
            % only consider Dry objectives for Scp.set.Objective
            objIx = cellfun(@(f) ~isempty(regexp(f,Objective, 'once')),avaliableObj) & cellfun(@(m) isempty(m),strfind(avaliableObj,'OIL'));
            if nnz(objIx)~=1
                error('Objective %s not found or not unique',Objective);
            end
            Objective = avaliableObj(objIx);
            % if requesting current objective just return
            if strcmp(Objective, Scp.Objective)
                return
            end
            
            if ~isempty(regexp(Objective{1}, '20X', 'once'))
                uiwait(msgbox({'Please make sure stage is not in edges before proceeding.' '' 'If using 96 well format, avoid edges.'}));
            end
            
            Scp.mmc.setProperty(Scp.DeviceNames.Objective,'Label',Objective);
            Scp.mmc.waitForSystem;

        end
        
        
        
        
        
        
                
        function setXY(Scp,XY)
            currXY = Scp.XY;
            dist = sqrt(sum((currXY(:)-XY(:)).^2));
            if Scp.XYpercision >0 && dist < Scp.XYpercision
                fprintf('movment too small - skipping XY movement\n');
                return
            end
            XY = XY./Scp.Stepsize;
            Scp.mmc.setXYPosition(Scp.mmc.getXYStageDevice,XY(1),XY(2))
            Scp.mmc.waitForDevice(Scp.mmc.getProperty('Core','XYStage'));
        end
        
        
        function setX(Scp,X)
            Scp.mmc.setXYPosition(Scp.mmc.getXYStageDevice,X./Scp.Stepsize, Scp.Y./Scp.Stepsize)
            Scp.mmc.waitForDevice(Scp.mmc.getProperty('Core','XYStage'));
        end
        function setY(Scp,Y)
            Scp.mmc.setXYPosition(Scp.mmc.getXYStageDevice,Scp.X./Scp.Stepsize,Y./Scp.Stepsize)
            Scp.mmc.waitForDevice(Scp.mmc.getProperty('Core','XYStage'));
        end
        
        
        function X=getX(Scp)
            X=Scp.mmc.getXPosition(Scp.mmc.getXYStageDevice).*Scp.Stepsize;
        end
        
        function Y=getY(Scp)
            Y=Scp.mmc.getYPosition(Scp.mmc.getXYStageDevice).*Scp.Stepsize;
        end
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        function Zfocus = ImageBasedFocusHillClimb(Scp,varargin)
            %Works pretty well with BF:
            %Scp.ImageBasedFocusHillClimb('channel','Brightfield','exposure',20,'resize',0.25,'scale',50)
            %Works really well with Hoescht:
            %Scp.ImageBasedFocusHillClimb('channel','Brightfield','exposure',20,'resize',0.25,'scale',50)
            
            arg.scale = 2; % if True will acq multiple channels per Z movement.
            arg.resize =1;
            arg.channel = 'DeepBlue'; % if True will acq multiple channels per Z movement.
            arg.exposure =10;
            % False will acq a Z stack per color.
            arg = parseVarargin(varargin,arg);
            %% Set channels and exposure
            Scp.Channel=arg.channel;
            Scp.Exposure=arg.exposure;
            
            Zs = [];
            Conts = [];
            
            figure(157),
            set(157,'menubar','none','Name','Finding focus by contrast','NumberTitle','off')
            
            clf
            
            Zinit = Scp.Z;
            dZ = 50;
            sgn = 1;
            acc = 50^(1/5);
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
            
            Scp.goto(Scp.Pos.Labels{1}, Scp.Pos)
            figure(445)
            set(445,'Windowstyle','normal','toolbar','none','menubar','none','Position',[700 892 300 75],'Name','Please find focus in first well','NumberTitle','off')
            uicontrol(445,'Style', 'pushbutton', 'String','Done','Position',[50 20 200 35],'fontsize',13,'callback',@(~,~) close(445))
            uiwait(445)
            Scp.Pos.List(:,3) = Scp.Z;
            ManualZ = Scp.Z;
            for i=1:Scp.Pos.N
                Scp.goto(Scp.Pos.Labels{i}, Scp.Pos)
                Zfocus = Scp.ImageBasedFocusHillClimb(varargin{:});
                if i==1
                    dZ = ManualZ-Zfocus;%difference bw what I call focus and what Mr. computer man thinks.
                end
                Scp.Pos.List(i,3) = Zfocus+dZ;
            end
        end
        

        
   
        
    end
end