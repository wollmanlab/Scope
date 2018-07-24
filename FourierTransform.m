function FY = FourierTransform(Y, varargin);
%
% 16.10.07
% A variation of fft for a normal user
% the program expects Y to be a structure with the following fields
% Y.r - the coordinates
% Y.fr - the function
%
%For inverse transform
% Y.q
% Y.fq
%
% varargin:
% '1D' - any function (default)
% '2D' - cylindrically symmetric function (no dependence on Z)
% '3D' - spherically symmetric function
% 'inv2D'
% 
% Other parameters come in pairs
% 'Interpolate'  -----   {Npoints, 'methodString' leftExtrap/optional rightExtrap/optional}: 
%       Npoints a number of points to add per dx interval; 
%       'methodString' describes the method of interpolation (the axes in which the function behaves approximately linearly)
%       e.g. for Gaussian-like function   'methodString' should be 'F = exp(interp1(x.^2, log(f), X.^2));'
%       the method string may include 'extrap' statement for extrapolation (see help interp1),
%       e.g. 'F = exp(interp1(x.^2, log(f), X.^2), 'linear', 'extrap');'
%      then the extrapolation vectors X  on the left: leftExtrap and on the
%      right rightExtrap should be added.
%       if one of these ranges is not used then place brackets [], e.g. 
%                   [I, X, F] = ApproxIntegral(x, f,  'Interpolate', {10   'F = exp(interp1(x.^2, log(f), X.^2, ''linear'', ''extrap''));' []  (1:100)})



if length(varargin) == 0,
    FTtype = 1;
elseif strcmp(varargin{1}, '1D'),
    FTtype = 1;
elseif strcmp(varargin{1}, '2D'),
    FTtype = 2;    
elseif strcmp(varargin{1}, '3D'),
    FTtype = 3;
elseif strcmp(varargin{1}, 'inv2D'),
    FTtype = 4;
else
    errordlg('the fft type parameter is incorrect')
end;

if FTtype < 4,
    Y.r = Y.r(:);
    Y.fr = Y.fr(:);
else
    Y.q = Y.q(:);
    Y.fq = Y.fq(:);
end;

if FTtype == 1,
    % 1D: check that the coordinates have an equal spacing
    dr =diff(Y.r);
    N = length(Y.r);
    dR = (max(Y.r) - min(Y.r))/(N-1);
    
    if abs(max(dr) -min(dr)) >10*eps,   %10 for bug?
        %disp('Warning:distances are not equally spaced: abs(max(dr) -min(dr)) = ');
        %abs(max(dr) -min(dr)) 
        %disp('interpolating the function');
        
        R =  (min(Y.r): dR : max(Y.r))';
        FR = interp1(Y.r, Y.fr, R,  'linear', 'extrap');
    else 
        R = Y.r;
        FR = Y.fr;
    end;
    
    q = (2*pi*(0:(N-1))/(dR*N))';
    
    i = sqrt(-1);
    fq = fft(FR).*exp( - i*q*min(R));
    
    %make q symmetric
    k1 = (1:(N/2+1-0.1))'; % trick to deal with even and odd values of N
    k2 = (ceil(N/2+1):N)';
    FY.q =  [q(k2) - 2*pi/dR; q(k1)];
    FY.fq =  [fq(k2) ; fq(k1)];    
end;

if FTtype == 3,
    % 3D: For FFT distances should be equally spaced starting at half step
    % size, e.g.: r = 0.01:0.02:10
    
    dr =diff(Y.r);
    N = length(Y.r);
    dR = (max(Y.r) - min(Y.r))/(N-1);
    if ~( (abs(max(dr) -min(dr)) < 50*eps) & ( (abs(Y.r(1) - dr(1)/2) < 10*eps) | (abs(Y.r(1)) < 10*eps) )),   %10 for bug?
        disp('Warning:distances are not properly spaced')
        disp('For FFT distances should be equally spaced starting at half step size or at 0, e.g.: r = 0.01:0.02:10 or r = 0:0.02:10')
  
        disp('interpolating the function');
        if ((abs(Y.r(1)) < 10*eps) & (~isinf(Y.fr(1))) & (~isnan(Y.fr(1)))) ,
            R =  (0:(N-1))'*dR;           
        else
            R =  (0:(N-1))'*dR + dR/2;  
        end; 
        FR = interp1(Y.r, Y.fr, R,  'linear', 'extrap');
        
    else 
        R = Y.r;
        FR = Y.fr;
    end;
    
    if abs(R(1)) < 10*eps,
        forFFT = [FR(N:-1:2).*R(N:-1:2);   - FR.*R];
         k=(1:(2*N-1))';
         q = 2*pi*( [k(1:N)-1; 2*N- k((N+1):(2*N-1))])/((2*N-1)*dR);
          i = sqrt(-1);
         fq =imag(fft(forFFT).*exp(pi*i*(k-1)*(2*N-2)/(2*N-1)))./q;
    else
        forFFT = [FR(N:-1:1).*R(N:-1:1);   - FR.*R];
        k=(1:(2*N))'; 
        q = 2*pi*( [k(1:N)-1; 2*N+1- k((N+1):(2*N))])/(2*N*dR);
        
        i = sqrt(-1);
        fq =imag(fft(forFFT).*exp(pi*i*(k-1)*(2*N-1)/(2*N)))./q;
        
        k0 = find(q==0);
        if length(k0) ~=0,
            fq(k0) =  2*sum(FR.*R.^2) ;
        end;
    end;
    
   
    
    FY.q =  q(1:N);
    FY.fq =  fq(1:N);    
end;

if FTtype == 2,
    
    load 'D:\Oleg\Matlab Programming\General Utilities\c.mat';  %for Hankel Transform
    
    N = length(Y.r);
    Rm = max(Y.r);
    c = c(1, 1:N+1);    %Bessel function zeros;
    V = c(N+1)/(2*pi*Rm);    % Maximum frequency
    
    R = c(1:N)'*Rm/c(N+1);   % Radius vector
    v = c(1:N)'/(2*pi*Rm);   % Frequency vector
    
    [Jn,Jm] = meshgrid(c(1:N),c(1:N));
    
    C = (2/c(N+1))*besselj(0, Jn.*Jm/c(N+1))./(abs(besselj(1,Jn)).*abs(besselj(1,Jm)));
    %C is the transformation matrix

    m1 = (abs(besselj(1,c(1:N)))/Rm)';   %% m1 prepares input vector for transformation
    m2 = m1*Rm/V;                            %% m2 prepares output vector for display
    clear Jn
    clear Jm
%end preparations for Hankel transform
    
    FR = interp1(Y.r, Y.fr, R,  'linear', 'extrap');    
    FY.q = 2*pi*v;
   
    FY.fq =   C*(FR./m1).*m2;
    
end;

if FTtype == 4,
    
    load 'D:\Oleg\Matlab Programming\General Utilities\c.mat';  %for Hankel Transform
    
    if length(varargin) >1,
        dr = varargin{2};
        V = 1/(2*dr);
    else
         V = max(Y.q)/(2*pi);
        dr = 1/(2*V)   
    end;
    N = length(Y.q);
   
    c = c(1, 1:N+1);    %Bessel function zeros;
    Rm = c(N+1)/(2*pi*V);    % Maximum radius
    
    R = c(1:N)'*Rm/c(N+1);   % Radius vector
    v = c(1:N)'/(2*pi*Rm);   % Frequency vector
    q = 2*pi*v; 
    
     [Jn,Jm] = meshgrid(c(1:N),c(1:N));
    
    C = (2/c(N+1))*besselj(0, Jn.*Jm/c(N+1))./(abs(besselj(1,Jn)).*abs(besselj(1,Jm)));
    %C is the transformation matrix

    m1 = (abs(besselj(1,c(1:N)))/Rm)';   %% m1 prepares input vector for transformation
    m2 = m1*Rm/V;                            %% m2 prepares output vector for display
    clear Jn
    clear Jm
%end preparations for Hankel transform
    
    FQ = interp1(Y.q, Y.fq, q,  'linear', 'extrap');    
    FY.r = R;
   
    FY.fr =   C*(FQ./m2).*m1;
end;
end