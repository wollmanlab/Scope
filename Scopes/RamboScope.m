classdef RamboScope < Scope
    properties
        Notifications = Notifications;
%         TempHumiditySensor = DHT11('COM9');
    end
    
    %% Methods
    methods
        function Scp = RamboScope()
            Scp@Scope();
            import mmcorej.*;
            import org.micromanager.*;
            Scp.studio = StartMMStudio('C:\Program Files\Micro-Manager-2.0gamma');
            Scp.mmc = Scp.studio.getCMMCore;
            Scp.ErrorLogPth='C:\GitRepos\Scope\ErrorLogs';
            disp('My name is Rambo and I am a microscope. ')
            Scp.basePath = 'D:/Images';Scp.ScopeName = 'Rambo';
            Scp.mmc.setChannelGroup('Channel');
            Scp.CameraName = 'Camera';
            Scp.mmc.setProperty(Scp.CameraName,'Gain-AutoOrManual','Manual');
            Scp.mmc.setProperty(Scp.CameraName,'Gain(dB)','4');
            Scp.Chamber = Plate('Underwood6');
            Scp.Chamber.x0y0 = [ 0 0];
            Scp.Chamber.directionXY = [-1 1];
            Scp.AutoFocusType = 'Hardware';
            %% Flatfield
            Scp.FlatFieldsFileName='D:\Images\FlatFieldCorrections\Flatfield.mat';
            Miji;
        end
        
      function [z,s]=autofocus(Scp)
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
                otherwise
                    error('Please define type of autofocus (as None if none exist)')
            end
            
        end
    end
end