classdef RamboScope < Scope
    % Subclass of Scope that makes certain behavior specific to the
    % zeiss scope.
    
    properties
        AF = TheseusFocus; 
        Notifications = Notifications;
        TempHumiditySensor = DHT11('COM14'); %FIX
        FlowData = FluidicsData;
        X_stage_max_limit = 55000;
        X_stage_min_limit = -55000;
        Y_stage_max_limit = 37500;
        Y_stage_min_limit = -37500;
        X_offset = -67000; % Distance of Scp.X=0 from center of stage
        Y_offset = -43000; % Distance of Scp.Y=0 from center of stage
    end
    
    
    methods
        
        function Scp = RamboScope()
            Scp@Scope; 
            disp('My name is Rambo and I am a microscope. ')
            Scp.FlowData.device = 'RamboFluidics';
            addpath('C:\Program Files\Micro-Manager-2.0gamma')
            Scp.studio = StartMMStudio('C:\Program Files\Micro-Manager-2.0gamma');
            Scp.mmc = Scp.studio.getCMMCore;
            Scp.mmc.setChannelGroup('Channel');
            Scp.LiveWindow = Scp.studio.live;
            Scp.ScopeName = 'Zeiss_Axio_0';
            import org.micromanager.navigation.*
            import org.micromanager.*;
            import mmcorej.*;
            Scp.CameraName = 'Camera';
            %% Scope-startup - runs Nikon-Epi specific configurations
            Scp.basePath = 'D:\Images';
            %% some propeties require knowing the name of the device
            Scp.DeviceNames.Objective = 'ZeissObjectiveTurret';
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
        
        function [z,s] = autofocus(Scp)
            z=nan;
            s=nan;
            switch lower(Scp.AutoFocusType)
                case 'nuclei'
                    Scp.AF = Scp.AF.findFocus(Scp);
                case 'theseus'
                    Scp.AF = Scp.AF.findFocus(Scp);
                case 'relative'
                    RelativeAutoFocus(Scp);
                case 'hardware'
                    Scp.AF = Scp.AF.findFocus(Scp);
                case 'none'
                    disp('No autofocus used')
            end
        end
    end
    
    
    
end
