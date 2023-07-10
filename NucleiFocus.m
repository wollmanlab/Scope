classdef NucleiFocus < AutoFocus
    properties
        verbose=true;
        channel = 'DeepBlue';
        exposure = 50;
        Pos = Positions;
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
        metric='sobel_af';
        ticker = 0;
        check_frequency = 0;

        coarse_window = 200;
        coarse_dZ = 20;
        medium_window = 20;
        medium_dZ = 2;
        fine_window = 2;
        fine_dZ = 1;
        smooth = 2;
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

        function Zfocus = ImageBasedCoarseGrainScan(AF,Scp)
            Zfocus = ImageBasedScan(AF,Scp, AF.coarse_window, AF.coarse_dZ);
        end

        function Zfocus = ImageBasedMediumGrainScan(AF,Scp)
            Zfocus = ImageBasedScan(AF,Scp, AF.medium_window, AF.medium_dZ);
        end

        function Zfocus = ImageBasedFineGrainScan(AF,Scp)
            Zfocus = ImageBasedScan(AF,Scp, AF.fine_window, AF.fine_dZ);
        end

        function Zfocus = PrimaryImageBasedScan(AF,Scp)
            tic
            Zfocus = AF.ImageBasedCoarseGrainScan(Scp);
%             img = Scp.snapImage;
            Zfocus = AF.ImageBasedMediumGrainScan(Scp);
%             img = Scp.snapImage;
            Zfocus = AF.ImageBasedFineGrainScan(Scp);
%             img = Scp.snapImage;
            toc
        end

        function Zfocus = SecondaryImageBasedScan(AF,Scp)
            tic
            Zfocus = AF.ImageBasedMediumGrainScan(Scp);
%             img = Scp.snapImage;
            Zfocus = AF.ImageBasedFineGrainScan(Scp);
%             img = Scp.snapImage;
            toc
        end


        function Zfocus = ImageBasedScan(AF,Scp,window,dZ)
%             AF.smooth = dZ;
            zinit = Scp.Z;
            zmax = zinit + window;
            zmin = zinit - window;
            steps = linspace(zmin,zmax,round((zmax-zmin)/dZ));
            score = zeros(length(steps),1);

%             % Turn on Light
%             Scp.mmc.stopSequenceAcquisition()
%             Scp.mmc.startContinuousSequenceAcquisition(0)
%             Scp.ContinousImaging = true;
previous_channel = Scp.Channel;
previous_exposure = Scp.Exposure;
Scp.Channel = AF.channel;
Scp.Exposure = AF.exposure;
% % Set Auto Shutter Off
% Scp.mmc.setAutoShutter(0);
% % Open Shutter (Auto Shutter must be off)
% Scp.mmc.setShutterOpen(1);
            % Calculate Focus Score
            for zindex = 1:length(steps)
                z = steps(zindex);
                Scp.Z = z; 
                score(zindex) = AF.calcMetric(Scp);
            end
            
            Zfocus = mean(steps(score==max(score)));
            Scp.Z = Zfocus;
            img = Scp.snapImage;

%             % Set Auto Shutter On
% Scp.mmc.setAutoShutter(1);
% % Open Shutter (Auto Shutter must be off)
% Scp.mmc.setShutterOpen(0);
%             % Turn off Light
%             Scp.mmc.stopSequenceAcquisition()
%             Scp.ContinousImaging = false;
% figure(707)
%             scatter(steps,score)
            Scp.Channel =  previous_channel;
            Scp.Exposure = previous_exposure;


        end

        function metric = calcMetric(AF,Scp)
            % snap an image
%             Scp.Channel=AF.channel;
%             Scp.Exposure=AF.exposure;
            % False will acq a Z stack per color.
            % Set Auto Shutter Off
            Scp.mmc.setAutoShutter(0);
            % Open Shutter (Auto Shutter must be off)
            Scp.mmc.setShutterOpen(1);
            pause(0.01);
            if AF.resize~=1
                img=imresize(Scp.snapImage, AF.resize);
            else
                img = Scp.snapImage;
            end
            Scp.mmc.setAutoShutter(1);
            % Open Shutter (Auto Shutter must be off)
            Scp.mmc.setShutterOpen(0);
            % calculate metric
            switch lower(AF.metric)
                case 'sobel'
                    hx = fspecial('sobel');
                    hy = fspecial('sobel')';
                    gx=imfilter(img,hx);
                    gy=imfilter(img,hy);
                    metric=mean(hypot(gx(:),gy(:)));
                case 'sobel_af'
                    %img = img(1000:end,:);
                    img = imgaussfilt(img,AF.smooth);
                    bkg = imgaussfilt(img,AF.smooth*10);
                    img = img-bkg;
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