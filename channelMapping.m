function [em_wheel_pos, vf_code, dichro_pos, scopeSettings, led] = channelMapping(dyename)
    % Return a decimal bytecode to sent to 10-3 controller
    % with a VF-5 and emission filter wheel by serial port
    
    % Should return values for set.channel to communicate
    % the proper 10-3 batch code and code to send to umanager
    % to change the reflector turret of the Zeiss Axio to the
    % correct dichroic filter position.
    
    % Calling should first change filter wheel then to 10-3 wait 
    % for 10-3 to confirm then wait for filter wheel then proceed.
    
    % Switch for special
    led = (0);
    if ischar(dyename)
        switch dyename(1:2)
            case 'XL'
                % If dye is long stoke shift+
                % use special code
                if strcmp(dyename, 'XL480')
                    vf_code = [218 1 wlen2code(505)];
                    em_wheel_pos = 5;
                    em_name = 'bp_630';
                    dichro_pos = 3;
                    dichro_name = '59003bs';
                elseif strcmp(dyename, 'XL395')
                    vf_code = [218 1 wlen2code(395)];
                    em_wheel_pos = 5;
                    em_name = 'bp_590_650';
                    dichro_pos = 3;
                    dichro_name = '59003bs';
                end
            case 'sp'
                % Trigger for special case
                % codes
            case 'cy'
                if strcmp(dyename, 'cy5.5')
                vf_code = [222 1 100 0];
                em_wheel_pos = 7;
                em_name = 'bp_695_745';
                dichro_pos = 4;
                dichro_name = 'FF700-Di01';
                led = (1);
%                 elseif
%                     strcmp(dyename, 'cy7')
%                     vf_code = [222 1 100 0];
%                     em_wheel_pos = 6;
%                     dichro_pos = 1;
%                     dichro_name = '408_504_581_667_762';
%                     led = (2);
                elseif strcmp(dyename, 'cy7')
                    vf_code = [222 1 100 0];
                em_wheel_pos = 7;
                em_name = 'pbp_440_521_607_694_809_empty';
                dichro_pos = 1;
                dichro_name = 'pbp_440_521_607_694_809';
                led = (2);
                end
                
            otherwise
                wlen = str2num(dyename);
                wlen = int16(wlen);
                if wlen > 700
                    led = (1);
                    vf_code = [222 1 100 0];
                else
                    vf_code = [218 1 wlen2code(wlen)];
                    led = (0);
%                 elseif wlen >= 630
%                     led = (1);
%                     vf_code = [218 1 wlen2code(wlen)];
%                 elseif wlen <630
%                     led = 0;
%                     vf_code = [218 1 wlen2code(wlen)];
                end
                [em_wheel_pos, em_name, dichro_pos, dichro_name] = lookupEmissionFilter(str2num(dyename));
                  %start_batch    %VF-5   %Wheel-speed-pos %end_batch

        end
    else
        msg = 'dyename should be a char class';
        error(msg)
    end
    scopeSettings = struct('wavelength', dyename, 'emission', em_name, 'dichroic', dichro_name);
end
        

function [em_pos, em_code, dichroic_pos, dichroic_name] = lookupEmissionFilter(wlen)
    %filterMapping = struct('bp_450', 3, 'lp_530', 1, 'lp_570', 9, 'lp_660', 4, 'bp_630', 5, 'open', 2);
%     filterMapping = struct('dbp_440.475_600.650', 0, 'bp_590.650', 1, 'bp_695.745', 2, ...
%         'tbp_425_527_615lp', 3, 'lp_570', 4, 'Empty', 5, 'lp_530', 6, 'Empty', 7, ...
%         'lp_665', 8, 'bp_665.715', 9);
    filterMapping = struct('dbp_440_475_600_650', 5, 'pbp_440_521_607_694_809_empty', 6, 'bp_695_745', 7, ...
        'tbp_425_527_615lp', 8, 'lp_570', 9, 'lp_776', 0, 'Empty1', 1, ...
        'lp_542', 2, 'lp_665', 3, 'lp_520', 4);
    if wlen < 420
        em_code = 'pbp_440_521_607_694_809_empty'; % Wheel position of correct filter
        dichroic_pos = 1;
        dichroic_name = '408_504_581_667_762';
%         
%     elseif wlen >= 470 && wlen <=520
%         em_code = 'tbp_425_527_615lp';
%         dichroic_pos = 5;
%         dichroic_name = '62HE';
        
    elseif wlen >= 470 && wlen <=491
        em_code = 'pbp_440_521_607_694_809_empty';
        dichroic_pos = 1;
        dichroic_name = '408_504_581_667_762';
%         dichroic_name = 'Di02-R514';
        
%     elseif wlen > 490 && wlen <= 522
%         em_code = 'lp_542';
%         dichroic_pos = 6;
%         dichroic_name = 'zt532/600';

    elseif wlen >= 492 && wlen <= 550
        em_code = 'lp_570';
        dichroic_pos = 2;
        dichroic_name = '59007bs';

%     elseif wlen > 550 && wlen <= 568
%         em_code = 'lp_570';
%         dichroic_pos = 1;
%         dichroic_name = '408_504_581_667_762';
        
    elseif wlen > 551 && wlen <= 567
        em_code = 'pbp_440_521_607_694_809_empty';
        dichroic_pos = 1;
        dichroic_name = '408_504_581_667_762';
        
%     elseif wlen > 568 && wlen <= 584
%         em_code = 'dbp_440_475_600_650';
%         dichroic_pos = 3;
%         dichroic_name = '59003bs';
    
    elseif wlen > 584 && wlen <= 636
        em_code = 'lp_665';
        dichroic_pos = 2;
        dichroic_name = '59007bs';
        
    elseif wlen >= 638 && wlen <= 700
        em_code = 'pbp_440_521_607_694_809_empty';
        dichroic_pos = 1;
        dichroic_name = 'unsure';
        led = (1);

    elseif wlen > 700
        em_code = 'pbp_440_521_607_694_809_empty';
        dichroic_pos=1;
        dichroic_name='pentaband';
        led = (1);
        
    else    
        msg = 'No known emission filter for that channel';
        error(msg)
    end
    em_pos = getfield(filterMapping, em_code);
end

function code = wlen2code(wlen)
    word = decimal2binary(wlen, 16, 'left-msb');
    low_order = binary2decimal(word(9:16), 'left-msb');
    high_order = binary2decimal(word(1:8), 'left-msb');
    code = [low_order high_order];
end

function b = de2bi(varargin)
%DE2BI Convert decimal numbers to binary numbers.
%   B = DE2BI(D) converts a nonnegative integer decimal vector D to a
%   binary matrix B. Each row of the binary matrix B corresponds to one
%   element of D. The default orientation of the binary output is
%   Right-MSB; the first element in B represents the lowest bit.
%
%   In addition to the vector input, three optional parameters can be
%   given:
%
%   B = DE2BI(...,N) uses N to define how many digits (columns) are output.
%
%   B = DE2BI(...,N,P) uses P to define which base to convert the decimal
%   elements to.
%
%   B = DE2BI(...,MSBFLAG) uses MSBFLAG to determine the output
%   orientation.  MSBFLAG has two possible values, 'right-msb' and
%   'left-msb'.  Giving a 'right-msb' MSBFLAG does not change the
%   function's default behavior.  Giving a 'left-msb' MSBFLAG flips the
%   output orientation to display the MSB to the left.
%
%   Examples:
%       E = [12; 5];
%
%       A = de2bi(E)                
%       B = de2bi(E,5)
%       C = de2bi(E,[],3)            
%       D = de2bi(E,5,'left-msb')
%
%   See also BI2DE.

%   Copyright 1996-2011 The MathWorks, Inc.

% Typical error checking.
error(nargchk(1,4,nargin,'struct'));

% --- Placeholder for the signature string.
sigStr = '';
msbFlag = '';
p = [];
n = [];

% --- Identify string and numeric arguments
for i=1:nargin
   if(i>1)
      sigStr(size(sigStr,2)+1) = '/';
   end;
   % --- Assign the string and numeric flags
   if(ischar(varargin{i}))
      sigStr(size(sigStr,2)+1) = 's';
   elseif(isnumeric(varargin{i}))
      sigStr(size(sigStr,2)+1) = 'n';
   else
      error(message('comm:de2bi:InvalidArg'));
   end;
end;

% --- Identify parameter signitures and assign values to variables
switch sigStr
   % --- de2bi(d)
   case 'n'
      d		= varargin{1};

	% --- de2bi(d, n)
	case 'n/n'
      d		= varargin{1};
      n		= varargin{2};

	% --- de2bi(d, msbFlag)
	case 'n/s'
      d		= varargin{1};
      msbFlag	= varargin{2};

	% --- de2bi(d, n, msbFlag)
	case 'n/n/s'
      d		= varargin{1};
      n		= varargin{2};
      msbFlag	= varargin{3};

	% --- de2bi(d, msbFlag, n)
	case 'n/s/n'
      d		= varargin{1};
      msbFlag	= varargin{2};
      n		= varargin{3};

	% --- de2bi(d, n, p)
	case 'n/n/n'
      d		= varargin{1};
      n		= varargin{2};
      p  	= varargin{3};

	% --- de2bi(d, n, p, msbFlag)
	case 'n/n/n/s'
      d		= varargin{1};
      n		= varargin{2};
      p  	= varargin{3};
      msbFlag	= varargin{4};

	% --- de2bi(d, n, msbFlag, p)
	case 'n/n/s/n'
      d		= varargin{1};
      n		= varargin{2};
      msbFlag	= varargin{3};
      p  	= varargin{4};

	% --- de2bi(d, msbFlag, n, p)
	case 'n/s/n/n'
      d		= varargin{1};
      msbFlag	= varargin{2};
      n		= varargin{3};
      p  	= varargin{4};

   % --- If the parameter list does not match one of these signatures.
   otherwise
      error(message('comm:de2bi:InvalidArgSeq'));
end;

if isempty(d)
   error(message('comm:de2bi:NoInput'));
end

inType = class(d);
d = double(d(:));
len_d = length(d);

if any(d(:) < 0) || any(~isfinite(d(:))) || ~isreal(d) || ~isequal(floor(d),d)
   error(message('comm:de2bi:InvalidInput'));
end

% Assign the base to convert to.
if isempty(p)
    p = 2;
elseif max(size(p) ~= 1)
   error(message('comm:de2bi:NonScalarBase'));
elseif (~isfinite(p)) || (~isreal(p)) || (floor(p) ~= p)
   error(message('comm:de2bi:InvalidBase'));
elseif p < 2
   error(message('comm:de2bi:BaseLessThan2'));
end;

% Determine minimum length required.
tmp = max(d);
if tmp ~= 0 				% Want base-p log of tmp.
   ntmp = floor( log(tmp) / log(p) ) + 1;
else 							% Since you can't take log(0).
   ntmp = 1;
end

% This takes care of any round off error that occurs for really big inputs.
if ~( (p^ntmp) > tmp )
   ntmp = ntmp + 1;
end

% Assign number of columns in output matrix.
if isempty(n)
   n = ntmp;
elseif max(size(n) ~= 1)
   error(message('comm:de2bi:NonScalarN'));
elseif (~isfinite(n)) || (~isreal(n)) || (floor(n) ~= n)
   error(message('comm:de2bi:InvalidN'));
elseif n < ntmp
   error(message('comm:de2bi:SmallN'));
end

% Check if the string msbFlag is valid.
if isempty(msbFlag)
   msbFlag = 'right-msb';
elseif ~(strcmp(msbFlag, 'right-msb') || strcmp(msbFlag, 'left-msb'))
   error(message('comm:de2bi:InvalidMsbFlag'));
end

% Initial value.
b = zeros(len_d, n);

% Perform conversion.
%Vectorized conversion for P=2 case
if(p==2)
    [~,e]=log2(max(d)); % How many digits do we need to represent the numbers?
    b=rem(floor(d*pow2(1-max(n,e):0)),p);
    if strcmp(msbFlag, 'right-msb')
        b = fliplr(b);
    end;
else
    for i = 1 : len_d                   % Cycle through each element of the input vector/matrix.
        j = 1;
        tmp = d(i);
        while (j <= n) && (tmp > 0)     % Cycle through each digit.
            b(i, j) = rem(tmp, p);      % Determine current digit.
            tmp = floor(tmp/p);
            j = j + 1;
        end;
    end;
    % If a msbFlag is specified to flip the output such that the MSB is to the left.
    if strcmp(msbFlag, 'left-msb')
        b2 = b;
        b = b2(:,n:-1:1);
    end;
end;

b = feval(inType, b);   % data type conversion

end
% [EOF]
