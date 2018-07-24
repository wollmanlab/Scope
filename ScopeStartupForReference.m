%% Init MM

cd C:/Micro-Manager/Micro-Manager-1.4.15/
import mmcorej.*;
import org.micromanager.*

%% for MM version 1.4.23
Scp.gui = MMStudio(false);
uiwait(msgbox('press when MM finished loading'));
Scp.mmc = Scp.gui.getCore;

%% for MM version 1.4.15
Scp.studio = MMStudioPlugin;
Scp.studio.run('');
button = questdlg('What configuration file did you load?','Configuration selection tool','Nikon','None','Nikon');
if strcmp(button,'Nikon')
    Scp.CameraName = 'Zyla'; 
end
    
Scp.mmc = Scp.studio.getMMCoreInstance;
Scp.gui = Scp.studio.getMMStudioMainFrameInstance;
Scp.acq = Scp.gui.getAcquisitionEngine;
Scp.acq = Scp.gui.getAcquisitionEngine;
Scp.mmc.setChannelGroup('Channel');


%% set the system to save using Multi-image format
% To force MM to use the multi-image-per-file format:
%             T = org.micromanager.acquisition.TaggedImageStorageMultipageTiff(java.lang.String('delme'),java.lang.Boolean(true),org.json.JSONObject());
%             Scp.gui.setImageSavingFormat(T.getClass());

%% To force MM to use the single-image-per-fle format:
try % to
    T = org.micromanager.acquisition.TaggedImageStorageDiskDefault('delme');
    Scp.gui.setImageSavingFormat(T.getClass());
catch %#ok<CTCH>
    warning('Couldn''t set single file as default')
end


%% Scope-startup - runs Nikon-Epi specific configurations
Scp.basePath = 'E:\WollmanLabEpiScopeData';

%% some propeties require knowing the name of the device
if strcmp(button,'Nikon')
    Scp.DeviceNames.Objective = 'TINosePiece';
    Scp.DeviceNames.AFoffset = 'TIPFSOffset';
    Scp.DeviceNames.LightPath = {'TILightPath','Label','Left100', 'Right100'};
    Scp.ScopeName = 'Nikon_epi_0';
end
%% define default color for channels
Scp.ClrArray.Blue = [0 0 1];
Scp.ClrArray.Cyan =  [0 1 1];
Scp.ClrArray.DeepBlue = [0 0 0.5];
Scp.ClrArray.FarRed = [0.5 0 0];
Scp.ClrArray.FuraCaBound = [0.8902    0.3569    0.8471];
Scp.ClrArray.FuraCaFree = [0.8902    0.3569    0.8471];
Scp.ClrArray.Green = [0 1 0];
Scp.ClrArray.Orange =  [1.0000    0.4980    0.1412];
Scp.ClrArray.Red = [1 0 0];
Scp.ClrArray.Yellow = [0 1 1];

%% set default chamber for this microscope - 96 Costar + add properties needed for this scope
Scp.Chamber = Plate('Costar96 (3904)');
Scp.Chamber.x0y0 = [ 49776      -31364];
Scp.Chamber.directionXY = [-1 1];
% 
% Scp.Chamber = Plate('Costar384 (4681)');
% Scp.Chamber.x0y0 = [50973      -37031];
% Scp.Chamber.directionXY = [-1 1];

% Scp.Chamber = Plate('Costar24 (3526)');
% Scp.Chamber.x0y0 = [50055      -29678];
% Scp.Chamber.directionXY = [-1 1];

% Scp.Chamber = Plate('50mm Matek Chamber');
% Scp.Chamber.x0y0 = [ 16616      -14418];
% Scp.Chamber.directionXY = [-1 1];

%% Offsets for different objectives

% Order is acccorting to the Objective Labels
Scp.ObjectiveOffsets.Z = [   0    -19    -8 0 0 0
    19     0  11 0 0 0
    8     -11   0 0 0 0
    zeros(3,6)];
Scp.ObjectiveOffsets.AF = [  0.0  -161.8  -209.9
    161.8    0.0   -48.1
    209.9   48.1    0.0];

% 20x = 5033.125
% 10x = 5022.7
% 4x = 5041.325

%% Autofocus method
Scp.AutoFocusType = 'Hardware';
% Scp.Devices = Diaphragm;
% Scp.Devices.initialize;

%% Flatfield
if strcmp(button,'Nikon')
    Scp.FlatFieldsFileName='E:\WollmanLabEpiScopeData\FlatFieldCorrections\Flatfield.mat';
    Scp.loadFlatFields;
    Scp.CorrectFlatField = true;
    Scp.mmc.setProperty(Scp.DeviceNames.LightPath{1},Scp.DeviceNames.LightPath{2},Scp.DeviceNames.LightPath{3});
end


%% Start ImageJ
Miji;
