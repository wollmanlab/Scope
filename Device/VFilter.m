classdef VFilter < Device
    % VFilter is an interface between the VF5 hardware, and the Scope class
    %   
    
    properties (Transient = true)
        deviceCOM
        status
        wavelength
        buffer
    end
    
    methods
        %% initialize the device as a serial interface
        function initialize(self, comport)
            self.deviceCOM = serial(comport, 'BaudRate', 9600);
            set(self.deviceCOM, 'Terminator', 'CR');
            fopen(self.deviceCOM);
            % Puts device in 'online' mode
            fwrite(self.deviceCOM, 238);
            pause(1)
            fread(self.deviceCOM, self.deviceCOM.BytesAvailable, 'uint8');
            self.status = true;
        end
        
        function wlen = get.wavelength(self)
            if self.deviceCOM.BytesAvailable > 0
                
                fread(self.deviceCOM, self.deviceCOM.BytesAvailable);
            end
            fwrite(self.deviceCOM, 219);
            current = [fread(self.deviceCOM, 11, 'uint8')];
            wlen = current(3)+256*current(4);
        end
        
        function changeWlen(self, bytecode)
            t0 = now;
            bytecode;
            if self.deviceCOM.BytesAvailable>0
                disp('Warning buffer not empty')
                fread(self.deviceCOM, self.deviceCOM.BytesAvailable);
            end
            
            fwrite(self.deviceCOM, bytecode);
            while self.deviceCOM.BytesAvailable<5
                pause(0.025)
            end
            fread(self.deviceCOM, self.deviceCOM.BytesAvailable, 'uint8');
            now-t0;
            pause(0.1)
            
        end
        
        
        function close(Dev)
            fclose(Dev.deviceCOM)
        end
        
        function send(self, code)
        fwrite(self.deviceCOM, code)
        end
        
        
        
    end
    
end