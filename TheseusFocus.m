classdef TheseusFocus < AutoFocus
    properties
        autofocusTimeout = 3;
        Channel = 'AutoFocus';
        Exposure = 100;
        Background_Limit = 200;
        Limit = 1000;
        Window = 30;
        Step = 0.1;
        start_Z = [];
        dZ = [];
        fine_move_limit = 0.2;
        total_translation_limit = 50;
        total_translation = 0;
        reference_plots = [];
    end
    methods
        function AF = checkFocus(AF,Scp,varargin)
            t0 = now;
            while ~AF.found_focus && (now-t0)*24*3600 < AF.autofocusTimeout && AF.total_translation<AF.total_translation_limit
                % First Find Focus and Move
                current_plot = AF.acquireFocus(Scp);
                [translation,~] = AF.calculateTranslation(current_plot);
                AF.total_translation = AF.total_translation + translation;
                Scp.Z = Scp.Z+translation;
                % If Move distance is small then done
                if abs(translation)<AF.fine_move_limit
                    AF.foundFocus = true;
                end
            end
        end
        
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
    end
end