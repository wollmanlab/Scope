classdef DHT11
    properties
        comPort = 'COM9';
        temp = 0;
        humidity = 0;
        serial;
    end
    methods
        function Sensor = DHT11(comPort)
            Sensor.comPort = comPort;
            try
                Sensor.serial = serialport(Sensor.comPort,9600);
                configureTerminator(Sensor.serial,"CR/LF");
            catch
            end
        end

        function temp = getTemp(Sensor)
            Sensor = Sensor.updateStatus();
            temp = Sensor.temp;
        end

        function humidity = getHumidity(Sensor)
            Sensor = Sensor.updateStatus();
            humidity = Sensor.humidity;
        end

        function Sensor = updateStatus(Sensor)
            flush(Sensor.serial);
            not_completed = true;
            iter = 0;
            max_iter = 100;
            while not_completed & iter<max_iter
                    data = char(readline(Sensor.serial));
                    if ~isempty(data)
                        if data(1) == '+'
                            if data(end) == '*'
                                data = split(data(2:end-1),'%');
                                Sensor.temp = data{2};
                                Sensor.humidity = data{1};
                                not_completed = false;
                            end
                        end
                    end
                    iter = iter+1;
            end
        end

    end

end
