classdef IncuScope < Scope
    % Version 0.2
    % Generalization of the Scope class to allow reusing code on muliple scopes
    % Created by Roy Wollman - 10/17/12
    
    
    properties 
        SHT15port = serial('COM10','baudrate',9600);
        ASI = ASIcontroller; 
        DichroicsPerChannel;
    end    
    
    %% Methods 
            methods
            function Objective = getObjective(Scp)
                Objective = 'You Guys miss Yanfei, yet?, yes we do....';
            end
            
            function PixelSize = getPixelSize(Scp)
                %PixelSize = Scp.mmc.getPixelSizeUm;
                Mag = 5.1;
                CamPixSize = 3.45;
                PixelSize = CamPixSize/Mag;
            end
            
            
            function Mag = getOptovar(Scp)
                Mag = 1;
            end
            
            function setChannel(Scp,chnl)
                Scp.initTempHumSenor;
                if strcmp(chnl,'Brightfield')
                    % do this
                    fwrite(Scp.SHT15port,'bright ,2')
                else
                    % make sure brightfield if off
                    fwrite(Scp.SHT15port,'bright ,0')
                end
                % figure out what dichroic we need and move there. 
                Scp.ASI.moveASI('F',Scp.DichroicsPerChannel.(chnl)); 
                
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
            
            % XY axis are fli
            function setX(Scp,X)
                Scp.ASI.moveASI('Y',X); 
%                 Scp.mmc.setXYPosition(Scp.mmc.getXYStageDevice,Scp.Y,X)
%                 Scp.mmc.waitForDevice(Scp.mmc.getProperty('Core','XYStage')); 
            end
            
            function setY(Scp,Y)
                Scp.ASI.moveASI('X',Y); 
%                 Scp.mmc.setXYPosition(Scp.mmc.getXYStageDevice,Y,Scp.X)
%                 Scp.mmc.waitForDevice(Scp.mmc.getProperty('Core','XYStage')); 
            end
            
            function setZ(Scp,Z)
                Scp.ASI.moveASI('Z',Z); 
%                 Scp.mmc.setXYPosition(Scp.mmc.getXYStageDevice,Y,Scp.X)
%                 Scp.mmc.waitForDevice(Scp.mmc.getProperty('Core','XYStage')); 
            end
            
            function X=getX(Scp)
                X = Scp.ASI.whereAmI('Y'); 
                 %X=Scp.mmc.getYPosition(Scp.mmc.getXYStageDevice);
                 
            end
            function Y=getY(Scp)
                 %Y=Scp.mmc.getXPosition(Scp.mmc.getXYStageDevice);
                 Y = Scp.ASI.whereAmI('X'); 
            end
            
            function Z=getZ(Scp)
                %Y=Scp.mmc.getXPosition(Scp.mmc.getXYStageDevice);
                Z = Scp.ASI.whereAmI('Z');
            end

            function setXY(Scp,XY)
                currXY = Scp.XY;
                dist = sqrt(sum((currXY-XY).^2));
                if Scp.XYpercision >0 && dist < Scp.XYpercision
                    fprintf('movment too small - skipping XY movement\n');
                    return
                end
                Scp.ASI.moveASI('XY',XY([2,1])); 
                %Scp.setX(XY(1)); 
                %Scp.setY(XY(2)); 
%                 Scp.mmc.setXYPosition(Scp.mmc.getXYStageDevice,XY(2),XY(1))
%                 Scp.mmc.waitForDevice(Scp.mmc.getProperty('Core','XYStage'));
            end
            
            function logError(Scp,msg,varargin)
                Scp.DieOnError=false; 
                logError@Scope(Scp,msg)
                Scp.resetASI; 
            end
            
           
            
        end
end
