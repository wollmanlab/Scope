classdef AutoFocusOfTheseus
    properties
        Channel = 'AutoFocus';
        Exposure = 100;
        Background_Limit = 200;
        Limit = 1000;
        Window = 30;
        Step = 0.1;
        start_Z = [];
        dZ = [];
        set_focus = [];
        Verbose = false;
        fine_move_limit = 0.2;
        total_translation_limit = 50;
        total_translation = 0;
        reference_plots = [];
        timeout = 10;
        found_focus = false;
        current_acq = 'default';
        focus_reliquary = containers.Map;
    end
    
    methods
        function current_plot = acquireFocus(AF,Scp)
            Scp.Channel = AF.Channel;
            Scp.Exposure = AF.Exposure;
            img = Scp.snapImage();
            bands = img(AF.Limit:end,:);
            bands = bands - mean(mean(bands(1:AF.Background_Limit,:)));
            current_plot = mean(bands,2);
            current_plot = imgaussfilt(current_plot,5);
        end
        
        function AF = generateReferenceFocus(AF,Scp)
            message = 'Press Ok When Sample Is In Focus';
            uiwait(msgbox(message))
            disp('Generating Reference Focus');
            tic
            AF.dZ = linspace(-AF.Window, AF.Window, 1+(AF.Window+AF.Window)/AF.Step);
            AF.reference_plots = zeros(length(AF.dZ),Scp.Height-AF.Limit+1);
            try
                close(1)
            end
            figure(1)
            hold on
            current_Z = Scp.Z;
            for i = 1:length(AF.dZ)
                Scp.Z = current_Z + AF.dZ(i);
                current_plot = AF.acquireFocus(Scp);
                AF.reference_plots(i,:) = current_plot;
                if i==median(1:length(AF.dZ))
                    AF.set_focus = current_plot;
                else
                    plot(1:length(current_plot),current_plot,'linewidth',0.2,'Color',[(length(AF.dZ)-i)/length(AF.dZ),0,i/length(AF.dZ)])
                end
            end
            plot(1:length(AF.set_focus),AF.set_focus,'linewidth',5,'Color',[0,0,0])
            title(['Reference AutoFocus Plots',newline,'Black is Set Focus'])
            xlabel('Camera Pixel')
            ylabel('AutoFocus Intensity')
            hold off
            Scp.Z = current_Z;
            toc
        end
        
        function [translation,confidence] = calculateTranslation(AF,current_plot)
            % MSE to find translation
            diff = mean(abs(AF.reference_plots-transpose(current_plot)),2);
            diff = imgaussfilt(diff,2);
            [min_diff,idx] = min(diff);
            if AF.Verbose
                figure(3)
                plot(1:length(diff),diff)
            end
            confidence = 1/min_diff;
            translation = -1*AF.dZ(idx);
        end
        
        function AF = findFocus(AF,Scp)
            disp('Finding Focus');
            tic
            AF.start_Z = Scp.Z;
            AF.found_focus = false;
            AF = AF.findFocusIterative(Scp);
            if AF.found_focus
                disp('Focus Found')
            else
                disp('Trying Coarse Focus')
                % AF has a bias to keep going up so start lower than is the
                % likely shift and allow it to drift upwards untill it
                % finds focus
                Scp.Z = AF.start_Z-75;
                og_total_translation_limit = AF.total_translation_limit;
                AF.total_translation_limit = 150;
                AF = AF.findFocusIterative(Scp);
                AF.total_translation_limit = og_total_translation_limit;
                if AF.found_focus
                    disp('Found Focus using Coarse Focus')
                else
                    disp('Interpolating Focus')
                    AF = AF.interpolateFocus(Scp);
                end
            end
            % Add Focus to Found Focus Reliquary
            label=['x_',int2str(Scp.X),'_y_',int2str(Scp.Y)];
            if isKey(AF.focus_reliquary,AF.current_acq)
                current_reliquary = AF.focus_reliquary(AF.current_acq);
            else
                current_reliquary = containers.Map;
            end
            current_reliquary(label) = [Scp.X,Scp.Y,Scp.Z];
            AF.focus_reliquary(AF.current_acq) = current_reliquary;
            toc
        end
        
        function AF = findFocusIterative(AF,Scp)
            disp('Iterative Finding Focus');
            tic
            AF.total_translation = 0;
            not_finished = true;
            while not_finished
                % First Check Focus
                current_plot = AF.acquireFocus(Scp);
                [translation,~] = AF.calculateTranslation(current_plot);
                AF.total_translation = AF.total_translation + translation;
                Scp.Z = Scp.Z+translation;
                disp(['Movement=',sprintf('%.2f',translation),'um']);
                % If Move distance is small then done
                if abs(translation)<AF.fine_move_limit
                    %disp('Focus Found')
                    not_finished = false; % Done
                    AF.found_focus = true;
                else
                    % If total movement is too large revert to coarse
                    if AF.total_translation>AF.total_translation_limit
                        disp(['Total Movement=',sprintf('%.2f',AF.total_translation_limit),'um'])
                        not_finished = false; % Done
                    end
                end
                if toc>AF.timeout
                    disp(['Autofocus Time>',int2str(AF.timeout)]);
                    not_finished = false; % Done
                end
            end
        end
        
%         function AF = findFocusCoarse(AF,Scp)
%             disp('Attempting Coarse Focus');
%             % First Go back to original Z
%             Scp.Z = AF.start_Z;
%             AF.total_translation = 0;
%             % Check Focus at a large range every 5 um
%             coarse_dZ = linspace(-100,100,1+200/20);
%             coarse_confidence = zeros(length(coarse_dZ),1);
%             coarse_translation = zeros(length(coarse_dZ),1);
%             current_Z = Scp.Z;
%             for i=1:length(coarse_dZ)
%                 Scp.Z = current_Z + coarse_dZ(i);
%                 current_plot = AF.acquireFocus(Scp);
%                 %[translation,confidence] = AF.calculateTranslation(current_plot);
%                 coarse_confidence(i) = 1/mean(abs(current_plot-AF.set_focus));
%                 coarse_translation(i) = coarse_dZ(i);
%             end
%             Scp.Z = current_Z;
%             AF.total_translation = 0;
%             % Move to best focus found
%             [~,idx] = max(coarse_confidence);
%             Scp.Z = Scp.Z + coarse_translation(idx);
%             % Do One last autofocus
%             current_plot = AF.acquireFocus(Scp);
%             [translation,~] = AF.calculateTranslation(current_plot);
%             AF.total_translation = coarse_translation(idx) + translation;
%             Scp.Z = Scp.Z + translation;
%             [translation,~] = AF.calculateTranslation(current_plot);
%             AF.total_translation = AF.total_translation + translation;
%             Scp.Z = Scp.Z + translation;
%             % If Move distance is small then done
%             if translation<AF.fine_move_limit
%                 disp('Coarse Focus Found Focus');
%             else
%                 disp('Coarse Focus Failed to find Focus');
%                 AF = AF.interpolateFocus(Scp);
%             end
%         end
        
        function AF = interpolateFocus(AF,Scp)
            if isKey(AF.focus_reliquary,AF.current_acq)==false
                disp('No Reliquary to Interpolate with')
                disp('Using Original Z')
                Scp.Z = Scp.AF.start_Z;
            elseif isempty(AF.focus_reliquary(AF.current_acq))
                disp('Empty Reliquary Unable to Interpolate')
                disp('Using Original Z')
                Scp.Z = Scp.AF.start_Z;
            else
                container = AF.focus_reliquary(AF.current_acq);
                array = zeros(length(container),3);
                key_list = keys(container);
                for i=1:length(container)
                    key = char(key_list(i));
                    array(i,:) = container(key);
                end
                try
                    surface_model = fit([array(:,1) array(:,2)],array(:,3),'poly23');
                    updated_coordinate = surface_model([Scp.X,Scp.Y]);
                catch ME
                    errorMessage = sprintf('Error in myScrip.m.\nThe error reported by MATLAB is:\n\n%s', ME.message);
                    disp(errorMessage);
                    disp('Surface Model Unable to fit');
                    disp('Using Median of Previous Positions')
                    updated_coordinate = median(array(:,3));
                end
                if isnan(updated_coordinate)
                    disp('Using Median of Previous Positions')
                    updated_coordinate = median(array(:,3));
                end
                Scp.Z = updated_coordinate;
            end
        end
        
    end
end