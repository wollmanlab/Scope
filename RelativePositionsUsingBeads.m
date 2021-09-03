classdef RelativePositionsUsingBeads < RelativePositions
    
    properties
        GlobalBeadsCoord = {}; % keep global beads as 3D cell array
        PerPositionBeads = containers.Map;
        GlobalregParams = [];
        surface_method = 'Position';
        % grid to fit over corners
        grid = [3,4];
        % acquiring data %
        % Exposure
        Exposure = 50;
        % Delay
        Delay = 250;
        % AutoShutter
        AutoShutter = false;
        % Channel
        Channel = 'DeepBlue';
        %Z steps
        dstart = -5;
        dend = 10;
        dz = 1;
    end
    
    methods
        
        function [xyzrtrn,xyzorg] = getPositionFromLabel(Pos,label)
            % first get xyz without in relative units
            xyzorg = getPositionFromLabel@RelativePositions(Pos,label);
            % adjust position based on global beads
            xyzrtrn = Pos.GlobalregParams.R*xyzorg' + Pos.GlobalregParams.t;
        end
        
        function globalSetFocus(Scp)
            % Create Global Reference Positions
            Scp.Pos.global_reference_positions = Scp.Pos.createGlobalReferencePositions();
            % Find Global Features
            Scp.Pos.GlobalBeadsCoord = Scp.Pos.findGlobalFeatures(Scp);
            % Fit Surface
            % Will be used to interpolate the focus z coordinate for local
            % positions as a best guess (maybe accurate enough without
            % local)
            Scp.Pos.fitSurfaceModel(Scp);
            % Update Scp.Pos with new Z Coordinates
            
        end
        
        function globalFindFocus(Scp)
            % Load Global Reference Points
            reference_global_points = Scp.Pos.GlobalBeadsCoord;
            % Find Global Features
            current_global_points = Scp.Pos.findGlobalFeatures();
            if isempty(Scp.Pos.current_global_points)
               % Redo with larger dZ
               old_dstart = Scp.Pos.dstart;
               old_dend = Scp.Pos.dend;
               Scp.Pos.dstart = old_dstart-10;
               Scp.Pos.dend = old_dend+10;
               current_global_points = Scp.Pos.findGlobalFeatures(Scp);
               Scp.Pos.dstart = old_dstart;
               Scp.Pos.dend = old_dend;
               if isempty(current_global_points)
                   %Raise Error%
                   % No Features Detected%
                   error('No Global Features Found');
               end
            end
            reference_coordinates = values(reference_global_points);
            current_coordinates = values(current_global_points);
            % Pair Features to Global Reference Points from RelativePositions
            indexPairs = matchFeatures(reference_coordinates,current_coordinates);
            reference_coordinates = reference_coordinates(indexPairs(:,1),:);
            current_coordinates = current_coordinates(indexPairs(:,2),:);
            
            if isempty(reference_coordinates)
                % Redo with larger dZ
               old_dstart = Scp.Pos.dstart;
               old_dend = Scp.Pos.dend;
               Scp.Pos.dstart = old_dstart-5;
               Scp.Pos.dend = old_dend+5;
               current_global_points = Scp.Pos.findGlobalFeatures(Scp);
               reference_coordinates = values(reference_global_points);
               current_coordinates = values(current_global_points);
               % Pair Features to Global Reference Points from RelativePositions
               indexPairs = matchFeatures(reference_coordinates,current_coordinates);
               reference_coordinates = reference_coordinates(indexPairs(:,1),:);
               current_coordinates = current_coordinates(indexPairs(:,2),:);
               Scp.Pos.dstart = old_dstart;
               Scp.Pos.dend = old_dend;
               if isempty(reference_coordinates)
                   %Raise Error%
                   % Features didnt match%
                   error('Global Features Dont Match Reference');
               end
            end
            % Calculate Global TForm and add it to Relative Positions
            Scp.Pos.GlobalregParams = absor(transpose(reference_coordinates),transpose(current_coordinates));
            % Check Residual and Error if too high
        end
        
        function GlobalBeadsCoord = findGlobalFeatures(Scp)
            % Go To Each Global Reference Position
            global_positions = keys(Scp.Pos.global_reference_positions);
            GlobalBeadsCoord = containers.Map;
            dZ = linspace(Scp.Pos.dstart, Scp.Pos.dend, 1+(Scp.Pos.dend-Scp.Pos.dstart)/Scp.Pos.dz);
            for p = 1:length(global_positions)
                pos = global_positions(p);
                xyz = Scp.Pos.global_reference_positions(pos);
                % Go to xyz
                Scp.X = xyz(1);
                Scp.Y = xyz(2);
                Scp.Z = xyz(3);
                % Detect Features
                % Acquire Stack
                Scp.Channel = Scp.Pos.Channel;
                Scp.Exposure = Scp.Pos.Exposure;
                stk = Scp.snapZstack(dZ);
                % Find Features in Stack Return Coordinates
                current_pixel_coordinates = findFeatures(stk);
                % Covert to Stage Coordinates Move to function
                current_coordinates = zeros(size(current_pixel_coordinates,1),3);
                for i=1:size(reference_pixel_coordinates,1)
                    % Verify Camera Orientation
                    current_coordinates(i,1:2)=Scp.rc2xy(current_pixel_coordinates(i,1:2));
                end
                current_coordinates(:,3) = Scp.Z + ((current_pixel_coordinates(:,3)*Scp.Pos.dz)-Scp.Pos.dstart);

                for f=1:size(current_coordinates,1)
                    label = ['Pos_',int2str(p),'_Bead_',int2str(f)];
                    %Add point to Reference
                    GlobalBeadsCoord(label) = current_coordinates(f,:);
                end
            end
        end
        
        function global_reference_positions = createGlobalReferencePositions(Scp)
            % Allow user to set 4 edges (XY) that encompass the area that
            % will be imaged during the acquisition
            % USe Scp.Pos coordinates for grid
            if isempty(Scp.Pos.Labels)
                edges = zeros(4,2);
                for c=1:size(edges,1)
                    message = ['Set Edge Number ',int2str(c),' of ',int2str(size(edges,1))];
                    uiwait(msgbox(message))
                    edges(c,:) = [Scp.X,Scp.Y];
                end
                % Create Grid
                xy_min = min(edges);
                xy_max = max(edges);
            else
                % Use Stage Positions to set borders
                xy_min = min(Scp.Pos.List);
                xy_max = max(Scp.Pos.List);
            end
            x_step = linspace(xy_min(1),xy_max(1),Scp.Pos.grid(1));
            y_step = linspace(xy_min(2),xy_max(2),Scp.Pos.grid(2));
            % Manually Find Focus For Grid
            global_reference_positions = containers.Map;
            for x=1:length(x_step)
                for y=1:length(y_step)
                    label=['x_',inst2str(x),'_y_',int2str(y)];
                    % Move to Location
                    Scp.X = x_step(x);
                    Scp.Y = y_step(y);
                    % Manually Define Focus
                    message = ['Set Reference Position ',int2str(x*y),' of ',int2str(Scp.Pos.grid(1)*Scp.Pos.grid(2))];
                    uiwait(msgbox(message))
                    % Save as focus point
                    global_reference_positions(label) = [Scp.X,Scp.Y,Scp.Z];
                end
            end
        end
        
        function fitSurfaceModel(Scp)
            % Take the given points and fit a Surface so that in the future
            % XY coordinates can be passed and the desired z coordinates
            % will be returned
            switch Scp.Pos.surface_method
                case 'Position'
                    % Based on set Z Coord
                    global_surface_coordinates = values(Scp.Pos.global_reference_positions);
                case 'Feature'
                    % Based on Global Features
                    global_surface_coordinates = values(Scp.Pos.GlobalBeadsCoord);
                    % Start with Plane
            end
            Scp.surface_model = global_surface_coordinates;
            %FIX%
        end
    end
end