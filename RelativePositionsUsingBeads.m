classdef RelativePositionsUsingBeads < RelativePositions
    
    properties
        GlobalBeadsCoord = {}; % keep global beads as 3D cell array
        reg_reliquary = containers.Map;
        bead_reliquary = containers.Map;
        PerPositionBeads = containers.Map;
        global_reference_positions = containers.Map;
        GlobalregParams = [];
        approach = 'registration' ;%plane
        surface_method = 'Position';
        % grid to fit over corners
        grid = [4,4];
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
        dz = 0.4;
    end
    
    methods
        
        function Pos = RelativePositionsUsingBeads(fullfilename,varargin)
            Pos@RelativePositions(fullfilename,varargin)
        end
        
        function [xyzrtrn,xyzorg] = getPositionFromLabel(Pos,label)
            % first get xyz without in relative units
            [xyzorg,~] = getPositionFromLabel@RelativePositions(Pos,label);
            % adjust position based on global beads
            switch Pos.approach
                case 'registration'
                    xyzrtrn = Pos.GlobalregParams.R*xyzorg' + Pos.GlobalregParams.t;
                case 'plane'
                    xyzrtrn = xyzorg;
            end
        end
        
        function globalSetFocus(Pos,Scp)
            % Create Global Reference Positions
            Scp.Pos.global_reference_positions = Pos.createGlobalReferencePositions(Scp);
            % Find Global Features
            Scp.Pos.GlobalBeadsCoord = Pos.findGlobalFeatures(Scp);
            % Fit Surface
            % Will be used to interpolate the focus z coordinate for local
            % positions as a best guess (maybe accurate enough without
            % local)% Update Scp.Pos with new Z Coordinates
            Pos.updateZCoordinates(Scp);
        end
        
        function array = container2array(Pos,container)
            array = zeros(length(container),3);
            key_list = keys(container);
            for i=1:length(container)
                key = char(key_list(i));
                array(i,:) = container(key);
            end
        end
        
        function [reference_coordinates,current_coordinates] = filterMatchedFeatures(Pos,reference_coordinates,current_coordinates)
            % Toss Pairs that are too different
            diff = reference_coordinates-current_coordinates;
            median_diff = diff - median(diff);
            max_diff = max(abs(median_diff),[],2);
            % Toss pairs that are more than 1 um different from median difference
            idx = max_diff<1;
            reference_coordinates = reference_coordinates(idx,:);
            current_coordinates = current_coordinates(idx,:);
        end
        
        function globalFindFocus(Pos,Scp)
            % Find Global Features
            current_global_points = Pos.findGlobalFeatures(Scp);
            if isempty(current_global_points)
                % Redo with larger dZ
                old_dstart = Pos.dstart;
                old_dend = Pos.dend;
                Pos.dstart = old_dstart-10;
                Pos.dend = old_dend+10;
                % Find Features
                current_global_points = Pos.findGlobalFeatures(Scp);
                
                Pos.dstart = old_dstart;
                Pos.dend = old_dend;
                if isempty(current_global_points)
                    %Raise Error%
                    % No Features Detected%
                    error('No Global Features Found');
                end
            end
            % Save Beads for diagnostics
            if isempty(Pos.bead_reliquary)
                Pos.bead_reliquary(int2str(1)) = current_global_points;
            else
                k = keys(Pos.bead_reliquary);
                k = k(length(k));
                k = str2double(cell2mat(k))+1;
                Pos.bead_reliquary(int2str(k)) = current_global_points;
            end
            switch Pos.approach
                case 'plane'
                    Pos.surface_method = 'Feature';
                    Pos.updateZCoordinates(Scp);
                case 'registration'
                    % Load Global Reference Points
                    reference_global_points = Pos.GlobalBeadsCoord;
                    
                    % Convert to array
                    reference_coordinates = Pos.container2array(reference_global_points);
                    current_coordinates = Pos.container2array(current_global_points);
                    
                    % Pair Features to Global Reference Points from RelativePositions
                    indexPairs = matchFeatures(reference_coordinates,current_coordinates);
                    reference_coordinates = reference_coordinates(indexPairs(:,1),:);
                    current_coordinates = current_coordinates(indexPairs(:,2),:);
                    
                    % Toss Pairs that are too different
                    [reference_coordinates,current_coordinates] = Pos.filterMatchedFeatures(reference_coordinates,current_coordinates);
                    
                    if isempty(reference_coordinates)
                        % Redo with larger dZ
                        old_dstart = Pos.dstart;
                        old_dend = Pos.dend;
                        Pos.dstart = old_dstart-5;
                        Pos.dend = old_dend+5;
                        % Find Features
                        current_global_points = Pos.findGlobalFeatures(Scp);
                        % Convert to array
                        reference_coordinates = Pos.container2array(reference_global_points);
                        current_coordinates = Pos.container2array(current_global_points);
                        
                        % Pair Features to Global Reference Points from RelativePositions
                        indexPairs = matchFeatures(reference_coordinates,current_coordinates);
                        reference_coordinates = reference_coordinates(indexPairs(:,1),:);
                        current_coordinates = current_coordinates(indexPairs(:,2),:);
                        
                        % Toss Pairs that are too different
                        [reference_coordinates,current_coordinates] = Pos.filterMatchedFeatures(reference_coordinates,current_coordinates);
                        
                        Pos.dstart = old_dstart;
                        Pos.dend = old_dend;
                        if isempty(reference_coordinates)
                            %Raise Error%
                            % Features didnt match%
                            error('Global Features Dont Match Reference');
                        end
                    end
                    % Calculate Global TForm and add it to Relative Positions
                    Scp.Pos.GlobalregParams = absor(transpose(reference_coordinates),transpose(current_coordinates));
                    % Check Residual and Error if too high
                    % Save Beads for diagnostics
                    if isempty(Pos.reg_reliquary)
                        Pos.reg_reliquary(int2str(1)) = Scp.Pos.GlobalregParams;
                    else
                        k = keys(Pos.reg_reliquary);
                        k = k(length(k));
                        k = str2double(cell2mat(k))+1;
                        Pos.reg_reliquary(int2str(k)) = Scp.Pos.GlobalregParams;
                    end
            end
        end
        
        function GlobalBeadsCoord = findGlobalFeatures(Pos,Scp)
            % Go To Each Global Reference Position
            global_positions = keys(Pos.global_reference_positions);
            GlobalBeadsCoord = containers.Map;
            dZ = linspace(Pos.dstart, Pos.dend, 1+(Pos.dend-Pos.dstart)/Pos.dz);
            for p = 1:length(global_positions)
                pos = char(global_positions(p));
                xyz = Pos.global_reference_positions(pos);
                % Go to xyz
                Scp.X = xyz(1);
                Scp.Y = xyz(2);
                Scp.Z = xyz(3);
                %
                pause(10);
                % Detect Features
                % Acquire Stack
                Scp.Channel = Pos.Channel;
                Scp.Exposure = Pos.Exposure;
                %stk = Scp.snapZstack(dZ);
                stk = zeros([Scp.Height Scp.Width length(dZ)]);
                current_Z = Scp.Z;
                for i = 1:length(dZ)
                    Scp.Z = current_Z + dZ(i);
                    stk(:,:,i) = Scp.snapImage();
                end
                Scp.Z = current_Z;
                % Find Features in Stack Return Coordinates
                current_pixel_coordinates = findFeatures(stk);
                % Covert to Stage Coordinates Move to function
                current_coordinates = zeros(size(current_pixel_coordinates,1),3);
                for i=1:size(current_coordinates,1)
                    % Verify Camera Orientation
                    current_coordinates(i,1:2)=Scp.rc2xy(current_pixel_coordinates(i,1:2),'cameratranspose',true,'cameradirection',[-1 1]);
                end
                current_coordinates(:,3) = Scp.Z + ((current_pixel_coordinates(:,3)*Pos.dz)-Pos.dstart);
                
                for f=1:size(current_coordinates,1)
                    label = ['Pos_',int2str(p),'_Bead_',int2str(f)];
                    %Add point to Reference
                    GlobalBeadsCoord(label) = current_coordinates(f,:);
                end
            end
        end
        
        function global_reference_positions = createGlobalReferencePositions(Pos,Scp)
            % Allow user to set 4 edges (XY) that encompass the area that
            % will be imaged during the acquisition
            % USe Scp.Pos coordinates for grid
            if isempty(Pos.Labels)
                edges = zeros(4,2);
                for c=1:size(edges,1)
                    message = ['Set Edge Number ',int2str(c),' of ',int2str(size(edges,1))];
                    uiwait(msgbox(message))
                    edges(c,:) = [Scp.X,Scp.Y];
                end
                % Create Grid
                % Add 100 um as buffer for plane fit
                xy_min = min(edges)-100;
                xy_max = max(edges)+100;
            else
                % Use Stage Positions to set borders
                xy_min = min(Pos.List)-100;
                xy_max = max(Pos.List)+100;
            end
            x_step = linspace(xy_min(1),xy_max(1),Pos.grid(1));
            y_step = linspace(xy_min(2),xy_max(2),Pos.grid(2));
            % Manually Find Focus For Grid
            global_reference_positions = containers.Map;
            ticker = 0;
            for x=1:length(x_step)
                for y=1:length(y_step)
                    ticker = ticker + 1;
                    label=['x_',int2str(x),'_y_',int2str(y)];
                    % Move to Location
                    Scp.X = x_step(x);
                    Scp.Y = y_step(y);
                    % Manually Define Focus
                    message = ['Set Reference Position ',int2str(ticker),' of ',int2str(Scp.Pos.grid(1)*Scp.Pos.grid(2)),newline,label];
                    uiwait(msgbox(message))
                    % Save as focus point
                    global_reference_positions(label) = [Scp.X,Scp.Y,Scp.Z];
                end
            end
            message = 'Press Ok When Live is Off';
            uiwait(msgbox(message))
        end
        
        function updateZCoordinates(Pos,Scp)
            % Take the given points and fit a Surface so that in the future
            % XY coordinates can be passed and the desired z coordinates
            % will be returned
            switch Pos.surface_method
                case 'Position'
                    % Based on set Z Coord
                    global_surface_coordinates = Pos.container2array(Pos.global_reference_positions);
                case 'Feature'
                    % Based on Global Features
                    global_surface_coordinates = Pos.container2array(Pos.GlobalBeadsCoord);
            end
            surface_model = fit([global_surface_coordinates(:,1) global_surface_coordinates(:,2)],global_surface_coordinates(:,3),'poly23');
            
            % Update Z Coordinates
            updated_coordinates = zeros(size(Scp.Pos.List,1),3);
            for i=1:size(Scp.Pos.List,1)
                updated_coordinates(i,1:2) = Scp.Pos.List(i,1:2);
                updated_coordinates(i,3) = surface_model(Scp.Pos.List(i,1:2));
            end
            % Check and fix nans with average focus
            updated_coordinates(:,isnan(updated_coordinates(:,3))) = mean(global_surface_coordinates(:,3));
            
            Scp.Pos.List = updated_coordinates;
            Scp.Pos.axis = {'X','Y','Z'};
        end
    end
end