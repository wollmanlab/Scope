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
                    z = Scp.ImageBasedFocusHillClimb('channel',AcqData.Channel,'exposure',AcqData.Exposure);
                    Scp.Z=z;
                otherwise
                    error('Please define type of autofocus (as None if none exist)')
            end
            
        end
   
        
    end
end