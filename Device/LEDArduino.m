classdef LEDArduino < handle
    properties
        serialObj;
        validCommands;
        mapPattern;
        validPatterns;
    end
    
    methods(Access=private)
        % send command 'cmd'
        function sendCommand(s,cmd)
            assert(ismember(cmd,s.validCommands));
            fprintf(s.serialObj, cmd);
            pause(0.01);
        end

        %write 
        function writeToSerial(s,cmd)
            fwrite(s.serialObj,cmd,'uint8');
        end

        
    end

    methods
        function s=LEDArduino(comPort)
            if nargin<1
                comPort='COM11';
            end

            s.validPatterns={'left','right','top','bottom','central','ring', 'crossline'};
            s.mapPattern=containers.Map(s.validPatterns,0:numel(s.validPatterns)-1);

            s.validCommands='arGgvz';

            s.serialObj = serial(comPort,'BaudRate',115200);
            try
                fopen(s.serialObj);
            catch ME
                disp(ME.message);
                fclose(s.serialObj);
                error(['Could not open port: ' comPort]);
            end
        end
        
        % destructor
        function delete(s)
            s.reset();
            fclose(s.serialObj);
        end

        function blink(s,num,d)
            s.writeToSerial(['b' num d]);
        end
        
        function advance(s)
            s.sendCommand('a');
        end
        
        function setPower(s,pwr)
            assert(pwr>=0 && pwr<=255);
            s.writeToSerial(['w' pwr]);
        end

        function turnLED(s, led)
            assert(led>=0 && led<=255);
            s.writeToSerial(['i' led]);
        end
        
        function reset(s)
            s.sendCommand('r');
        end

        function turnLEDsOff(s)
            s.sendCommand('z');
        end

        function turnLEDArray(s,arr)
            assert(numel(arr)>0);
            assert(all(arr)>=0 && all(arr)<=255);
            s.writeToSerial(['l' numel(arr) arr]);
        end

        function turnLEDRange(s,startLED, endLED)
            assert(startLED>=0 && startLED<=255);
            assert(endLED>=0 && endLED<=255);
            assert(endLED>=startLED);
            s.writeToSerial(['c' startLED endLED]);
        end

        function turnLEDPattern(s, pattern)
            
            if ischar(pattern)
                assert(s.mapPattern.isKey(pattern),sprintf('Pattern %s is not a valid pattern', pattern));
                patternInd=s.mapPattern(pattern);
            else
                assert(pattern>=0 && pattern<=numel(s.validPatterns)-1,sprintf('Pattern index must be in the range [0,%d]',numel(s.validPatterns)-1));
                patternInd=pattern;
            end
            s.writeToSerial(['p' patternInd]);
        end
        
        function enableCounter(s)
            s.writeToSerial(['e' 1]);
        end
        
        function disableCounter(s)
            s.writeToSerial(['e' 0]);
        end
        
        function setCounter(s,c)
            s.writeToSerial(['s' c]);
        end

        function sendPatterns(s, LEDs, patterns)
            s.writeToSerial(['n' length(LEDs) length(patterns)]);
            
            % send LEDs
            if(length(LEDs)>20)
                batchSize=20;
                numBatches=ceil(length(LEDs)/batchSize);
                for i=1:numBatches
                    ind=(i-1)*batchSize+1:min(length(LEDs),i*batchSize);
                    s.writeToSerial(['L' length(ind) LEDs(ind)]);
                end
            else
                s.writeToSerial(['L' length(LEDs) LEDs]);
            end

            % send patterns
            patternInd=[];
            for iter=1:numel(patterns)
                if(~s.mapPattern.isKey(patterns{iter}))
                    error('Pattern %s is not a valid pattern',patterns{iter});
                end
                patternInd(end+1)=s.mapPattern(patterns{iter});                 
            end
            s.writeToSerial(['P' length(patternInd) patternInd]);
        end

        function pwr=getPower(s)
            s.sendCommand('G');
            pwr=fread(s.serialObj,1,'uint8');
        end

        function count=getCounter(s)
            s.sendCommand('g');
            count=fread(s.serialObj,1,'uint8');
        end
        
        function sendLEDs(s,A,patterns)
            if nargin<3
                patterns={'left','right','top','bottom','central','ring'};
            end
            if nargin<2
                A=[45    46    47     0     1     2     3;...
                    5     6     7     8     9    10    11;...
                    13    14    15    16    17    18    19;...
                    21    22    23    24    25    26    27;...
                    29    30    31    32    33    34    35;...
                    37    38    39    40    41    42    43;...
                    163   132   133   134   254   254   254;...
                    136   137   138   139   254   254   254;...
                    141   142   143   144   254   254   254;...
                    146   147   148   149   254   254   254;...
                    152   153   154   155   254   254   254;...
                    157   158   159   160   254   254   254;...
                    214   191   192   254   254   254   254;...
                    193   194   195   254   254   254   254;...
                    198   199   200   254   254   254   254;...
                    201   202   203   254   254   254   254;...
                    206   207   208   254   254   254   254;...
                    210   211   212   254   254   254   254];
            end
            [numRows,numCols]=size(A);
            assert (numRows>0 && numCols>0);
            assert(~isempty(patterns));
            s.writeToSerial(['n' numRows numCols length(patterns)]);
            
            % send LEDs
            for i=1:numRows
                s.writeToSerial(['L' A(i,:)]);
            end
            % send patterns
            patternInd=[];
            for iter=1:numel(patterns)
                if(~s.mapPattern.isKey(patterns{iter}))
                    error('Pattern %s is not a valid pattern',patterns{iter});
                end
                patternInd(end+1)=s.mapPattern(patterns{iter});                 
            end
            s.writeToSerial(['P' length(patternInd) patternInd]);
        end

        function status=getInfo(s)
            s.sendCommand('v');
            status.counter=fread(s.serialObj,1,'uint8');
            status.enableFlag=fread(s.serialObj,1,'uint8');
            status.power=fread(s.serialObj,1,'uint8');
            numRows=fread(s.serialObj,1,'uint8');
            numCols=fread(s.serialObj,1,'uint8');
            status.LEDs=zeros(numRows,numCols);
            for i=1:numRows
                status.LEDs(i,:)=fread(s.serialObj,numCols,'uint8');
            end
            numPatterns=fread(s.serialObj,1,'uint8');
            status.patterns=fread(s.serialObj, numPatterns, 'uint8');
        end

        function parseChannel(s, chnl)
            if(strcmp(chnl(1:3),'LED'))
                LED=uint8(str2double(chnl(4:end)));
                s.turnLED(LED);
            elseif length(chnl)>8 && strcmp(chnl(1:7),'CUSTOM_')
                str=chnl(8:end);
                startLED=uint8(str2double(str(1:3)));
                endLED = uint8(str2double(str(5:end)));
                s.turnLEDRange(startLED,endLED);
            elseif length(chnl)>7 && strcmp(chnl(1:6),'ARRAY_')
                str = chnl(7:end);
                s.turnLEDPattern(str);
            elseif length(chnl)== 4 && strcmp(chnl(1:2),'PS') % pizza slice
                A=[45    46    47     0     1     2     3;...
                    5     6     7     8     9    10    11;...
                    13    14    15    16    17    18    19;...
                    21    22    23    24    25    26    27;...
                    29    30    31    32    33    34    35;...
                    37    38    39    40    41    42    43;...
                    163   132   133   134   254   254   254;...
                    136   137   138   139   254   254   254;...
                    141   142   143   144   254   254   254;...
                    146   147   148   149   254   254   254;...
                    152   153   154   155   254   254   254;...
                    157   158   159   160   254   254   254;...
                    214   191   192   254   254   254   254;...
                    193   194   195   254   254   254   254;...
                    198   199   200   254   254   254   254;...
                    201   202   203   254   254   254   254;...
                    206   207   208   254   254   254   254;...
                    210   211   212   254   254   254   254];
                
                ind=uint8(str2double(chnl(3:end)));
                assert(ind>=1 && ind<=18);
                arr=A(ind,:);
                arr(arr==254)=[];
                s.turnLEDArray(arr);
            end
        end
    end
end