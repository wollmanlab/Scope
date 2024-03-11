classdef RelativeManualPlaneFocus < NucleiFocus
    properties
        window = 25;
        reference_XY;
        reference_Z;
        reference_Zfocus;
        reference_offset;
        plane_points;
        groups;
        use_groups = false;
        locations = {'Center'};%,'Top','Right','Bottom','Left'};
    end
    methods
        function AF = checkFocus(AF,Scp,varargin)
            x = Scp.X;
            y = Scp.Y;

            % Find the closest Plane 
            [~,i] = sort(sqrt(((AF.plane_points(:,1)-x).^2)+((AF.plane_points(:,2)-y).^2)));
            i = i(1);
            group = AF.plane_points(i,4);
            m = AF.plane_points(:,4)==group;
            group_plane_points = AF.plane_points(m,1:3);
            if sum(m)==1
                Z = median(group_plane_points(:,3));
            else
                plane = [group_plane_points(:,1), group_plane_points(:,2), ones(size(group_plane_points,1),1)] \ group_plane_points(:,3);
                Z = [x,y ones(size(1,1),1)]*plane;
            end
            Scp.Z = Z;
            AF.foundFocus = true;
        end

        function AF = manualSetPlane(AF,Scp)
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
            uiwait(msgbox('Set Reference position (XYZ)'))
            AF.reference_XY = Scp.XY;
%             AF = AF.setRelativeReferencePosition(Scp);
        end

        function AF = setRelativeReferencePosition(AF,Scp)
%             uiwait(msgbox('Set Reference position (XYZ)'))
%             AF.reference_XY = Scp.XY;
            Scp.XY = AF.reference_XY;
            AF.reference_Z = AF.ImageBasedScan(Scp, AF.window, AF.dZ);
        end

        function AF = updateZ(AF,Scp)
            Scp.XY = AF.reference_XY;
            Scp.Z = AF.reference_Z;
            current_Z = AF.ImageBasedScan(Scp, AF.window, AF.dZ);
            difference = current_Z-AF.reference_Z;
            AF.reference_Z = current_Z;
            AF.plane_points = AF.plane_points+difference;
        end

        function AF = createPostions(AF,Pos)
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
