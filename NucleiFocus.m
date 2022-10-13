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
    end
    methods
        function AF = checkFocus(AF,Scp,varargin)
            % Call Imaged Based 
            [Zfocus,~] = ImageBasedFocusHillClimb(AF,Scp); 
            Scp.Z = Zfocus; 
            AF.foundFocus = true;
        end
        
        
        function [Zfocus,contF] = ImageBasedFocusHillClimb(AF,Scp)
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

            acc = dZ^(AF.acceleration);
            cont1=AF.calcMetric(Scp);
            Zs = [Zs Scp.Z];
            Conts = [Conts cont1];

            if AF.verbose
                plot(Scp.Z,cont1,'o')
                hold all
            end
            %determine direction of motion

            Scp.Z = Scp.Z+sgn*dZ;
            cont2=AF.calcMetric(Scp);

            Zs = [Zs Scp.Z];
            Conts = [Conts cont2];
            if AF.verbose
                plot(Scp.Z,cont2,'o')
            end
            if cont2<cont1
                sgn = -sgn;
                Scp.Z  = Scp.Z+2*sgn*dZ;
                cont2=AF.calcMetric(Scp);
                if AF.verbose
                    set(157,'menubar','none','Name','Finding focus by contrast','NumberTitle','off')
                end
                Zs = [Zs Scp.Z];
                Conts = [Conts cont2];
                if AF.verbose
                    plot(Scp.Z,cont2,'o');
                end

                if cont2<cont1
                    dZ=dZ/2;%(acc^2);
%                     dZ=dZ/(acc);
                    Scp.Z = Zinit;%start over with smaller region
                    cont1=AF.calcMetric(Scp);

                    Scp.Z = Scp.Z+sgn*dZ;
                    cont2=AF.calcMetric(Scp);

                    Zs = [Zs Scp.Z];
                    Conts = [Conts cont2];
                    if AF.verbose
                        plot(Scp.Z,cont2,'o')
                    end
                    if cont2<cont1
                        sgn = -sgn;
                        Scp.Z = Scp.Z+2*sgn*dZ;
                        cont2=AF.calcMetric(Scp);
                        Zs = [Zs Scp.Z];
                        Conts = [Conts cont2];
                        if AF.verbose
                            plot(Scp.Z,cont2,'o');
                            drawnow;
                        end
                    end
                end
            end

            while dZ>=AF.resolution
                while cont2>=cont1
                    cont1=cont2;
                    new_z = Scp.Z+sgn*dZ;
                    if (new_z>max_Z)
                        disp('Too High')
                        disp(dZ)
                        disp(new_z)
                        disp(max_Z)
                        disp(Zinit)
                        % Moved To Far go back the other direction
                        Scp.Z = Zinit;
                        sgn = -1;
                    elseif (new_z<min_Z)
                        disp('Too Low')
                        disp(dZ)
                        disp(new_z)
                        disp(max_Z)
                        disp(Zinit)
                        % Moved To Far go back the other direction
                        Scp.Z = Zinit;
                        sgn = 1;
                    else
                        Scp.Z = new_z;
                    end
                    cont2=AF.calcMetric(Scp);
                    if AF.verbose
                        figure(157);
                    end
                    Zs = [Zs Scp.Z];
                    Conts = [Conts cont2];
                    if AF.verbose
                        plot(Scp.Z,cont2,'o')
                        drawnow;
                    end

                end
                dZ = dZ/2;%acc;
                sgn=-sgn;
                cont1=cont2;
            end
            % Remove Outliers
            [z,i] = sort(Zs);
            C = Conts(i);
            c = medfilt1(Conts(i),5);
            o = ~isoutlier(abs(c-C));
            z = z(o);
            c = c(o);
            C = C(o);
            i = i(o);
            Zfocus = mean(z(C==max(C)));
            %Zfocus = mean(Zs(Conts==max(Conts)));
            Scp.Z = Zfocus;
            contF=AF.calcMetric(Scp);
        end

        function metric = calcMetric(AF,Scp)
            % snap an image
            Scp.Channel=AF.channel;
            Scp.Exposure=AF.exposure;
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