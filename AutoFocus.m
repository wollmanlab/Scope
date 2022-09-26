classdef (Abstract) AutoFocus < handle
    properties
        lower_z = 50;
        upper_z = 50;
        step = 10;
        pause = 1;
        foundFocus = false;
        current_acq = 'default';
        focus_reliquary = containers.Map;
        start_Z = [];
        surface_method = 'poly23';
        alert_level = 2;
    end
    
    methods
        function [AF,Pos] = findFocus(AF,Scp,varargin)
            Pos = Scp.Pos;
            AF.foundFocus = false;
            AF.start_Z = Scp.Z;
            % First Check Focus
            AF = AF.checkFocus(Scp,varargin);
            % If Focus wasnt found
            if ~AF.foundFocus
                % Predict Focus based on past found focus 
%                 AF = AF.predictFocus(Scp,varargin);
                % Check Focus
                AF = AF.checkFocus(Scp,varargin);
                % If Focus wasnt found
                if ~AF.foundFocus
                   % Move down in Z
                   % Scan upwards checking for focus
                   AF = AF.scanFocus(Scp,varargin);
                   % If Focus wasnt found
                   if ~AF.foundFocus
                       % Send Slack Message to User
                       % Wait for Response
                       Scp.Z = AF.start_Z;
                       [AF,Pos] = AF.askForHelp(Scp,varargin);
                   end
                end
            end
            if isempty(Scp.MD)
                AF.current_acq = 'default';
            else
                AF.current_acq = Scp.MD.acqname;
            end
            % Add Focus to Found Focus Reliquary
            label=['x_',int2str(Scp.X),'_y_',int2str(Scp.Y)];
            if isKey(AF.focus_reliquary,AF.current_acq)
                current_reliquary = AF.focus_reliquary(AF.current_acq);
            else
                current_reliquary = containers.Map;
            end
            current_reliquary(label) = [Scp.X,Scp.Y,Scp.Z];
            AF.focus_reliquary(AF.current_acq) = current_reliquary;
        end
        
        function AF = checkFocus(AF,Scp,varargin)
            % Intended to be overwritten
            error('Not implemented in AutoFocus - overload to use')
        end
        
        function AF = predictFocus(AF,Scp,varargin)
            if AF.alert_level<2
                message = ['Autofocus didnt find focus',newline,'Attempting to Predict Focus'];
                Scp.Notifications.sendSlackMessage(Scp,message,'all',true);
            end
            if isKey(AF.focus_reliquary,AF.current_acq)==false
                % Use start Z
                Scp.Z = Scp.AF.start_Z;
            elseif isempty(AF.focus_reliquary(AF.current_acq))
                % Use start Z
                Scp.Z = Scp.AF.start_Z;
            else
                % Use Found Focus points
                container = AF.focus_reliquary(AF.current_acq);
                array = zeros(length(container),3);
                key_list = keys(container);
                for i=1:length(container)
                    key = char(key_list(i));
                    array(i,:) = container(key);
                end
                try
                    % Use Found Focus to fit surface and predict focus
                    surface_model = fit([array(:,1) array(:,2)],array(:,3),AF.surface_method);
                    updated_coordinate = surface_model([Scp.X,Scp.Y]);
                catch ME
                    % Use Median
                    updated_coordinate = median(array(:,3));
                end
                if isnan(updated_coordinate)
                    % Use Median
                    updated_coordinate = median(array(:,3));
                end
                Scp.Z = updated_coordinate;
            end
        end
        
        function AF = scanFocus(AF,Scp,varargin)
            if AF.alert_level<3
                message = ['Autofocus didnt find focus',newline,'Attempting to Scan for Focus'];
                Scp.Notifications.sendSlackMessage(Scp,message,'all',true);
            end
            dZ = linspace(-AF.lower_z, AF.upper_z, 1+(AF.lower_z+AF.upper_z)/AF.step);
            current_Z = Scp.Z;
            for i = 1:length(dZ)
                Scp.Z = current_Z + dZ(i);
                pause(AF.pause);
                AF = AF.checkFocus(Scp);
                if AF.foundFocus
                    break
                end
            end
        end
        
        function [AF,Pos] = askForHelp(AF,Scp,varargin)
            message = ['Autofocus didnt find focus and Needs Help',newline,'Turn On Live',newline,'Manually Find Focus',newline,'Then Click OK'];
            % Add Option To Hide Position In Future
            Scp.Notifications.sendSlackMessage(Scp,message,'all',true);
            answer = questdlg(['Autofocus didnt find focus and Needs Help',newline,'Turn On Live',newline,'Manually Find Focus',newline,'Then Click OK',newline,'If Position Is not Good Click Hide'], ...
                'AutoFocus Needs Help', ...
                'Okay','Hide','');
            switch answer
                case 'Hide'
                    % Hide Current Position
                    current_xy = Scp.XY;
                    Distance = pdist2(current_xy, Scp.Pos.List);
                    [value, index] = min(Distance,[], 2);
                    Scp.Pos.Hidden(index) = 1;
                    
            end
            Pos = Scp.Pos;
        end
    end
end