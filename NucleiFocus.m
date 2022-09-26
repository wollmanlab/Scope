classdef NucleiFocus < AutoFocus
    properties
        autofocusTimeout = 3;
        Channel = 'DeepBlue';
        Exposure = 20;
        Background_Limit = 200;
        Limit = 1000;
        Window = 20;
        Step = 1;
        dZ = [];
        fine_move_limit = 0.5;
        total_translation_limit = 50;
        total_translation = 0;
        reference_plots = containers.Map;
        ref_pos_indices = [];
        min_ref = 4;
        max_ref_percent = 10; %
        reference_plane = [];
        manual = false;
        found_focus = false;
    end
    methods
        function AF = checkFocus(AF,Scp,varargin)
            % Interpolate from plane
            %             t0 = now;
            %             while ~AF.found_focus && (now-t0)*24*3600 < AF.autofocusTimeout && AF.total_translation<AF.total_translation_limit
            %                 % First Find Focus and Move
            %                 current_plot = AF.acquireFocus(Scp);
            %                 [translation,~] = AF.calculateTranslation(current_plot);
            %                 AF.total_translation = AF.total_translation + translation;
            %                 Scp.Z = Scp.Z+translation;
            %                 % If Move distance is small then done
            %                 if abs(translation)<AF.fine_move_limit
            %                     AF.foundFocus = true;
            %                 end
            %             end
        end

        function current_plot = acquireFocus(AF,Scp)
            % Calculate distinguising metric for image
            Scp.Channel = AF.Channel;
            Scp.Exposure = AF.Exposure;
            temp = Scp.acqshow;
            Scp.acqshow = 'single';
            img = imgaussfilt(Scp.snapImage,3);
            Scp.acqshow = temp;
            current_plot = prctile(img,95,2);
            current_plot = current_plot-mean(current_plot);
        end

        function focus_z = findFocusReference(AF,Scp,ref_pos)
            t0 = now;
            tic
            Scp.Channel = AF.Channel;
            Scp.Exposure = AF.Exposure;
            while ~AF.found_focus && (now-t0)*24*3600 < AF.autofocusTimeout && AF.total_translation<AF.total_translation_limit
                % First Find Focus and Move
                current_plot = Scp.acquireFocus;
                [translation,~] = AF.calculateTranslation(current_plot,ref_pos);
                AF.total_translation = AF.total_translation + translation;
                Scp.Z = Scp.Z+translation;
                % If Move distance is small then done
                if abs(translation)<AF.fine_move_limit
                    AF.foundFocus = true;
                end
            end
            focus_z = Scp.Z;
            toc
        end

        function focus_z = findFocusDeNovo(AF,Scp)
            aftype = Scp.AutoFocusType;
            Scp.AutoFocusType='none';
            if AF.manual
                message = 'Press Ok When Sample Is In Focus';
                uiwait(msgbox(message))
                focus_z = Scp.Z;
            else
                disp('Finding Focus De Novo')
                tic
                DZ = linspace(-AF.Window, AF.Window, 1+(AF.Window+AF.Window)/AF.Step);
                ref_plots = zeros(length(DZ),1);
                current_Z = Scp.Z;
                for i = 1:length(DZ)
                    Scp.Z = current_Z + DZ(i);
                    temp = Scp.acqshow;
                    Scp.acqshow = 'single';
                    img = Scp.snapImage;%imgaussfilt(Scp.snapImage,3);
                    Scp.acqshow = temp;
                    img = img-median(img);
                    img = img/(prctile(img,75,'all')-prctile(img,25,'all'));
                    current_plot = mean(img(img>5),"all");
                    ref_plots(i,:) = current_plot;
                end
                ref_plots = imgaussfilt(ref_plots,3);
                [~,argmax] = max(ref_plots);
                focus_z = current_Z + DZ(argmax);
                Scp.Z = focus_z; %CHECK
                toc
            end
            Scp.AutoFocusType=aftype;
        end
        function focus_z = findFocusReferenceSmart(AF,Scp)
            aftype = Scp.AutoFocusType;
            Scp.AutoFocusType='none';
            if AF.manual
                message = 'Press Ok When Sample Is In Focus';
                uiwait(msgbox(message))
                focus_z = Scp.Z;
            else
                disp('Finding Focus De Novo Smart')
                t0 = now;
                tic
                Scp.Channel = AF.Channel;
                Scp.Exposure = AF.Exposure;
                window = 5;
                steps = 5;
                AF.total_translation = 0;
                AF.autofocusTimeout = 60;
                Scp.mmc.setAutoShutter(0);
                Scp.mmc.setShutterOpen(1);
                AF.found_focus = false;
                while ~AF.found_focus && (now-t0)*24*3600 < AF.autofocusTimeout && AF.total_translation<AF.total_translation_limit
                    if abs(window/steps)<AF.fine_move_limit
                        AF.found_focus = true;
                    end
                    DZ = linspace(-window,window,steps);%[-window,0,window];
                    ref_plots = zeros(length(DZ),1);
                    current_Z = Scp.Z;
                    for i = 1:length(DZ)
                        Scp.Z = current_Z + DZ(i);
                        Scp.acqshow = 'hybe';
%                         temp = Scp.acqshow;
%                         Scp.acqshow = 'single';
                        
%                         img = imgaussfilt(Scp.snapImage,3);
                        img = Scp.snapImage;
%                         img = edge(Scp.snapImage);
%                         current_plot = sum(img)
%                         Scp.acqshow = temp;
                        img = img-median(img);
                        img = img/(prctile(img,75,'all')-prctile(img,25,'all'));
                        current_plot = mean(img(img>10),"all");
                        ref_plots(i,:) = current_plot;
                    end
%                     ref_plots = imgaussfilt(ref_plots,3);
                    [~,argmax] = max(ref_plots);
                    % Move to best focus
                    AF.total_translation = AF.total_translation + DZ(argmax);
                    focus_z = current_Z + DZ(argmax);
                    Scp.Z = focus_z; %CHECK
                    disp(Scp.Z)
                    disp('idx')
                    disp(argmax)
                    disp('window')
                    disp(window)
                    plot(DZ,ref_plots)
                    if abs(argmax-median(1:numel(DZ)))<=((numel(DZ)-1)/2)-1
                        % best focus is center image
                        % narrow window
                        window = window/2;
                    end
%                     if abs(window/steps)<AF.fine_move_limit
%                         AF.found_focus = true;
%                     end
                end
                focus_z = Scp.Z;
                toc
                Scp.AutoFocusType=aftype;
                Scp.mmc.setAutoShutter(1);
                Scp.mmc.setShutterOpen(0);
            end
        end

            function AF = generateReferenceFocus(AF,Scp)
                disp('Generating Reference Focus')
                % Determine Reference Positions from Scp.Pos
                AF.findReferencePositions(Scp);
                ref_plane = zeros(numel(AF.ref_pos_indices),3);
                % For each Reference Position
                for p=1:numel(AF.ref_pos_indices)
                    ref_idx=AF.ref_pos_indices(p);
                    ref_pos = Scp.Pos.Labels{ref_idx};
                    disp(ref_pos)
                    % Go to that position
                    Scp.goto(Scp.Pos.Labels{ref_idx}, Scp.Pos)
                    pause(5);
                    % Find Focus De Novo
                    focus_z = AF.findFocusDeNovo(Scp);
                    % Save X,Y,focus_z for interpolating
                    ref_plane(p,1:2) = Scp.Pos.List(ref_idx,1:2);
                    ref_plane(p,3) = focus_z;
                    % Acquire Nuclei Vectors for Fine Focus
                    disp('Generating Reference Focus');
                    tic
                    AF.dZ = linspace(-AF.Window, AF.Window, 1+(AF.Window+AF.Window)/AF.Step);
                    ref_plots = zeros(length(AF.dZ),Scp.Height);
                    current_Z = focus_z;
                    for i = 1:length(AF.dZ)
                        Scp.Z = current_Z + AF.dZ(i);
                        current_plot = AF.acquireFocus(Scp);
                        ref_plots(i,:) = current_plot;
                    end
                    Scp.Z = current_Z;
                    toc
                    AF.reference_plots(ref_pos) = ref_plots;
                end
                AF.reference_plane = ref_plane;
            end

            function findReferencePositions(AF,Scp)
                n = round(size(Scp.Pos.List,1)*AF.max_ref_percent/100);
                if n<AF.min_ref
                    n = AF.min_ref;
                end
                AF.ref_pos_indices = randsample(1:size(Scp.Pos.List,1),n,false);
            end

            function [translation,confidence] = calculateTranslation(AF,current_plot,ref_pos)
                % MSE to find translation
                % Convert to dictionary
                diff = mean(abs(AF.reference_plots(ref_pos)-transpose(current_plot)),2);
                diff = imgaussfilt(diff,2);
                [min_diff,idx] = min(diff);
                confidence = 1/min_diff;
                translation = -1*AF.dZ(idx);
            end

            function findReferenceFocus(AF,Scp)
                ref_plane = zeros(numel(AF.ref_pos_indices),3);
                % For each Reference Position
                for p=1:numel(AF.ref_pos_indices)
                    ref_idx=AF.ref_pos_indices(p);
                    ref_pos = Scp.Pos.Labels{ref_idx};
                    % Go to that position
                    Scp.goto(Scp.Pos.Labels{ref_idx}, Scp.Pos)
                    pause(5);
                    % Find Focus Based on Reference
                    focus_z = AF.findFocusReference(Scp,ref_pos);
                    % Update Plane
                    ref_plane(p,1:2) = Scp.Pos.List(ref_idx,1:2);
                    ref_plane(p,3) = focus_z;
                end
                AF.reference_plane = ref_plane;
            end

            function focus_z = interpolateReferencePlane(AF,Scp)
                % Use local reference positions to extrapolate to current
                % position Linear or Non-Linear

            end
        end
end

tic
window = 5;
steps = 1+window*2;
DZ = linspace(-window,window,steps);%[-window,0,window];
ref_plots = zeros(length(DZ),1);
current_Z = Scp.Z;
Scp.mmc.setAutoShutter(0);
Scp.mmc.setShutterOpen(1);
for i = 1:length(DZ)
    Scp.Z = current_Z + DZ(i);
    Scp.acqshow = 'hybe';
    img = Scp.snapImage;
%     img = img-median(img);
%     img = img/(prctile(img,75,'all')-prctile(img,25,'all'));
%     current_plot = mean(img(img>10),"all");
    ref_plots(i,:) = current_plot;
end
Scp.mmc.setAutoShutter(1);
Scp.mmc.setShutterOpen(0);
toc