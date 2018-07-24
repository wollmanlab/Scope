function [flt,stk] = createFlatFieldImage(Scp,varargin)

%%
arg.iter = 5;
arg.channel = Scp.Channel; 
arg.exposure = Scp.Exposure; 
arg = parseVarargin(varargin,arg); 

Scp.CorrectFlatField = 0; 

XY0 = Scp.XY; 

Scp.Channel = arg.channel; 
Scp.Exposure = arg.exposure; 
stk = zeros(Scp.Height,Scp.Width,arg.iter); 
for i=1:arg.iter
    Scp.XY=XY0+randn(1,2)*Scp.Width.*Scp.PixelSize*0.1; 
    Scp.wait; 
    %%
    img = Scp.snapImage;
    while nnz(img==0) > 0.01*numel(img)
        Scp.Exposure = Scp.Exposure./2; 
        img = Scp.snapImage;
    end
    img = medfilt2(img); 
    stk(:,:,i) = img;
end

flt = median(stk,3); 
flt = flt-100/2^16; 
flt = flt./mean(flt(:)); 