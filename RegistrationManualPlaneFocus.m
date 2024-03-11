classdef RegistrationManualPlaneFocus < AutoFocus
    properties
        channel = 'FarRed';
        exposure = 100;
        plane_points;
        groups;
        reference_images;
        reference_image;
        use_groups = false;
        Pos = Positions;
        locations = {'Center'};%,'Top','Right','Bottom','Left'};

    end
    methods
        function AF = checkFocus(AF,Scp,varargin)
            x = Scp.X;
            y = Scp.Y;

            % Find the closest Plane 
            [~,i] = sort(sqrt(((AF.plane_points(:,1)-x).^2)+((AF.plane_points(:,2)-y).^2)));
            group = AF.plane_points(i,4);
            m = AF.plane_points(:,4)==group;
            if sum(m)==1
                group_plane_points = AF.plane_points(m,1:3);
                Z = median(group_plane_points(:,3));
            else
                group_plane_points = AF.plane_points(m,1:3);
                plane = [group_plane_points(:,1), group_plane_points(:,2), ones(size(group_plane_points,1),1)] \ group_plane_points(:,3);
                Z = [x,y ones(size(1,1),1)]*plane;
            end
            Scp.Z = Z;
            AF.foundFocus = true;
        end

        function manualSetZ(AF,Scp)
            Scp.Notifications.sendSlackMessage(Scp,'Manual Autofocus');

            % For each group
            for G = 1:length(AF.groups)
                disp(['Group ',int2str(G),' of ',int2str(length(AF.groups))])
                m1 = ismember(AF.Pos.Group,AF.groups{G});
                m2 = AF.Pos.Hidden==0;
                m = m1&m2;
                if sum(m)==0
                    continue
                end

                XYZ = zeros(sum(m),3);
                XYZ(:,1:2) = AF.Pos.List(m,1:2);
                % Go To Center of section
                Scp.XY = mean(XYZ(:,1:2));

                % Find Focus
                for i=1:length(AF.locations)
                    idx = ((G-1)*length(AF.locations))+i;
                    uiwait(msgbox(['Find Focus ',AF.locations{i}]))
                    AF.plane_points(idx,1:2) = Scp.XY;
                    AF.plane_points(idx,3) = Scp.Z;
                    AF.plane_points(idx,4) = G;
                end
            end
        end

        function acquireReference(AF,Scp)
            AF.reference_images = zeros([length(AF.groups),Scp.Width,Scp.Height]);
            Scp.Channel = AF.channel;
            Scp.Exposure = AF.exposure;
            for G=1:length(AF.groups)
                idx = ((G-1)*length(AF.locations))+1;
                Scp.XY = AF.plane_points(idx,1:2);
                Scp.Z = AF.plane_points(idx,3);
                AF.reference_images(G,:,:) = Scp.snapImage;
            end
        end

        function updateZ(AF,Scp)
            for G=1:length(AF.groups)
                idx = ((G-1)*length(AF.locations))+1;
                % Move to reference location
                Scp.XY = AF.plane_points(idx,1:2);
                Scp.Z = AF.plane_points(idx,3);
                previousZ = Scp.Z;
                
                AF.Scan(Scp,G);

                % Update
                newZ = Scp.Z;
                difference = previousZ-newZ;
                m = AF.plane_points(:,4)==G;
                AF.plane_points(m,3) = AF.plane_points(m,3)+difference;
            end
        end

        function processed_image = processImage(AF,image)
            processed_image = medfilt2(image,[3,3]); % Remove Hot Pixels
            bkg = imgaussfilt(processed_image,50); % Remove Bleedthrough light
            processed_image = processed_image-bkg;
        end

        function Zfocus = Scan(AF,Scp,G)
            zinit = Scp.Z;
            zmax = zinit + AF.window;
            zmin = zinit - AF.window;
            steps = linspace(zmin,zmax,1+round((zmax-zmin)/AF.dZ));
            score = zeros(length(steps),1);
            previous_channel = Scp.Channel;
            previous_exposure = Scp.Exposure;
            Scp.Channel = AF.channel;
            Scp.Exposure = AF.exposure;

            AF.reference_image = AF.processImage(AF.reference_images(G,:,:));
            % Calculate Focus Score
            for zindex = 1:length(steps)
                Scp.Z = steps(zindex); 
                image = AF.processImage(Scp.snapImage);
                score(zindex) = AF.calcMetric(AF.reference_image,image);
            end
            
            Zfocus = mean(steps(score==max(score))); % Maybe update to be a fit
            Scp.Z = Zfocus;
            AF.reference_images(G,:,:) = Scp.snapImage; % Maybe Remove %%%%%%%%%%%%%%%%%%%%%%%%%%%
            figure(G*101)
            scatter(steps,score)
            Scp.Channel =  previous_channel;
            Scp.Exposure = previous_exposure;
        end

        function score = calcMetric(AF,reference_image,image)
            % Correlation 
            score = corr2(reference_image,image);
        end

        function AF = createPostions(AF,Pos,varargin)
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
            AF.plane_points = zeros([length(unique(AF.groups))*5,4]); %XYZG
        end
    end
end
