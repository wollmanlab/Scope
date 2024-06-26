classdef PurpleScope < Scope
    % Subclass of Scope that makes certain behavior specific to the
    % zeiss scope.
    
    properties
        AF = ContrastPlaneFocus; 
        Notifications = Notifications;
        TempHumiditySensor = DHT11('COM7'); %FIX
        FlowData = FluidicsData;
        X_stage_max_limit = 57500;
        X_stage_min_limit = -54000;
        Y_stage_max_limit = 24000;
        Y_stage_min_limit = -60000;
        X_offset = 1000; % Distance of Scp.X=0 from center of stage
        Y_offset = -5000;%-12000; % Distance of Scp.Y=0 from center of stage
        directionXY = [-1,1]; % double check
    end
    
    
    methods
        
        function Scp = PurpleScope()
            Scp@Scope; 
            Scp.dXY = [Scp.X_offset Scp.Y_offset];
            disp('My name is Purple and I am a microscope. ')
            Scp.FlowData.device = 'PurpleFluidics';
            Scp.FlowData.python = 'C:\Users\wollmanlab\.conda\envs\py37\python';
            addpath('C:\Program Files\Micro-Manager-2.0gamma')
            Scp.studio = StartMMStudio('C:\Program Files\Micro-Manager-2.0gamma');
            Scp.mmc = Scp.studio.getCMMCore;
            Scp.mmc.setChannelGroup('Channel');
            Scp.LiveWindow = Scp.studio.live;
            Scp.ScopeName = 'PurpleScope';
            import org.micromanager.navigation.*
            import org.micromanager.*;
            import mmcorej.*;
            Scp.CameraName = 'Camera';
            %% Scope-startup - runs Nikon-Epi specific configurations
            Scp.basePath = 'D:\Images';
            %%
            %% Autofocus method
            Scp.CorrectFlatField = false; 
            Scp.Chamber = Plate('Coverslip');
            Scp.Chamber.x0y0 = [0 0]; 
            Scp.mmc.setProperty(Scp.CameraName,'Gain-AutoOrManual','Manual');
            Scp.mmc.setProperty(Scp.CameraName,'Gain(dB)','4');
            Scp.Zpercision = 0.5;
            Scp.reduceAllOverheadForSpeed = 1;
            Scp.AutoFocusType='none';
            Scp.acqshow = 'single';
            Miji;
            %%% java.lang.System.gc()
            
        end
        function PixelSize = getPixelSize(Scp)
            PixelSize = (0.49/1.5)/0.8;%Scp.mmc.getPixelSizeUm;
%             if Scp.Optovar==1
%                 PixelSize = PixelSize/0.7;
%             end
        end
        
        function [z,s] = autofocus(Scp)
            z=nan;
            s=nan;
            switch lower(Scp.AutoFocusType)
                case 'nuclei'
                    Scp.AF = Scp.AF.findFocus(Scp);
                case 'relative'
                    RelativeAutoFocus(Scp);
                case 'hardware'
                    Scp.AF = Scp.AF.findFocus(Scp);
                case 'none'
                    disp('No autofocus used')
            end
        end
        
        function img = microscope_correct_image(Scp,img)
            img = flip(img,2);
        end

    end
end
