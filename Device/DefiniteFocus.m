classdef DefiniteFocus < Device
    % VFilter is an interface between the VF5 hardware, and the Scope class
    %
    
    properties (Transient = true)
        ard
        status
        arduinoTriggerPin
        referenceFocus
        camera
        pixel_size
        pixel_map
        ledPin
        pumpPin
        
    end
    
    methods
        %% initialize the device as a serial interface
        function initialize(self, comport, arduinoTriggerPin, ledPin, pumpPin)
            self.ard = arduino(comport, 'UNO');
            self.camera = videoinput('gentl')
            src = getselectedsource(self.camera);
            src.ExposureTime = 15*1000; %microseconds units
            triggerconfig(self.camera, 'manual');
            start(self.camera);
            self.arduinoTriggerPin = arduinoTriggerPin;
            self.ledPin = ledPin;
            self.pumpPin = pumpPin;
            self.ard.configurePin(self.arduinoTriggerPin, 'DigitalOutput');
            self.ard.configurePin(ledPin, 'DigitalOutput');
            self.ard.configurePin(pumpPin, 'DigitalOutput');
            self.ard.writeDigitalPin(ledPin, 0);
            self.ard.writeDigitalPin(self.arduinoTriggerPin, 0);
            self.ard.writeDigitalPin(self.pumpPin, 0);
            self.referenceFocus = 0;
            self.pixel_size = -0.0880; % um
            self.pixel_map = [0 0 0];
        end
        
        function [scans z_s, maxCor]= calibrateReferenceFocus(self, scope)
            current_z = scope.Z;
            z_s = [];
            lines = {};
            max_pos = [];
            for z = linspace(-20, 20, 41)
                scope.Z = current_z+z;
                l = self.snapFocus(1);
                [l lp] = self.processLineScan(l);
                lines = cat(1, lines, lp);
                z_s = [z_s scope.Z];
                max_pos = [max_pos lp];
                if ~scope.reduceAllOverheadForSpeed
                    plot(l)
                end
            end
            self.ard.writeDigitalPin(self.arduinoTriggerPin, 0);
            %toc
            %             subplot(3,1,3)
            %
            %             plot(z_s, maxCor)%, 1:101, maxFit
            
            %%
            plot(max_pos)
            coeffs = polyfit(max_pos, z_s, 1)
            pixel_size = coeffs(1); % um units
            self.pixel_size = coeffs(1)
            coeffs = polyfit(max_pos, z_s, 3)
            self.pixel_map = coeffs;
            
        end
        
        function setReferenceFocus(self, focus_type, scope)
            switch focus_type
                case 'scan_z'
                    current_z = scope.Z;
                    lines = {};
                    for z = linspace(-10, 10, 51)
                        scope.Z = current_z+z;
                        l_raw = self.snapFocus(0);
                        [l pos] = self.processLineScan(l_raw);
                        lines = cat(1, lines, l);
                    end
                    self.ard.writeDigitalPin(self.arduinoTriggerPin, 0);
                    self.referenceFocus = lines;
                    scope.Z = current_z;
                case 'single'
                    l_raw = self.snapFocus(1);
                    [l pos] = self.processLineScan(l_raw);
                    self.referenceFocus = pos;
            end
            figure(99)
                subplot(1,2,1)
                plot(l);
                subplot(1,2,2)
                plot(l_raw)
            scope.good_focus_z = [scope.good_focus_z scope.Z];
        end
        
        function [line pos amp] = processLineScan(self, line)
            line = line(400:1100);
            flt = GaussianFit([1, 0, 10], -50:50);
            fr = 1000.*line./sum(line);
            fr = sqrt((fr - filtfilt(flt, 1, fr)).^2);
            line = filtfilt(flt, 1, fr);
            [maxie maxie_i] = max(line);
            stdie = std(line);
            opts = optimset('Display','off');
            beta = lsqcurvefit(@GaussianWithBackgroundFit, [maxie, maxie_i, stdie, 0], 1:length(line), line, [], [], opts);
            pos = beta(2);
            amp = beta(1);
            %GaussianWithBackgroundFit()
        end
        
        function [movement confidence, pos] = checkFocus(self)
            [linescan img] = self.snapFocus(1);
            [line pos amp] = self.processLineScan(linescan);
%             if ~scope.reduceAllOverheadForSpeed
%                 figure(99)
%                 subplot(1,2,1)
%                 plot(line);
%                 subplot(1,2,2)
%                 imagesc(img)
                %shg
%             end
            confidence = amp/median(line);
            ref = self.referenceFocus;
            movement = (self.referenceFocus-pos)*self.pixel_size;
            
        end
        
        %         function [movement confidence] = findFocus(self, current)
        %
        %             switch focus_type
        %                 case 'scan_z'
        %                     for i = 1:size(self.referenceFocus)
        %                     end
        %                 case 'gauss'
        %                     coeffs = [10.2175 98.4356];
        %
        %                 otherwise
        %
        %                     disp('Not implemented')
        %             end
        %         end
        
        function [linescan img] = snapFocus(self, single_snap)
            self.ard.writeDigitalPin(self.arduinoTriggerPin, 1);
            pause(0.2)
            [img finfo] = getsnapshot(self.camera);
            linescan = mean(img(445:450, :));
%             figure(98)
%             plot(linescan)
            if single_snap
                self.ard.writeDigitalPin(self.arduinoTriggerPin, 0);
            end
        end
        
        
        function close(Dev)
            delete(self.camera)
        end
    end
    
end

