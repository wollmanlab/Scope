classdef Kilroy
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    % Interface to Kilroy.py
    % Connect to port 9500 on localhost
    % Send protocols using sendProtocol
    % Wait for BytesAvailable
    % Read
    % close socket
    % Image
    properties
        status
        ipaddress
        port
        socket
    end
    
    methods
%         function initialize(self)
%             self.ipaddress = '127.0.0.1';
%             self.port = 9500
%             self.socket = tcpip('127.0.0.1', 9500);
%             pause(0.5);
%             fopen(self.socket);
%         end
        
        function sendProtocolAndWait(self, protocol)
            self.checkStatus;
            disp(protocol)
            fopen(self.socket);
            fprintf(self.socket, sprintf('{"message_type":"Kilroy Protocol", "message_data": {"name": "%s"}}', protocol));
            disp('Waiting for protocol to finish.')
            start = clock;
            while self.checkStatus
                self.checkStatus;
                fprintf('\n');
                fprintf('Elapsed time waiting: %f', etime(clock, start))
                pause(10);
            end
        end
        
        function status = checkStatus(self)
            if self.socket.BytesAvailable
                status=0;
                fscanf(self.socket)
                fclose(self.socket);
            elseif strcmp(self.socket.Status, 'closed')
                status = 0;
            else
                status = 1;
            end
        end
        function self = set.status(self, stat)
            self.status=stat;
        end
%         function get.status(self)
%             
            
        function close(self)
            fclose(self.socket)
        end
    end
    
end

