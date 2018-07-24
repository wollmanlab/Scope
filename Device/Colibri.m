classdef Colibri < Device
    %Interface between arduino controlling LED on off and Scope;
    %
    
    properties (Transient = true)
        ard_led
        status
        arduinoTriggerPin
        ledPin
        ledColor
        
    end
    
    methods
        %% initialize the device as a serial interface
        function initialize(self, comport, varargin)
            arg.D8 = 'DeepBlue';
            arg.D9 = 'Green';
            arg.D10 = 'Orange';
            arg.D11 = 'FarRed';
%             arg = parseVarargin(arg);
            self.ard_led = arduino('COM9');
            pause(0.5)
            self.ard_led.configurePin('D8', 'DigitalOutput');
            self.ard_led.configurePin('D9', 'DigitalOutput');
            self.ard_led.configurePin('D10', 'DigitalOutput');
            self.ard_led.configurePin('D11', 'DigitalOutput');
            self.ard_led.writeDigitalPin('D8', 0);
            self.ard_led.writeDigitalPin('D9', 0);
            self.ard_led.writeDigitalPin('D10', 0);
            self.ard_led.writeDigitalPin('D11', 0);
            self.ledPin = 'DeepBlue';
            self.ledColor = 'DeepBlue';
        end
        
        function setActiveLed(self, color)
            switch color
                case 'DeepBlue'
                    self.ledPin = 'D8';
                case 'Green'
                    self.ledPin = 'D9';
                case 'Orange'
                    self.ledPin = 'D10';
                case 'FarRed'
                    self.ledPin = 'D11';
                otherwise
                    disp('Warning color arduino pin mapping not understood.')
                    
            end
            self.ledColor=color;
        end
        
        function changeLedState(self, state)
            self.ard_led.writeDigitalPin(self.ledPin, state);
        end
    end
end
    