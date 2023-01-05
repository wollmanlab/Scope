classdef NucleiFocus < AutoFocus
    properties
        verbose=true;
        channel = 'DeepBlue';
        exposure = 50;
        Pos;
        B;
        dZ = 50;
        max_dZ = 500;
        resolution=1;
        n_neighbors = 10;
        acceleration = 1/5;
        scale = 2;
        resize=1;
        thresh = 1*10^-3;
        iteration = 1;
        max_iterations = 3;
        distance_thresh = 5000;
        metric='Contrast_1D';
        ticker = 0;
        check_frequency = 0;
    end
    methods
        function AF = checkFocus(AF,Scp,varargin)
            if AF.ticker>=AF.check_frequency
                AF.ticker = 0;
            end
            if AF.ticker==0
                % Call Imaged Based
                [Zfocus,~] = ImageBasedFocusHillClimb(AF,Scp);
                Scp.Z = Zfocus;
                AF.foundFocus = true;
            end
            if AF.check_frequency>0
                AF.foundFocus = true;
                AF.ticker = AF.ticker+1;
            end
        end


        function Zfocus = ImageBasedFineScan(AF,Scp)
            if AF.verbose
                figure(158),
                set(158,'menubar','none','Name','Finding focus by contrast','NumberTitle','off')
                clf
            end
            %% Set channels and exposure
            Scp.Channel=AF.channel;
            Scp.Exposure=AF.exposure;
            Zs = [];
            Conts = [];
            Zinit = Scp.Z;
            if AF.verbose
                plot(Zinit, AF.calcMetric(Scp),'o');
                hold all
            end
            max_Z = Zinit+AF.max_dZ;
            min_Z = Zinit-AF.max_dZ;
            dZ = AF.dZ*5;%25*(6.3)^2;
            sgn = 1;
            bottom = (Zinit-dZ);
            top = (Zinit+dZ);
            steps = linspace(bottom,top,round((top-bottom)/AF.resolution));
            for Z=steps
                Scp.Z = Z;
                current_cont = AF.calcMetric(Scp);
                Conts = [Conts current_cont];
                if AF.verbose
                    plot(Z,current_cont,'o');
                end
            end
            contF = max(Conts)
            Zfocus = steps(Conts==contF)
            Scp.Z = Zfocus;
        end

        
        
        function Zfocus = ImageBasedFocusHillClimb(AF,Scp)
            %% Set channels and exposure
            Scp.Channel=AF.channel;
            Scp.Exposure=AF.exposure;
            Zs = [];
            Conts = [];
            if AF.verbose
                figure(157),
                set(157,'menubar','none','Name','Finding focus by contrast','NumberTitle','off')
                clf
            end
            Zinit = Scp.Z;
            max_Z = Zinit+AF.max_dZ;
            min_Z = Zinit-AF.max_dZ;
            dZ = AF.dZ;%25*(6.3)^2;
            sgn = 1;

            option = 1;
            % Zinit
            current_Z = Zinit;
            Zs = [Zs current_Z];
            best_conts = AF.calcMetric(Scp);
            best_Z = current_Z;
            current_cont = best_conts;
            Conts = [Conts current_cont];
            if AF.verbose
                plot(Zs,Conts,'o')
                hold all
            end
            while option<3
                if option == 1
                    % Option 1 scan around point
                    below = best_Z-dZ;
                    above = best_Z+dZ;

                    current_Z = below;
                    Scp.Z = current_Z;
                    Zs = [Zs current_Z];
                    below_conts = AF.calcMetric(Scp);
                    current_cont = below_conts;
                    Conts = [Conts current_cont];
                    if AF.verbose
                        plot(current_Z,current_cont,'o');
                    end
                    current_Z = above;
                    Scp.Z = current_Z;
                    Zs = [Zs current_Z];
                    above_conts = AF.calcMetric(Scp);
                    current_cont = above_conts;
                    Conts = [Conts current_cont];
                    if AF.verbose
                        plot(current_Z,current_cont,'o');
                    end
                    if below_conts>best_conts
                        % move down
                        direction = -1;
                        option = 2;
                        best_Z = below;
                        best_conts=below_conts;
                    elseif above_conts>best_conts
                        % move up
                        direction = 1;
                        option = 2;
                        best_Z = above;
                        best_conts=above_conts;
                    else
                        % shrink window
                        option = 1;
                        dZ = dZ/2;
                        if dZ<AF.resolution
                            % finished
                            option = 3;
                        end
                    end
                else
                    % Option 2 scan past point
                    beyond_Z = best_Z+direction*dZ;
                    if (beyond_Z>max_Z)|(beyond_Z<min_Z)
                        % failed to find focus
                        % go back to Zinit
                        option = 3;
                        current_Z = Zinit;
                        Scp.Z = current_Z;
                        disp('Fine Scan Needed')
                        best_Z = AF.ImageBasedFineScan(Scp);
                        best_conts = 0;
                    else
                        current_Z = beyond_Z;
                        Scp.Z = current_Z;
                        Zs = [Zs current_Z];
                        beyond_conts = AF.calcMetric(Scp);
                        current_cont = beyond_conts;
                        Conts = [Conts current_cont];
                        if AF.verbose
                            plot(current_Z,current_cont,'o');
                        end
                        if beyond_conts>best_conts
                            % going in the right direction keep going
                            option = 2;
                            best_conts = beyond_conts;
                            best_Z = beyond_Z;
                        else
                            % going in the wrong direction go back
                            option = 1;
                            dZ = dZ/2;
                        end
                    end
                end
                Zfocus = best_Z;
                contF = best_conts;
                Scp.Z = Zfocus;
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
%             current_Z = Zinit;
%             max_Z = Zinit+AF.max_dZ;
%             min_Z = Zinit-AF.max_dZ;
%             dZ = AF.dZ;%25*(6.3)^2;
%             sgn = 1;
% 
%             acc = dZ^(AF.acceleration);
%             cont1=AF.calcMetric(Scp);
%             Zs = [Zs current_Z];
%             Conts = [Conts cont1];
% 
%             if AF.verbose
%                 plot(Scp.Z,cont1,'o')
%                 hold all
%             end
%             %determine direction of motion
%             current_Z = current_Z+sgn*dZ;
%             Scp.Z = current_Z;
%             cont2=AF.calcMetric(Scp);
% 
%             Zs = [Zs current_Z];
%             Conts = [Conts cont2];
%             if AF.verbose
%                 plot(current_Z,cont2,'o')
%             end
%             if cont2<cont1
%                 sgn = -sgn;
%                 current_Z = current_Z+2*sgn*dZ;
%                 Scp.Z  = current_Z;
%                 cont2=AF.calcMetric(Scp);
%                 if AF.verbose
%                     set(157,'menubar','none','Name','Finding focus by contrast','NumberTitle','off')
%                 end
%                 Zs = [Zs current_Z];
%                 Conts = [Conts cont2];
%                 if AF.verbose
%                     plot(current_Z,cont2,'o');
%                 end
% 
%                 if cont2<cont1
%                     dZ=dZ/2;%(acc^2);
% 
%                     current_Z = Zinit;
%                     Scp.Z = current_Z;%start over with smaller region
%                     cont1=AF.calcMetric(Scp);
%                     current_Z = current_Z+sgn*dZ;
%                     Scp.Z = current_Z;%Scp.Z+sgn*dZ;
%                     cont2=AF.calcMetric(Scp);
% 
%                     Zs = [Zs current_Z];
%                     Conts = [Conts cont2];
%                     if AF.verbose
%                         plot(current_Z,cont2,'o')
%                     end
%                     if cont2<cont1
%                         sgn = -sgn;
%                         current_Z = current_Z+2*sgn*dZ;
%                         Scp.Z = current_Z;%Scp.Z+2*sgn*dZ;
%                         cont2=AF.calcMetric(Scp);
%                         Zs = [Zs current_Z];
%                         Conts = [Conts cont2];
%                         if AF.verbose
%                             plot(current_Z,cont2,'o');
%                             drawnow;
%                         end
%                     end
%                 end
%             end
% 
%             while dZ>=AF.resolution
%                 while cont2>=cont1
%                     cont1=cont2;
%                     new_z = current_Z+sgn*dZ;
%                     if (new_z>max_Z)
%                         disp('Too High')
%                         disp(dZ)
%                         disp(new_z)
%                         disp(max_Z)
%                         disp(Zinit)
%                         % Moved To Far go back the other direction
%                         current_Z = Zinit;
%                         %Scp.Z = Zinit;
%                         sgn = -1;
%                     elseif (new_z<min_Z)
%                         disp('Too Low')
%                         disp(dZ)
%                         disp(new_z)
%                         disp(max_Z)
%                         disp(Zinit)
%                         % Moved To Far go back the other direction
%                         current_Z = Zinit;
%                         %Scp.Z = Zinit;
%                         sgn = 1;
%                     else
%                         current_Z = new_z;
%                         %Scp.Z = new_z;
%                     end
%                     Scp.Z = current_Z;
%                     cont2=AF.calcMetric(Scp);
%                     if AF.verbose
%                         figure(157);
%                     end
%                     Zs = [Zs current_Z];
%                     Conts = [Conts cont2];
%                     if AF.verbose
%                         plot(current_Z,cont2,'o')
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

        function metric = calcMetric(AF,Scp)
            % snap an image
%             Scp.Channel=AF.channel;
%             Scp.Exposure=AF.exposure;
            % False will acq a Z stack per color.
            if AF.resize~=1
                img=imresize(Scp.snapImage, AF.resize);
            else
                img = Scp.snapImage;
            end
            % calculate metric
            switch lower(AF.metric)
                case 'sobel'
                    hx = fspecial('sobel');
                    hy = fspecial('sobel')';
                    gx=imfilter(img,hx);
                    gy=imfilter(img,hy);
                    metric=mean(hypot(gx(:),gy(:)));
                case 'contrast' 
                    if AF.scale>0
                        m=img-imgaussfilt(img,AF.scale);
                    else
                        m=img;
                    end
                    rng=prctile(m(:),[1 99]);
                    metric=rng(2)-rng(1);
                case 'contrast_1d'
                    img = cat(1,[max(img),max(img')]);
                    if AF.scale>0
                        m=img-imgaussfilt(img,AF.scale);
                    else
                        m=img;
                    end
                    rng=prctile(m(:),[1 99]);
                    metric=rng(2)-rng(1);
            end
        end

    end
end