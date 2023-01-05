classdef ContrastPlaneFocus < NucleiFocus
    properties

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
                AF.B = [P(:,1), P(:,2), ones(size(P,1),1)] \ P(:,3);
                Z = [x,y ones(size(1,1),1)]*AF.B;
            end
            Scp.Z = Z;
            AF.foundFocus = true;
        end

        function AF = setupPositions(AF,Scp)
            uiwait(msgbox(['Create Atleast 4 Positions per sample']))
            AF.Pos = Scp.createPositionFromMM;
        end

        function AF = calculateZ(AF,Scp)
            XYZ = zeros(size(AF.Pos.List,1),3);
            XYZ(:,1:2) = AF.Pos.List(:,1:2);
            last_XY = Scp.XY;
            good_labels = 1:size(AF.Pos.Labels,1);
            good_labels = good_labels(AF.Pos.Hidden==0);
            for g=1:size(good_labels,2)
                p=good_labels(g);
                tic
%                 if AF.Pos.Hidden(p)==1
%                     continue
%                 end
                disp([int2str(g),' of ',int2str(size(good_labels,2))])
%                 dist = sqrt(sum((Scp.XY-last_XY).^2));
%                 Scp.goto(AF.Pos.Labels{p}, AF.Pos)
                Scp.XY = AF.Pos.List(p,1:2);
% % % %                 if g==1
% % % %                     % finer precise scan for first position of well
% % % %                     focus = AF.ImageBasedFineScan(Scp);
% % % %                 end

%                 if (p==1)|(dist>AF.distance_thresh)
%                     uiwait(msgbox(['Manually Find Focus First']))
%                 end
%                 last_XY = Scp.XY;
%                 Scp.Z = AF.Pos.List(p,3);
%                 pause(1)
                focus = AF.ImageBasedFocusHillClimb(Scp);
                XYZ(p,3) = focus;
                toc
            end
            if strcmp(AF.Pos.axis{1},'XY')
                AF.Pos.axis = {'X','Y','Z'};
            end
            AF.Pos.List = XYZ;
            AF = AF.updateB();
        end

        function AF = updateZ(AF,Scp)
            tic
            % Go to 10% of positions and update Z 
            good_labels = 1:size(AF.Pos.Labels,1);
            good_labels = good_labels(AF.Pos.Hidden==0);
            n_sites = max([10,round(size(good_labels,1)/4)]);
            sites = randsample(good_labels,n_sites)';

            XYZ = zeros(size(sites,1),3);
            XYZ(:,1:2) = AF.Pos.List(sites,1:2);
            for p=1:size(sites,1)
                disp([int2str(p),' of ',int2str(size(sites,1))])
                Scp.XY = AF.Pos.List(sites(p),1:2);
                pause(1)
                Scp.Z = AF.Pos.List(sites(p),3); 
                focus = AF.ImageBasedFocusHillClimb(Scp);
%                 focus = AF.ImageBasedFocusHillClimb(Scp);
                XYZ(p,3) = focus;
            end
            translation = median(AF.Pos.List(sites,3)-XYZ(:,3));
            AF.Pos.List(:,3) = AF.Pos.List(:,3)-translation;
            toc
        end

        function AF = updateB(AF)
            P = AF.Pos.List;
            AF.B = [P(:,1), P(:,2), ones(size(P,1),1)] \ P(:,3);
        end

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
        
        function Zfocus = iterativeFindFocus(AF,Scp)
            contF = 0;
            AF.iteration = 0;
            Zinit = Scp.Z;
            backup_dZ = AF.dZ;
            while (contF<AF.thresh)&(AF.iteration<AF.max_iterations)
                Scp.Z = Zinit;
                AF.iteration = AF.iteration+1;
                disp(['Iteration',int2str(AF.iteration)])
                [Zfocus,contF] = AF.ImageBasedFocusHillClimb(Scp);
                AF.dZ = 2*AF.dZ; % Try Larger Window
            end
            AF.dZ = backup_dZ;
            if AF.iteration>=AF.max_iterations
                disp('No Focus Found')
                % Focus Wasnt Found
                Zfocus = Zinit;
                Scp.Z = Zinit;
            end
        end

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

        function Zfocus = localFocusImageScan(AF,Scp)
            start_z = Scp.Z;
            % Choose Direction First
            cont=AF.calcMetric(Scp);
            Scp.Z = start_z+AF.dZ;
            cont1=AF.calcMetric(Scp);
            Scp.Z = start_z-AF.dZ;
            cont2=AF.calcMetric(Scp);
            not_finished = true;
            if cont1>cont
                % UP
                direction = 1;
                cont = cont1;
                Scp.Z = start_z+AF.dZ;
            elseif cont2>cont
                % Down
                direction = -1;
                cont = cont2;
                Scp.Z = start_z-AF.dZ;
            else
                % Already There
                Zfocus = start_z;
                Scp.Z = Zfocus;
                not_finished = false;
            end
            while not_finished
                Scp.Z = Scp.Z+(direction*AF.dZ);
                cont1=AF.calcMetric(Scp);
                if cont>cont1
                    % Finished
                    not_finished = false;
                    Zfocus = Scp.Z-(direction*AF.dZ);
                    Scp.Z = Zfocus;
                else
                    % Not There Yet
                    cont = cont1;
                end
            end

        end
    end
end
