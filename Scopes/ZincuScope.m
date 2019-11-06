classdef ZincuScope < Scope
    
    properties
        OptovarStatus=[];
        Stepsize = 2;
        Mishor;
    end
    
    methods
        
        function PixelSize = getPixelSize(Scp)
            %PixelSize = Scp.mmc.getPixelSizeUm;
            CamPixSize = 3.45;
            PixelSize = CamPixSize/Scp.getOptovar;
        end
        
        
        function Mag = getOptovar(Scp)
            %regexp(Scp.Objective,'X')
            Mag=str2double(Scp.Objective(1:regexp(Scp.Objective,'X')-1));
            Mag=Mag*0.63;
        end
        
        function goto(Scp,label,Pos,varargin)
            arg.plot = true;
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
             err = goto@Scope(Scp,label,Pos,varargin);
%             if err
%                 warning('resetting stage')
%                 Scp.mmc.setProperty('Focus','Load Position',1);
%                 
%                 Scp.mmc.setSerialPortCommand('COM1', 'REMRES', '\r');
%                 pause(15)
%                 Scp.mmc.setProperty('XYStage','Speed',20000);
%                 Scp.mmc.setProperty('XYStage','Acceleration',2);
%                 Scp.mmc.setSerialPortCommand('COM1', 'HOME X', '\r');
%                 Scp.X;
%                 pause(5)
%                 
%                 Scp.mmc.setSerialPortCommand('COM1', 'HOME Y', '\r');
%                 Scp.Y;
%                 pause(5)
%                 Scp.Chamber.x0y0 = Scp.XY+[13326       10550];
%                 Scp.Chamber.directionXY = [1 1];
%                 
%                 Scp.goto(label,Pos,varargin)
%                 Scp.mmc.setProperty('Focus','Load Position',0);
% 
%             end
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
     
        function [z,s]=autofocus(Scp)
            z=nan;
            s=nan;
            switch lower(Scp.AutoFocusType)
                case 'none'
                    disp('No autofocus used');
                case 'plane'
                    if isempty(Scp.Mishor)
                        error('Plane has not been initialized.');
                    end
                    zOffset = Scp.Pos.getzOffset;
                    z = Scp.Mishor.Zpredict(Scp.XY)+zOffset;
                    Scp.Z = z;
                    fprintf('I autofocused! moved to %.2f \n',z);
                case 'hardware'
                    warning('There`s no hardware AF here, yet.');
                    %Scp.studio.autofocusNow();
                case 'software'
                    if isa(Scp.Mishor,'MishorAutofocus')
                        zPred = Scp.Mishor.Zpredict(Scp.XY);
                        Scp.Z = zPred;
                    end
                    z = Scp.ImageBasedFocusHillClimb;
                    Scp.Z=z;
                    fprintf('I software autofocused! moved to %.2f \n',z);
                otherwise
                    error('Please define type of autofocus (as None if none exist)')
            end
            
        end
   
        function ZDriveGUI(Scp)
            %%
            figure(468)
            clf;
            set(468,'position',[400 600 50 300],'color','w','toolbar','none','dockcontrol','off','menubar','none','Name','Z','NumberTitle','off');
            sliderpos=str2double(Scp.mmc.getProperty('Focus','Position'));
            h = uicontrol(468,'Style','slider','Min',-10000,'Max',5000,'Units','normalized','String','Z','Value',sliderpos,'Position',[0.35 0 0.65 1],'SliderStep',[5/15000 50/15000]);
            addlistener(h,'Value','PostSet',@slidercallback);
            h.BackgroundColor='w'; 
            
            %gui updater
            T = timer('Period',1,'StartDelay',0,'TimerFcn',@(src,evt)set(h,'Value',str2double(Scp.mmc.getProperty('Focus','Position'))),...
             'ExecutionMode','FixedRate');
            start(T)
            
            
            annotation('textbox', [0, 0.6, 0, 0], 'string', 'Z')
            function slidercallback(~,~)
                sliderpos = get(h,'Value');
                Scp.mmc.setProperty('Focus','Position',num2str(sliderpos))
            end

        end
        
        function changePlateRoutine(Scp,PlateName,x0y0)
            Scp.Chamber = Plate(PlateName);

            Scp.mmc.setProperty('Focus','Load Position',1);
            Scp.mmc.setSerialPortCommand('COM1', 'HOME X', '\r');
            Scp.X;
            pause(5)

            Scp.mmc.setSerialPortCommand('COM1', 'HOME Y', '\r');
            Scp.Y;
            pause(5)
            Scp.Chamber.x0y0 = Scp.XY+x0y0;
            Scp.Chamber.directionXY = [1 1];
            Scp.reduceAllOverheadForSpeed=true;
            Scp.mmc.setProperty('Focus','Load Position',0);
        end
        
    end
end