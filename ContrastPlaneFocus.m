classdef ContrastPlaneFocus < NucleiFocus
    properties
        groups
        group_focuses
        radius = 1500/2;
        method = 'plane';
        n_pos = 3;

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
            arg.percentage = 0.75;
            arg = parseVarargin(varargin,arg);
            AF.Pos = Positions;
            AF.Pos.List = Pos.List(Pos.Hidden==0,1:2);
            AF.Pos.Labels = Pos.Labels(Pos.Hidden==0);
            AF.Pos.Hidden = Pos.Hidden(Pos.Hidden==0);
            AF.Pos.Group = Pos.Group(Pos.Hidden==0);
            AF.Pos.Well = Pos.Well;
            good_labels = 1:length(AF.Pos.Labels);
            if arg.filter
                if floor(length(good_labels)*arg.percentage)>AF.n_neighbors
                    filtered_labels = datasample(good_labels,floor(length(good_labels)*arg.percentage),'Replace',false);
                else
                    filtered_labels = datasample(good_labels,AF.n_neighbors,'Replace',false);
                end
                AF.Pos.Hidden(filtered_labels) = 1;
            end

        end

        function AF = setupPositions(AF,Scp)
            uiwait(msgbox(['Create Atleast 4 Positions per sample']))
            AF.Pos = Scp.createPositionFromMM;
            % Update Groups to be sections
            for i = 1:length(AF.Pos.Labels)
                if AF.Pos.Hidden(i)==0
                    g = split(AF.Pos.Labels{i},'-');
                    AF.Pos.Group{i} = g{2};
                end
            end
            AF.groups = unique(AF.Pos.Group(AF.Pos.Hidden==0));
            AF.group_focuses = zeros(length(AF.groups),1);
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
                    
                    g = split(AF.Pos.Labels{i},'-Pos');
                    AF.Pos.Group{i} = g{1};
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

%                 if arg.filter
%                     filtered_labels = datasample(good_labels,floor(length(good_labels)*arg.percentage),'Replace',false);
%                     AF.Pos.Hidden(filtered_labels) = 1;
%                     m1 = ismember(AF.Pos.Group,AF.groups{G});
%                     m2 = AF.Pos.Hidden==0;
%                     m = m1&m2;
%                     good_labels = 1:length(AF.Pos.Labels);
%                     good_labels = good_labels(m);
%                 end
                XYZ = zeros(sum(m),3);
                XYZ(:,1:2) = AF.Pos.List(m,1:2);
                % Go To Center of section
                Scp.XY = mean(XYZ(:,1:2));
                % Use Slow Wide Scan For primary search
                section_focus = AF.PrimaryImageBasedScan(Scp);
                AF.group_focuses(G) = section_focus;
                global_XYZ(m,3) = section_focus;
                % Create 3x3 grid of positions for reference
%                 ys = [-2,-1,0,1,2];
%                 xs=[-2,-1,0,1,2];
%                 temp_focuses = zeros(length(ys)*length(xs),3);
%                 ticker = 1;
%                 for y = ys
%                     Y = mean(XYZ(:,2))+(y*AF.radius);
%                     for x = xs
%                         X = mean(XYZ(:,1))+(x*AF.radius);
%                         Scp.XY = [X,Y];
%                         Scp.Z = section_focus;
%                         Z = AF.SecondaryImageBasedScan(Scp);
%                         temp_focuses(ticker,:) = [X,Y,Z];
%                         ticker = ticker+1;
%                     end
%                 end
                % For each position in the group
                for g = 1:length(good_labels)
%                     tic
                    p = good_labels(g);
                    disp(['Position ',int2str(g),' of ',int2str(length(good_labels))])
                    Scp.XY = AF.Pos.List(p,1:2);
                    Scp.Z = section_focus; % always start at group focus
                    % Use Medium Speed Scan
                    position_focus = AF.SecondaryImageBasedScan(Scp);
                    global_XYZ(p,3) = position_focus; 
                    % Maybe snap an image to save and use later %%%%%FUTURE
%                     toc
                end
%                 global_XYZ(m,3) = XYZ(:,3);

% P = temp_focuses;
% % add outlier detection
% P = P(P(:,3)<max(P(:,3)),:);
% P = P(P(:,3)>min(P(:,3)),:);
% AF.B = [P(:,1), P(:,2), ones(size(P,1),1)] \ P(:,3);
% guess_focuses = zeros(size(temp_focuses));
% for i=1:size(temp_focuses,1)
%     guess_focuses(i,1:2) = temp_focuses(i,1:2);
%     guess_focuses(i,3) = [temp_focuses(i,1),temp_focuses(i,2) ones(size(1,1),1)]*AF.B;
% end
% 
% figure(102)
% hold on
% scatter(temp_focuses(:,1)+500,temp_focuses(:,2)+500,100,temp_focuses(:,3),'filled')
% scatter(guess_focuses(:,1),guess_focuses(:,2),100,guess_focuses(:,3),'filled')
% hold off
% colorbar
% A = temp_focuses - guess_focuses;
% figure(104)
% hold on
% scatter(temp_focuses(:,1),temp_focuses(:,2),100,A(:,3),'filled')
% hold off
% colorbar
            end
            if strcmp(AF.Pos.axis{1},'XY')
                AF.Pos.axis = {'X','Y','Z'};
            end
            AF.Pos.List = global_XYZ;
            Scp.AutoFocusType=backup_type;
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
                if sum(m)>AF.n_pos
                    n_pos = AF.n_pos;
                else
                    n_pos = sum(m);
                end
                selected_labels = datasample(good_labels,n_pos,'Replace',false);
                XYZ = zeros(n_pos,3);
                XYZ(:,1:3) = AF.Pos.List(selected_labels,1:3);
                
%                 % Go To Center of section
%                 Scp.XY = mean(XYZ(:,1:2));
%                 Scp.Z =  AF.group_focuses(g); % Use last Focus as a starting place
%                 % Use Medium Speed Scan
%                 section_focus = AF.SecondaryImageBasedScan(Scp);
%                 AF.group_focuses(g) = section_focus;

                for i=1:n_pos
                    Scp.XY = XYZ(i,1:2);
                    Scp.Z = XYZ(i,3);
                    XYZ(i,3) = AF.SecondaryImageBasedScan(Scp);
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
            AF.save_AF;
        end


%         function AF = calculateZ(AF,Scp)
%             XYZ = zeros(size(AF.Pos.List,1),3);
%             XYZ(:,1:2) = AF.Pos.List(:,1:2);
%             last_XY = Scp.XY;
%             good_labels = 1:size(AF.Pos.Labels,1);
%             good_labels = good_labels(AF.Pos.Hidden==0);
%             for g=1:size(good_labels,2)
%                 p=good_labels(g);
%                 tic
% 
%                 disp([int2str(g),' of ',int2str(size(good_labels,2))])
% 
%                 Scp.XY = AF.Pos.List(p,1:2);
% % % % %                 if g==1
% % % % %                     % finer precise scan for first position of well
% % % % %                     focus = AF.ImageBasedFineScan(Scp);
% % % % %                 end
% 
% %                 if (p==1)|(dist>AF.distance_thresh)
% %                     uiwait(msgbox(['Manually Find Focus First']))
% %                 end
% %                 last_XY = Scp.XY;
% %                 Scp.Z = AF.Pos.List(p,3);
% %                 pause(1)
%                 focus = AF.ImageBasedFocusHillClimb(Scp);
%                 XYZ(p,3) = focus;
%                 toc
%             end
%             if strcmp(AF.Pos.axis{1},'XY')
%                 AF.Pos.axis = {'X','Y','Z'};
%             end
%             AF.Pos.List = XYZ;
%             AF = AF.updateB();
%         end

%         function AF = updateZ(AF,Scp)
%             tic
%             % Go to 10% of positions and update Z 
%             good_labels = 1:size(AF.Pos.Labels,1);
%             good_labels = good_labels(AF.Pos.Hidden==0);
%             n_sites = max([10,round(size(good_labels,1)/4)]);
%             sites = randsample(good_labels,n_sites)';
% 
%             XYZ = zeros(size(sites,1),3);
%             XYZ(:,1:2) = AF.Pos.List(sites,1:2);
%             for p=1:size(sites,1)
%                 disp([int2str(p),' of ',int2str(size(sites,1))])
%                 Scp.XY = AF.Pos.List(sites(p),1:2);
%                 pause(1)
%                 Scp.Z = AF.Pos.List(sites(p),3); 
%                 focus = AF.ImageBasedFocusHillClimb(Scp);
% %                 focus = AF.ImageBasedFocusHillClimb(Scp);
%                 XYZ(p,3) = focus;
%             end
%             translation = median(AF.Pos.List(sites,3)-XYZ(:,3));
%             AF.Pos.List(:,3) = AF.Pos.List(:,3)-translation;
%             toc
%         end

%         function AF = updateB(AF)
%             P = AF.Pos.List;
%             AF.B = [P(:,1), P(:,2), ones(size(P,1),1)] \ P(:,3);
%         end

%         function metric = calcMetric(AF,Scp)
%             if strcmp(AF.metric,'Contrast')
%                 Scp.Channel=AF.channel;
%                 Scp.Exposure=AF.exposure;
%                 % False will acq a Z stack per color.
%                 if AF.resize~=1
%                     img=imresize(Scp.snapImage, AF.resize);
%                 else
%                     img = Scp.snapImage;
%                 end
%                 if AF.scale>0
%                     m=img-imgaussfilt(img,AF.scale);
%                 else
%                     m=img;
%                 end
% %                 size(m)
%                 %m = m(200:end,200:end);
%                 rng=prctile(m(:),[1 99]);
%                 metric=rng(2)-rng(1);
%             elseif strcmp(AF.metric,'Contrast_1D')
%                 Scp.Channel=AF.channel;
%                 Scp.Exposure=AF.exposure;
%                 % False will acq a Z stack per color.
%                 if AF.resize~=1
%                     img=imresize(Scp.snapImage, AF.resize);
%                 else
%                     img = Scp.snapImage;
%                 end
%                 img = cat(1,[max(img),max(img')]);
%                 if AF.scale>0
%                     m=img-imgaussfilt(img,AF.scale);
%                 else
%                     m=img;
%                 end
% %                 size(m)
%                 %m = m(200:end,200:end);
%                 rng=prctile(m(:),[1 99]);
%                 metric=rng(2)-rng(1);
%             end
%         end
        
%         function Zfocus = iterativeFindFocus(AF,Scp)
%             contF = 0;
%             AF.iteration = 0;
%             Zinit = Scp.Z;
%             backup_dZ = AF.dZ;
%             while (contF<AF.thresh)&(AF.iteration<AF.max_iterations)
%                 Scp.Z = Zinit;
%                 AF.iteration = AF.iteration+1;
%                 disp(['Iteration',int2str(AF.iteration)])
%                 [Zfocus,contF] = AF.ImageBasedFocusHillClimb(Scp);
%                 AF.dZ = 2*AF.dZ; % Try Larger Window
%             end
%             AF.dZ = backup_dZ;
%             if AF.iteration>=AF.max_iterations
%                 disp('No Focus Found')
%                 % Focus Wasnt Found
%                 Zfocus = Zinit;
%                 Scp.Z = Zinit;
%             end
%         end

%         function [Zfocus,contF] = ImageBasedFocusHillClimb(AF,Scp)
%             %% Set channels and exposure
%             Scp.Channel=AF.channel;
%             Scp.Exposure=AF.exposure;
%             Zs = [];
%             Conts = [];
%             if AF.verbose
%                 figure(157),
%                 set(157,'menubar','none','Name','Finding focus by contrast','NumberTitle','off')
%                 clf
%             end
%             Zinit = Scp.Z;
%             max_Z = Zinit+AF.max_dZ;
%             min_Z = Zinit-AF.max_dZ;
%             dZ = AF.dZ;%25*(6.3)^2;
%             sgn = 1;
% 
%             acc = dZ^(AF.acceleration);
%             cont1=AF.calcMetric(Scp);
%             Zs = [Zs Scp.Z];
%             Conts = [Conts cont1];
% 
%             if AF.verbose
%                 plot(Scp.Z,cont1,'o')
%                 hold all
%             end
%             %determine direction of motion
% 
%             Scp.Z = Scp.Z+sgn*dZ;
%             cont2=AF.calcMetric(Scp);
% 
%             Zs = [Zs Scp.Z];
%             Conts = [Conts cont2];
%             if AF.verbose
%                 plot(Scp.Z,cont2,'o')
%             end
%             if cont2<cont1
%                 sgn = -sgn;
%                 Scp.Z  = Scp.Z+2*sgn*dZ;
%                 cont2=AF.calcMetric(Scp);
%                 if AF.verbose
%                     set(157,'menubar','none','Name','Finding focus by contrast','NumberTitle','off')
%                 end
%                 Zs = [Zs Scp.Z];
%                 Conts = [Conts cont2];
%                 if AF.verbose
%                     plot(Scp.Z,cont2,'o');
%                 end
% 
%                 if cont2<cont1
%                     dZ=dZ/2;%(acc^2);
% %                     dZ=dZ/(acc);
%                     Scp.Z = Zinit;%start over with smaller region
%                     cont1=AF.calcMetric(Scp);
% 
%                     Scp.Z = Scp.Z+sgn*dZ;
%                     cont2=AF.calcMetric(Scp);
% 
%                     Zs = [Zs Scp.Z];
%                     Conts = [Conts cont2];
%                     if AF.verbose
%                         plot(Scp.Z,cont2,'o')
%                     end
%                     if cont2<cont1
%                         sgn = -sgn;
%                         Scp.Z = Scp.Z+2*sgn*dZ;
%                         cont2=AF.calcMetric(Scp);
%                         Zs = [Zs Scp.Z];
%                         Conts = [Conts cont2];
%                         if AF.verbose
%                             plot(Scp.Z,cont2,'o');
%                             drawnow;
%                         end
%                     end
%                 end
%             end
% 
%             while dZ>=AF.resolution
%                 while cont2>=cont1
%                     cont1=cont2;
%                     new_z = Scp.Z+sgn*dZ;
%                     if (new_z>max_Z)
%                         disp('Too High')
%                         disp(dZ)
%                         disp(new_z)
%                         disp(max_Z)
%                         disp(Zinit)
%                         % Moved To Far go back the other direction
%                         Scp.Z = Zinit;
%                         sgn = -1;
%                     elseif (new_z<min_Z)
%                         disp('Too Low')
%                         disp(dZ)
%                         disp(new_z)
%                         disp(max_Z)
%                         disp(Zinit)
%                         % Moved To Far go back the other direction
%                         Scp.Z = Zinit;
%                         sgn = 1;
%                     else
%                         Scp.Z = new_z;
%                     end
%                     cont2=AF.calcMetric(Scp);
%                     if AF.verbose
%                         figure(157);
%                     end
%                     Zs = [Zs Scp.Z];
%                     Conts = [Conts cont2];
%                     if AF.verbose
%                         plot(Scp.Z,cont2,'o')
%                         drawnow;
%                     end
% 
%                 end
%                 dZ = dZ/2;%acc;
%                 sgn=-sgn;
%                 cont1=cont2;
%             end
%             % Remove Outliers
%             [z,i] = sort(Zs);
%             C = Conts(i);
%             c = medfilt1(Conts(i),5);
%             o = ~isoutlier(abs(c-C));
%             z = z(o);
%             c = c(o);
%             C = C(o);
%             i = i(o);
%             Zfocus = mean(z(C==max(C)));
%             %Zfocus = mean(Zs(Conts==max(Conts)));
%             Scp.Z = Zfocus;
%             contF=AF.calcMetric(Scp);
%         end
% 
%         function Zfocus = localFocusImageScan(AF,Scp)
%             start_z = Scp.Z;
%             % Choose Direction First
%             cont=AF.calcMetric(Scp);
%             Scp.Z = start_z+AF.dZ;
%             cont1=AF.calcMetric(Scp);
%             Scp.Z = start_z-AF.dZ;
%             cont2=AF.calcMetric(Scp);
%             not_finished = true;
%             if cont1>cont
%                 % UP
%                 direction = 1;
%                 cont = cont1;
%                 Scp.Z = start_z+AF.dZ;
%             elseif cont2>cont
%                 % Down
%                 direction = -1;
%                 cont = cont2;
%                 Scp.Z = start_z-AF.dZ;
%             else
%                 % Already There
%                 Zfocus = start_z;
%                 Scp.Z = Zfocus;
%                 not_finished = false;
%             end
%             while not_finished
%                 Scp.Z = Scp.Z+(direction*AF.dZ);
%                 cont1=AF.calcMetric(Scp);
%                 if cont>cont1
%                     % Finished
%                     not_finished = false;
%                     Zfocus = Scp.Z-(direction*AF.dZ);
%                     Scp.Z = Zfocus;
%                 else
%                     % Not There Yet
%                     cont = cont1;
%                 end
%             end
% 
%         end
    end
end
