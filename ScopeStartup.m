%% Startup file - a place to put all microscope / computer
% specific customization. 

%% base path to save images in: 
Scp.basePath = 'C:\Users\rwollman\Downloads\TempData';

%% Colors to channels: 


%% position of different chambers on the stage
Scp.PossibleChambers(1).x0y0 = [0 0];

%% use 96 well plate as default on the fake scope as well
Scp.Chamber = 'Costar96 (3904)';

%% Pixel Size 
% Scp.PixelSizeLookup(1,:) = {'4x',2.5}; 
% Scp.PixelSizeLookup(2,:) = {'10x',1.6};
% Scp.PixelSizeLookup(3,:) = {'20x',0.8}; 
% Scp.PixelSizeLookup(4,:) = {'40x',0.4}; 

