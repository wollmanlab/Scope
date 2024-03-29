classdef ContrastPlaneFocus < NucleiFocus
    properties
        use_groups = false;
        groups
        group_focuses
        radius = 1500/2;
        method = 'robust_plane';
        n_pos = 3;
        percentage_thresh = 10;
        min_positions = 20;
        group_samples;
        optimize_speed = true;

    end
    methods
        function AF = checkFocus(AF,Scp,varargin)
            x = Scp.X;
            y = Scp.Y;
            P = AF.Pos.List(AF.Pos.Hidden==0,:);
            [~,i] = sort(sqrt(((P(:,1)-x).^2)+((P(:,2)-y).^2)));
            P = P(i(1:AF.n_neighbors),:);
            if AF.n_neighbors == 1
                Z = P(:,3);
            else
                if strcmp(AF.method,'plane')
                    AF.B = [P(:,1), P(:,2), ones(size(P,1),1)] \ P(:,3);
                    Z = [x,y ones(size(1,1),1)]*AF.B;
                elseif strcmp(AF.method,'robust_plane')
                    all_P = P;
                    P_indexes = 1:size(P,1);
                    Zs = zeros(length(P_indexes),1);
                    % Robust Plane
                    for z=1:length(P_indexes)
                        P = all_P([1:z-1,z+1:end],:);
                        % Robust Plane
                        AF.B = [P(:,1), P(:,2), ones(size(P,1),1)] \ P(:,3);
                        Zs(z) = [x,y ones(size(1,1),1)]*AF.B;
                    end
                    Z = median(Zs);
                elseif  strcmp(AF.method,'median')
                    Z = median(P(:,3));
                else
                    Z = mean(P(:,3));
                end

            end
            Scp.Z = Z;
            AF.foundFocus = true;
        end

        function AF = createPostions(AF,Pos,varargin)
            arg.filter = true;
            arg.percentage = 0.95;
            arg = parseVarargin(varargin,arg);
            AF.Pos = Positions;
            AF.Pos.List = Pos.List(Pos.Hidden==0,1:2);
            AF.Pos.Labels = Pos.Labels(Pos.Hidden==0);
            AF.Pos.Hidden = Pos.Hidden(Pos.Hidden==0);
            if ~AF.use_groups
                cellArray = Pos.Group(Pos.Hidden==0);
                for i=1:numel(cellArray)
                    cellArray{i} = '1';
                end
                AF.Pos.Group = cellArray;
            else
                cellArray = Pos.Group(Pos.Hidden==0);
                for i=1:numel(cellArray)
                    g = split(AF.Pos.Labels{i},'-Pos');
                    g = g{1};
                    cellArray{i} = g;
                end
                AF.Pos.Group = cellArray;
            end
            AF.Pos.Well = Pos.Well;
            groups = unique(AF.Pos.Group);
            for g = 1:length(groups)
                group = groups{g};
                good_labels = 1:length(AF.Pos.Labels);
                good_labels = good_labels(cellfun(@(x) strcmp(x, group), AF.Pos.Group));
                if arg.filter
                    if floor(length(good_labels)*(1-arg.percentage))>AF.min_positions
                        filtered_labels = datasample(good_labels,floor(length(good_labels)*(arg.percentage)),'Replace',false);
                    else
                        if length(good_labels)>AF.min_positions
                            filtered_labels = datasample(good_labels,length(good_labels)-AF.min_positions,'Replace',false);
                        elseif length(good_labels)<3
                            Scp.Notifications.sendSlackMessage(Scp,['Not Enough Positions for Plane Use NucleiFocus']);
                            uiwait(msgbox(['You should probably just use NucleiFocus']))
                        else
                            AF.n_neighbors = length(good_labels);
                            filtered_labels = [];
                        end
                    end
                    %                 AF.Pos.Hidden(:) = 1;
                    AF.Pos.Hidden(filtered_labels) = 1;
                end
            end
        end

%         function AF = createPostionsWithCells(AF,Scp,varargin)
%             arg.filter = true;
%             arg.percentage = 0.95;
%             arg = parseVarargin(varargin,arg);
%             AF.Pos = Positions;
%             Pos = Scp.Pos;
%             AF.Pos.List = Pos.List(Pos.Hidden==0,1:2);
%             AF.Pos.Labels = Pos.Labels(Pos.Hidden==0);
%             AF.Pos.Hidden = Pos.Hidden(Pos.Hidden==0);
%             if ~AF.use_groups
%                 cellArray = Pos.Group(Pos.Hidden==0);
%                 for i=1:numel(cellArray)
%                     cellArray{i} = '1';
%                 end
%                 AF.Pos.Group = cellArray;
%             else
%                 cellArray = Pos.Group(Pos.Hidden==0);
%                 for i=1:numel(cellArray)
%                     g = split(AF.Pos.Labels{i},'-Pos');
%                     g = g{1};
%                     cellArray{i} = g;
%                 end
%                 AF.Pos.Group = cellArray;
%             end
%             AF.Pos.Well = Pos.Well;
%             groups = unique(AF.Pos.Group);
%             for g = 1:length(groups)
%                 group = groups{g};
%                 mask = cellfun(@(x) strcmp(x, group), AF.Pos.Group);
%                 good_labels = AF.Pos.Labels(mask);
%                 % Go to center of area to find rough focus
%                 xy = AF.Pos.List(mask,:);
%                 [value,index] = min(sum(abs(xy-mean(xy)),2));
%                 Scp.XY = xy(index,:);
%                 AF.PrimaryImageBasedScan(Scp);
%                 keepers = zeros([length(good_labels),1)]);
%                 for i=1:length(good_labels)
%                     Scp.Xy = xy(i,;)
%                     img = Scp.snapImage;
%                     img = imgaussfilt(img,2);
%                     bkg = imgsussfilt(img,50);
%                     img = img-bkg;
%                     n_pixels = sum(img>arg.thresh);
%                     if n_pixels>arg_pixel_thresh)
%                         keepers(i)=1;
%                     end
%                 end
%             end



%         end

        function AF = setupPositions(AF,Scp)
            uiwait(msgbox(['Create Atleast 4 Positions per sample']))
            AF.Pos = Scp.createPositionFromMM;
            % Update Groups to be sections
            for i = 1:length(AF.Pos.Labels)
                if AF.Pos.Hidden(i)==0
                    if AF.use_groups
                        g = split(AF.Pos.Labels{i},'-Pos');
                        g = g{1};
                    else
                        g = '1';
                    end
                    AF.Pos.Group{i} = g;
                end
            end
            AF.groups = unique(AF.Pos.Group(AF.Pos.Hidden==0));
            AF.group_focuses = zeros(length(AF.groups),1);
            AF.group_samples = zeros(length(AF.groups),AF.n_pos);
        end


 


        function AF = calculateZ(AF,Scp,varargin)

%             arg.filter = true;
            arg.percentage = 0.75;
            arg = parseVarargin(varargin,arg);

            Scp.Notifications.sendSlackMessage(Scp,'Calculating Autofocus');

            backup_type = Scp.AutoFocusType; 
            Scp.AutoFocusType='none';
            % Update Groups to be sections
            for i = 1:length(AF.Pos.Labels)
                if AF.Pos.Hidden(i)==0
                    if AF.use_groups
                        g = split(AF.Pos.Labels{i},'-Pos');
                        g = g{1};
                    else
                        g = '1';
                    end
                    AF.Pos.Group{i} = g;
                else
                    AF.Pos.Group{i} = '0';
                end
            end
            AF.groups = unique(AF.Pos.Group(AF.Pos.Hidden==0));
            AF.group_focuses = zeros(length(AF.groups),1);
            global_XYZ = zeros(length(AF.Pos.List),3);
            global_XYZ(:,1:2) = AF.Pos.List(:,1:2);
            % For each group
            for G = 1:length(AF.groups)
                disp(['Group ',int2str(G),' of ',int2str(length(AF.groups))])
                m1 = ismember(AF.Pos.Group,AF.groups{G});
                m2 = AF.Pos.Hidden==0;
                m = m1&m2;
                if sum(m)==0
                    continue
                end

                good_labels = 1:length(AF.Pos.Labels);
                good_labels = good_labels(m);
                AF.group_samples(G,:) = datasample(good_labels,AF.n_pos,'Replace',false);

                XYZ = zeros(sum(m),3);
                XYZ(:,1:2) = AF.Pos.List(m,1:2);
                % Go To Center of section
                Scp.XY = mean(XYZ(:,1:2));
                % Use Slow Wide Scan For primary search
                section_focus = AF.PrimaryImageBasedScan(Scp);
                section_focus = Scp.Z;
                AF.group_focuses(G) = section_focus;
                global_XYZ(m,3) = section_focus;
                % For each position in the group
                for g = 1:length(good_labels)
%                     tic
                    p = good_labels(g);
                    disp(['Position ',int2str(g),' of ',int2str(length(good_labels))])
                    Scp.XY = AF.Pos.List(p,1:2);
                    Scp.Z = section_focus; % always start at group focus
                    % Use Medium Speed Scan
                    if AF.optimize_speed
                        position_focus = AF.MiddleOutScan(Scp);
                    else
%                         position_focus = AF.SecondaryImageBasedScan(Scp);
                        position_focus = AF.PrimaryImageBasedScan(Scp);
                    end
                    AF.Pos.Other{p} = AF.calcMetric(Scp,'update_scp',true);
                    global_XYZ(p,3) = position_focus; 
                    % Maybe snap an image to save and use later %%%%%FUTURE
%                     toc
                end
%                 global_XYZ(m,3) = XYZ(:,3);

            end
            if strcmp(AF.Pos.axis{1},'XY')
                AF.Pos.axis = {'X','Y','Z'};
            end
            AF.Pos.List = global_XYZ;
            Scp.AutoFocusType=backup_type;
            for G = 1:length(AF.groups)
                AF.Pos.Labels{AF.group_samples(G,:)}
            end
        end

        function AF = updateZ(AF,Scp)
            global_XYZ = zeros(length(AF.Pos.List),3);
            global_XYZ(:,1:3) = AF.Pos.List(:,1:3);
            % For each section
            for g = 1:length(AF.groups)
                disp(['Group ',int2str(g),' of ',int2str(length(AF.groups))])
                m1 = ismember(AF.Pos.Group,AF.groups{g});
                m2 = AF.Pos.Hidden==0;
                m = m1&m2;
                if sum(m)==0
                    continue
                end
                good_labels = 1:length(AF.Pos.Labels);
                good_labels = good_labels(m);
%                 if sum(m)>AF.n_pos
%                     n_pos = AF.n_pos;
%                 else
%                     n_pos = sum(m);
%                 end
%                 selected_labels = datasample(good_labels,n_pos,'Replace',false);
                selected_labels = AF.group_samples(g,:);
                XYZ = zeros(AF.n_pos,3);
                XYZ(:,1:3) = AF.Pos.List(selected_labels,1:3);
                
%                 % Go To Center of section
%                 Scp.XY = mean(XYZ(:,1:2));
%                 Scp.Z =  AF.group_focuses(g); % Use last Focus as a starting place
%                 % Use Medium Speed Scan
%                 section_focus = AF.SecondaryImageBasedScan(Scp);
%                 AF.group_focuses(g) = section_focus;

                for i=1:AF.n_pos
                    p = selected_labels(i);
                    Scp.XY = XYZ(i,1:2);
                    Scp.Z = XYZ(i,3);
                    if AF.optimize_speed
                        XYZ(i,3) = AF.MiddleOutScan(Scp);
                    else
                        XYZ(i,3) = AF.SecondaryImageBasedScan(Scp);
                    end
%                     current_metric = AF.calcMetric(Scp,'update_scp',true);
%                     past_metric = AF.Pos.Other{p};
%                     if (100*abs(past_metric-current_metric)/past_metric)>(AF.percentage_thresh)
%                         message = ['Current Metric is more than ',num2str(AF.percentage_thresh),'% different than previous metric for this position'];
%                         disp(message)
%                         Scp.Notifications.sendSlackMessage(Scp,message);
%                         Scp.Z = XYZ(i,3);
%                         XYZ(i,3) = AF.PrimaryImageBasedScan(Scp);
%                         % update last metric
%                         AF.Pos.Other{p} = AF.calcMetric(Scp,'update_scp',true);
%                     end
                end
                translation = median(global_XYZ(selected_labels,3)-XYZ(:,3));
                global_XYZ(m,3) = global_XYZ(m,3)-translation;
%                 prevous_section_focus = AF.group_focuses(g);
%                 translation = prevous_section_focus-section_focus;
%                 global_XYZ(m,3) = section_focus;% XYZ(:,3)-translation;
            end
            if strcmp(AF.Pos.axis{1},'XY')
                AF.Pos.axis = {'X','Y','Z'};
            end
            AF.Pos.List = global_XYZ;
        end

    end
end
