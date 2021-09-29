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
        lut = [];
        lut_map = [];
        dfcoords = [];
        deltas = [];
    end
    
    methods
        %% initialize the device as a serial interface
        function initialize(self, comport, arduinoTriggerPin, ledPin, pumpPin)
            self.ard = arduino(comport, 'UNO');
            self.camera = videoinput('gentl')
            src = getselectedsource(self.camera);
            src.ExposureTime = 80*1000; %microseconds units
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
            self.lut = false;
            self.dfcoords = []; % df coordinate of deltas
            self.deltas = []; % 0.1um grid of deltas in units of df coordinates
        end
        
%         function [dfcoords_vector dfcoord_deltas] = mapCoordinateToDistance(self, scope, varargin)
%             arg.movement = 1;
%             arg.numrepeats = 5;
%             arg.dfcoord_vector = linspace(350, 450, 26);
%             arg = parseVarargin(varargin, arg);
%             dfcoord_deltas = [];
%             for dfcoord = arg.dfcoord_vector
%                 disp(dfcoord)
%                 movement = self.focusMove(scope, dfcoord);
%                 pause(0.5)
%                 [movement confidence, pos_starting, pos_local, maxie_i, interp_pos] = self.checkFocus;
%                 scope.Z = scope.Z+arg.movement;
%                 pause(0.5)
%                 avg = [];
%                 for i = 1:arg.numrepeats
%                     [movement confidence, pos_aftermove, pos_local, maxie_i, interp_pos] = self.checkFocus;
%                     avg = [avg pos_aftermove-pos_starting];
%                 end
%                 dfcoord_deltas = [dfcoord_deltas median(avg)]
%             end
%             dfcoords_vector = arg.dfcoord_vector
%         end
        
        function [dfcoords_vector dfcoord_deltas,df_images, bead_images, scope_z] = mapCoordinateToDistance2(self, scope, varargin)
            arg.movement = 0.333;
            arg.numrepeats = 2;
            arg.dfcoord_vector = linspace(325, 450, 26);
            arg = parseVarargin(varargin, arg);
            dfcoord_deltas = [];
            dfcoords_vector = [];
            df_images = {};
            bead_images = [];
            scope_z = [];
            movement = self.focusMove(scope, arg.dfcoord_vector(1));
            current = arg.dfcoord_vector(1);
            [movement confidence, pos_starting, linescan] = self.checkFocus;
            img = scope.snapImage;
            ii=1;
            bead_images{ii} = img;
            scope_z = cat(1, scope_z, scope.Z);
            df_images{ii} = linescan;
            while current < arg.dfcoord_vector(end)
                avg = [];
                for i = 1:arg.numrepeats
                    [movement confidence, pos_starting] = self.checkFocus(scope);
                    avg = [avg pos_starting];
                end
                pos_starting = mean(avg);
                scope.Z = scope.Z-arg.movement;
                pause(0.5)
                avg = [];
                for i = 1:arg.numrepeats
                    [movement confidence, pos_aftermove] = self.checkFocus;
                    avg = [avg pos_aftermove-pos_starting];
                end
                pos_aftermove
                img = scope.snapImage;
                ii=ii+1;
            bead_images{ii} = img;
            scope_z = cat(1, scope_z, scope.Z);
            df_images{ii} = linescan;
                dfcoord_deltas = [dfcoord_deltas mean(avg)];
                current = pos_aftermove;
                dfcoords_vector = [dfcoords_vector current];
            end
            
        end
        
        function total_distance = findDistanceFromReference(self, coords, deltas)
            [movement, confidence, pos] = self.checkFocus()
            total_delta = pos-self.referenceFocus; % if positive pos is below the reference
            total_distance = 0;
            current_delta = abs(total_delta);
            [blank idx] = min(abs(coords-pos));
            %current_delta = current_delta-deltas(idx);
            while abs(current_delta)>1
                
                if total_delta > 0
                    pos = pos - deltas(idx);
                    total_distance  = total_distance + 0.5;
                else
                    pos = pos + deltas(idx);
                    total_distance  = total_distance - 0.5;
                end
                [blank idx] = min(abs(coords-pos));
                current_delta = current_delta-deltas(idx);
            end
        end
        
        function calibratedMove(self, dZ)
            
        end
        
        function [total_movement] = focusMove(self, scope, dfcoord, varargin)
            arg.high_limit = 475;
            arg.low_limit = 300;
            arg.min_movement = 1;
            arg = parseVarargin(varargin, arg);
            if dfcoord>arg.high_limit
                throw(baseException)
            elseif dfcoord < arg.low_limit
                throw(baseException)
            end
            total_movement = 0;
            [movement, confidence, pos] = self.checkFocus(scope);
            dist = dfcoord-pos; % positive means move away from coverslip and negative means move toward coverslip
            while abs(dist) > 0.3
                move = dist*-1*random('uniform', 0.08, 0.09);
                if scope.Z + move > 1.5
                    throw(baseException)
                end
                scope.Z = scope.Z + move;
                total_movement = total_movement+move;
                [movement, confidence, pos] = self.checkFocus(scope);
                dist = dfcoord-pos;
            end
                    
        end
        
        function [z_s, max_pos]= calibrateReferenceFocus(self, scope, varargin)
            arg.tmp = false;
            arg = parseVarargin(varargin, arg);
            current_z = scope.Z;
            z_s = [];
            lines = {};
            max_pos = [];
            for z = linspace(-5, 10, 91)%linspace(-20, 20, 41)
%                 scope.autofocus;
%                 scope.Z = scope.Z+z
                scope.Z = current_z+z;
                pause(0.2)
                l = self.snapFocus(1);
                [line pos amp] = self.processLineScan(l);
                %lines = cat(1, lines, lp);
                z_s = [z_s z];
                max_pos = [max_pos pos];
%                 if ~scope.reduceAllOverheadForSpeed
%                     plot(l)
%                 end
            end
            self.ard.writeDigitalPin(self.arduinoTriggerPin, 0);
            %toc
            %             subplot(3,1,3)
            %
            %             plot(z_s, maxCor)%, 1:101, maxFit
            
            %%
            Scp.Z = current_z;
%             figure(11), hold on
%             plot(z_s, max_pos)
            coeffs_linear = polyfit(max_pos, z_s, 1);
            coeffs = polyfit(max_pos, z_s, 3);
            if ~arg.tmp
                self.pixel_map = coeffs;
                self.pixel_size = coeffs_linear
            end
            %self.interp = 
            
            
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
                    [l pos amp] = self.processLineScan(l_raw);
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
            line = line(400:1000);
flt = GaussianFit([1, 0, 10], -50:50);
fr = 1000.*line./sum(line);
%fr2 = sqrt((fr - filtfilt(flt, 1, fr)).^2);
local_ave = filtfilt(ones(10, 1)/10, 1, fr);
fr = abs(fr-local_ave);
fr = abs(hilbert(fr));
line = filtfilt(flt, 1, fr);

[maxie maxie_i] = max(line);
stdie = std(line);
opts = optimset('Display','off');
beta = lsqcurvefit(@GaussianWithBackgroundFit, [maxie, maxie_i, stdie, 0], 1:length(line), line, [], [], opts);
pos = beta(2);
amp = beta(1);
%             line = line(400:1000);
% flt = GaussianFit([1, 0, 10], -50:50);
% fr = 1000.*line./sum(line);
% fr = sqrt((fr - filtfilt(flt, 1, fr)).^2);
% local_ave = filtfilt(ones(10, 1)/10, 1, fr);
% 
% figure(13), hold on
% plot(fr)
% [peaks cc] = findpeaks(fr, 'MinPeakHeight', 0.1);
% e = zeros(numel(line), 1);
% e(cc) = peaks;
% pos = centerOfMass(e)
% pos = pos(1);
% amp = max(peaks)/min(fr);
% [maxie maxie_i] = max(fr);
% 
% opts = optimset('Display','off');
%             stdie = std(fr);
%             opts = optimset('Display','off');
%             beta = lsqcurvefit(@GaussianWithBackgroundFit, [maxie, maxie_i, stdie, 0], 1:length(line), line, [], [], opts);
%             l = line';
%             N = size(l, 1);
%             X = fftshift(fft(l));
%             X = abs(X);
%             line = X(1:600);
%             figure(12), hold on
%             flt = GaussianFit([1, 0, 4], -20:20);
%             subplot(1,2,1)
% 
%             linef = filtfilt(flt, 1, line);
%             plot(linef)
%            
%             subplot(1,2,2)
%             plot(line/numel(line))
%             pos = 1;
%             amp = 1;
%             flt = GaussianFit([1, 0, 10], -50:50);
%             fr = 1000.*line./sum(line);
%             fr = sqrt((fr - filtfilt(flt, 1, fr)).^2);
%             line = filtfilt(flt, 1, fr);
%             [maxie maxie_i] = max(line);
%             stdie = std(line);
%             opts = optimset('Display','off');
%             beta = lsqcurvefit(@GaussianWithBackgroundFit, [maxie, maxie_i, stdie, 0], 1:length(line), line, [], [], opts);
%             pos = beta(2);
%             amp = beta(1);
% 
%             wdsz = 20;
%             coords = maxie_i-wdsz:maxie_i+1+wdsz;
%             line2 = line(coords);
%             stdie = std(line2);
%             beta_local = lsqcurvefit(@GaussianFit, [maxie, wdsz, stdie], 1:length(line2), line2, [], [], opts);
%             
%             pos_local = beta_local(2)+double(maxie_i);
%             icoords = linspace(maxie_i-wdsz, maxie_i+1+wdsz, 201);
%             v = interp1(maxie_i-wdsz:maxie_i+1+wdsz, line2, icoords);
%             [m, interp_pos] = max(v);
%             interp_pos = icoords(interp_pos);
        end
        
        function [movement, confidence, pos, linescan] = checkFocus(self, Scp, varargin)
            arg.lut = false;
%             arg.lutty = self.pixel_size;
            try
            %arg = parseVarargin(varargin, arg);
            [linescan img] = self.snapFocus(1);
            [line pos amp] = self.processLineScan(linescan);
            confidence = amp/median(line);
            catch
                pause(10)
                Scp.Z = mean(Scp.good_focus_z);
                delete(self.camera)
                self.camera = videoinput('gentl')
                src = getselectedsource(self.camera);
                src.ExposureTime = 80*1000; %microseconds units
                triggerconfig(self.camera, 'manual');
                start(self.camera);
                pause(60)
                [linescan img] = self.snapFocus(1);
                [line pos amp] = self.processLineScan(linescan);
                confidence = amp/median(line);
                if confidence<500
                    Scp.Z = mean(Scp.good_focus_z);
                    pause(5)
                    [linescan img] = self.snapFocus(1);
                    [line pos amp] = self.processLineScan(linescan);
                    confidence = amp/median(line);
                    if confidence<500
                        error('Error during camera snap and low confidence after reinitializing camera')
                    end
                end
            end
%             figure(23), hold on
%             subplot(1,2,1)
%             hold off
            %imshow(img)
%             subplot(1,2,2)
%             plot(line)
%             if ~scope.reduceAllOverheadForSpeed
%                 figure(99)
%                 subplot(1,2,1)
%                 plot(line);
%                 subplot(1,2,2)
%                 imagesc(img)
%                 shg
%             end
            ref = self.referenceFocus;
            func = self.pixel_size;
            if arg.lut
                [blank idx_ref] = min(abs(self.pixel_map-self.referenceFocus));
                ref = arg.lutty(idx_ref);
                [blank idx] = min(abs(self.pixel_map-pos));
                %movement = arg.lutty(idx);
                movement = ref-arg.lutty(idx);
            else
                movement = polyval(func, self.referenceFocus)-polyval(func, pos); %linear
            end
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
        
        function [linescan, img] = snapFocus(self, single_snap)
            self.ard.writeDigitalPin(self.arduinoTriggerPin, 1);
            pause(0.2)
            [img finfo] = getsnapshot(self.camera);
            linescan = mean(img(435:445, :));
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

