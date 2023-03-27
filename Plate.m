classdef Plate < Chamber
    properties
        sz;
        Wells = {};
        x0y0; % position of the upper left well (e.g. A01)
        x1y1; % for determining well dimensions in PDMS
        tform; % an optional transformation that came from plate calibration.
        wellSpacingXY
        wellDimensions
        wellCurvature
        directionXY=[-1 -1];
        Features=struct('Name',{},'XY',{});
        
        %% from the Chamber interface
        type
        numOfsubChambers
        Labels
        Fig = struct('fig',[],'Wells',{});
    end
    
    properties (Dependent)
        Xcenter
        Ycenter
    end
    
    methods
        function P = Plate(type)
            if nargin==0
                type = 'Costar96 (3904)';
            end
            switch type
                case 'Underwood6'
                    P.numOfsubChambers=6;
                    P.type = type;
                    P.sz = [2 3];
                    P.wellDimensions=[32000 32000];
                    P.wellCurvature = [1 1];
                    %P.x0y0 = [ ]; %Has to be determined by Scope stage in ScopeStartup config file
                    P.x0y0 = [42000 -20000]; %FIX P.x0y0 = [40000 -20000]; %FIX
                    P.directionXY = [-1 1];
                    P.wellSpacingXY = [40000 40000];
                    P.Wells = { 'A','D','B','E','C','F'};
               case 'FCS2'
                    P.numOfsubChambers=1;
                    P.type = type;
                    P.sz = [1 1];
                    P.wellDimensions=[25000 25000];
                    P.wellCurvature = [1 1];
                    P.x0y0 = [0 0]; %FIX P.x0y0 = [40000 -20000]; %FIX
                    P.directionXY = [-1 1];
                    P.wellSpacingXY = [40000 40000];
                    P.Wells = { 'M'};
                case 'Costar96 (3904)'
                    P.numOfsubChambers=96;
                    P.type = type;
                    P.sz = [8 12];
                    P.wellDimensions=[6300 6300];
                    P.wellCurvature = [1 1];
                    %P.x0y0 = [ ]; %Has to be determined by Scope stage in ScopeStartup config file
                    P.x0y0 = [49776      -31364];
                    P.directionXY = [-1 1];
                    P.wellSpacingXY = [9020 9020];
                    P.Wells = {  'A01'    'A02'    'A03'    'A04'    'A05'    'A06'    'A07'    'A08'    'A09'    'A10'    'A11'    'A12'
                        'B01'    'B02'    'B03'    'B04'    'B05'    'B06'    'B07'    'B08'    'B09'    'B10'    'B11'    'B12'
                        'C01'    'C02'    'C03'    'C04'    'C05'    'C06'    'C07'    'C08'    'C09'    'C10'    'C11'    'C12'
                        'D01'    'D02'    'D03'    'D04'    'D05'    'D06'    'D07'    'D08'    'D09'    'D10'    'D11'    'D12'
                        'E01'    'E02'    'E03'    'E04'    'E05'    'E06'    'E07'    'E08'    'E09'    'E10'    'E11'    'E12'
                        'F01'    'F02'    'F03'    'F04'    'F05'    'F06'    'F07'    'F08'    'F09'    'F10'    'F11'    'F12'
                        'G01'    'G02'    'G03'    'G04'    'G05'    'G06'    'G07'    'G08'    'G09'    'G10'    'G11'    'G12'
                        'H01'    'H02'    'H03'    'H04'    'H05'    'H06'    'H07'    'H08'    'H09'    'H10'    'H11'    'H12'};
                case 'Costar384 (4681)'
                    P.numOfsubChambers=336;
                    P.type = type;
                    P.sz = [14 24];
                    P.wellDimensions=[2000 2000];
                    P.wellCurvature = [1 1];
                    P.x0y0 = [50973      -37031]; %Has to be determined by Scope stage in ScopeStartup config file
                    P.wellSpacingXY = [4500 4500];
                    P.directionXY=[-1 -1];
                    W=cell(14,24);
                    R='BCDEFGHIJKLMNO';
                    for i=1:14
                        for j=1:24
                            W{i,j}=[R(i) sprintf('%02.0f',j)];
                        end
                    end
                    P.Wells=W;
                    
                case 'BioLite48 (130187)'
                    P.numOfsubChambers=48;
                    P.type = type;
                    P.sz = [6 8];
                    P.wellDimensions=[12000 12000];
                    P.wellCurvature = [1 1];
                    P.x0y0 = [45085      -31676];
                    P.directionXY = [-1 1];
                    P.wellSpacingXY = [12989 12799];
                    P.Wells = {  'A01'    'A02'    'A03'    'A04'    'A05'    'A06'    'A07'    'A08'
                        'B01'    'B02'    'B03'    'B04'    'B05'    'B06'    'B07'    'B08'
                        'C01'    'C02'    'C03'    'C04'    'C05'    'C06'    'C07'    'C08'
                        'D01'    'D02'    'D03'    'D04'    'D05'    'D06'    'D07'    'D08'
                        'E01'    'E02'    'E03'    'E04'    'E05'    'E06'    'E07'    'E08'
                        'F01'    'F02'    'F03'    'F04'    'F05'    'F06'    'F07'    'F08'};
                    
                case 'Costar24 (3526)'
                    P.numOfsubChambers=24;
                    P.type = type;
                    P.sz = [4 6];
                    P.wellDimensions=[15620 15620];
                    P.wellCurvature = [1 1];
                    P.x0y0 = [50055      -29678]; %Has to be determined by Scope stage in ScopeStartup config file
                    P.wellSpacingXY = [19300 19300];
                    P.directionXY=[-1 1];
                    P.Wells = {  'A01'    'A02'    'A03'    'A04'    'A05'    'A06'
                        'B01'    'B02'    'B03'    'B04'    'B05'    'B06'
                        'C01'    'C02'    'C03'    'C04'    'C05'    'C06'
                        'D01'    'D02'    'D03'    'D04'    'D05'    'D06'};
                case 'Costar12 (3513)'
                    % cells in focus at 4416 um
                    P.numOfsubChambers=12;
                    P.type = type;
                    P.sz = [3 4];
                    P.wellDimensions=[15620 15620];
                    P.wellCurvature = [1 1];
                    P.x0y0 = [41000 -26854]; %Change this later
                    P.wellSpacingXY = [26000 26000];
                    P.directionXY = [-1 1];
                    P.Wells = {  'A01'    'A02'    'A03'    'A04'
                        'B01'    'B02'    'B03'    'B04'
                        'C01'    'C02'    'C03'    'C04'};
                case 'Costar6 (3516)'
                    % Focus around 4230 um
                    P.numOfsubChambers=6;
                    P.type = type;
                    P.sz = [2 3];
                    P.wellDimensions=[30000 30000]; %not accurate
                    P.wellCurvature = [1 1];
                    P.x0y0 = [40756      -22344]; %Change this later
                    P.wellSpacingXY = [40000 40000];
                    P.directionXY = [-1 1];
                    P.Wells = {  'A01'    'A02'    'A03'
                        'B01'    'B02'    'B03'};
                case 'ibidi 6-lane 4 sites per lane'
                    P.numOfsubChambers=24;
                    P.type = type;
                    P.sz = [4 6];
                    P.wellDimensions=[3800 2500];
                    P.wellCurvature = [0.2 1];
                    P.x0y0 = []; %Has to be determined by Scope stage in ScopeStartup config file
                    %changed Ryan 7/1
                    P.directionXY = [-1 -1];
                    P.wellSpacingXY = [-8800 3000];
                    P.Wells = {  'L1S1'    'L2S1'    'L3S1'    'L4S1'    'L5S1'    'L6S1'
                        'L1S2'    'L2S2'    'L3S2'    'L4S2'    'L5S2'    'L6S2'
                        'L1S3'    'L2S3'    'L3S3'    'L4S3'    'L5S3'    'L6S3'
                        'L1S4'    'L2S4'    'L3S4'    'L4S4'    'L5S4'    'L6S4'};
                case 'ibidi high-mag'
                    P.numOfsubChambers = 6;
                    P.type = type;
                    P.sz = [1 6];
                    P.directionXY = [-1 1];
                    P.wellDimensions = [3800 2500];
                    P.wellCurvature = [0.2 1];
                    P.x0y0 = [];
                    P.wellSpacingXY = [8800 3000];
                    P.Wells = {'L1' 'L2', 'L3', 'L4', 'L5', 'L6'}; % Ibidi -> L1 .. L6
                    
                case 'ibidi 6-lane center at top'
                    P.numOfsubChambers=6;
                    P.type = type;
                    P.sz = [1 6];
                    P.wellDimensions=[2500 17000];
                    P.wellCurvature = [0 0];
                    P.x0y0 = [24189       -9405]; % define this at the top position you want to image in (assuming you use alignsites = top
                    %changed Ryan 7/1
                    P.directionXY = [-1 -1];
                    %P.wellSpacingXY = [8800 0];
                    P.wellSpacingXY = [12000 0];
                    P.Wells = {  'L1'    'L2'    'L3'    'L4'    'L5'    'L6'};
                case 'ibidi 6-lane'
                    P.numOfsubChambers=24;
                    P.type = type;
                    P.sz = [1 6];
                    P.wellDimensions=[2500 18000];
                    P.wellCurvature = [0 0];
                    %                    P.x0y0 = [23417  700];
                    P.x0y0 = []; % define this at the top position you want to image in (assuming you use alignsites = top
                    %changed Ryan 7/1
                    P.directionXY = [-1 1];
                    P.wellSpacingXY = [9000 0];
                    P.Wells = {  'L1'    'L2'    'L3'    'L4'    'L5'    'L6'};
                    P.Features(1) = struct('Name','TopL1','XY',[22643      -12395]);
                    P.Features(2) = struct('Name','BottomL1','XY',[22643     12395]);
                    P.Features(3) = struct('Name','TopL2','XY',[13843      -12395]);
                    P.Features(4) = struct('Name','BottomL2','XY',[13843      12395]);
                    P.Features(5) = struct('Name','TopL3','XY',[5043      -12395]);
                    P.Features(6) = struct('Name','BottomL3','XY',[5043      12395]);
                    P.Features(7) = struct('Name','TopL4','XY',[-3757      -12395]);
                    P.Features(8) = struct('Name','BottomL4','XY',[-3757      12395]);
                    P.Features(9) = struct('Name','TopL5','XY',[-12557      -12395]);
                    P.Features(10) = struct('Name','BottomL5','XY',[-12557      -12395]);
                    P.Features(11) = struct('Name','TopL6','XY',[-21357 -12395]);
                    P.Features(12) = struct('Name','BottomL6','XY',[-21357 -12395]);
                    
                case 'PTFE glass slide'
                    P.numOfsubChambers=30;
                    P.type = type;
                    P.sz = [3 10];
                    P.wellDimensions=[2000 2000];
                    P.wellCurvature = [1 1];
                    P.x0y0 = []; %Has to be determined by Scope stage in ScopeStartup config file
                    P.wellSpacingXY = [5073 5853]; %needs to be recalibrated each time
                    P.Wells = {  'A01'    'A02'    'A03'    'A04'    'A05'    'A06'    'A07'    'A08'    'A09'    'A10'
                        'B01'    'B02'    'B03'    'B04'    'B05'    'B06'    'B07'    'B08'    'B09'    'B10'
                        'C01'    'C02'    'C03'    'C04'    'C05'    'C06'    'C07'    'C08'    'C09'    'C10'};
                case 'PTFE glass slide vertical'
                    P.numOfsubChambers=30;
                    P.type = type;
                    P.sz = [10 3];
                    P.wellDimensions=[2000 2000];
                    P.wellCurvature = [1 1];
                    P.x0y0 = []; %Has to be determined by Scope stage in ScopeStartup config file
                    P.wellSpacingXY = [5853 5073 ]; %needs to be recalibrated each time
                    P.Wells = {  'A01'    'B01'    'C01'
                        'A02'    'B02'    'C02'
                        'A03'    'B03'    'C03'
                        'A04'    'B04'    'C04'
                        'A05'    'B05'    'C05'
                        'A06'    'B06'    'C06'
                        'A07'    'B07'    'C07'
                        'A08'    'B08'    'C08'
                        'A09'    'B09'    'C09'
                        'A10'    'B10'    'C10'};
                    
                case 'Robs PDMS'
                    P.numOfsubChambers=4;
                    P.type = type;
                    P.sz = [2 2];
                    P.wellDimensions=[7500 7500];
                    P.wellCurvature = [1 1];
                    P.x0y0 = []; %Has to be determined by Scope stage in ScopeStartup config file
                    P.directionXY = [1 1];
                    P.wellSpacingXY = [9000 8500];
                    P.Wells = {  'TL'    'TR'    'BL'    'BR'};
                    
                    
                case 'Evans PDMS'
                    P.numOfsubChambers=1;
                    P.type = type;
                    P.sz = [1 1];
                    P.wellCurvature = [1 1];
                    P.x0y0 = [2212    768]; % change (center)
                    P.wellDimensions=abs([6046       -2696]-[-1622        4233]); % (top left - bot right)
                    P.directionXY = [-1 1];
                    P.wellSpacingXY = [0 0];
                    P.Wells = {'CR'};
                    
                case 'Labtek 8-wells'
                    P.numOfsubChambers=8;
                    P.type = type;
                    P.sz=[4 2];
                    P.wellDimensions=[9000 9000]; % Estimate
                    P.wellCurvature = [1 1];
                    P.directionXY = [-1 -1];
                    P.x0y0 = [21072      -28563]; %Has to be determined by Scope stage in ScopeStartup config file
                    P.wellSpacingXY = [12033 -11631];
                    P.Wells = {'A1' 'A2' 'A3' 'A4' 'B1' 'B2' 'B3' 'B4'};
                case 'Microfluidics Wounding Device Ver 3.0'
                    P.numOfsubChambers = 1;
                    P.type = type;
                    P.sz = [1 1];
                    P.x0y0 = [];
                    P.wellSpacingXY = [0 0];
                    P.Wells = {'uFluidicsDevice'};
                    P.wellDimensions = [4000 4000];
                    P.wellCurvature = [0 0];
                case 'Coverslip'
                    P.numOfsubChambers = 1;
                    P.type = type;
                    P.sz = [1 1];
                    P.x0y0 = [];
                    P.wellSpacingXY = [0 0];
                    P.Wells = {'Coverslip'};
                    P.wellDimensions = [10000 10000];
                    P.wellCurvature = [0 0];
                case 'Frame_Seal_65'
                    % at 1X optivar, the pixel size is 2.2857
                    % 65 uL is 15 mm by 15 mm
                    % 6562 pixels by 6562 pixels is the width
                    % width is 2448 pixels
                    % heigh is 2048 pixels
                    % need a 3x4 image for full sizing
                    P.numOfsubChambers = 12;
                    P.type = type;
                    P.sz = [7 7];
                    P.x0y0 = []; %ask at beginning
                    P.directionXY = [-1 1];
                    P.Wells = {'A1' 'A2' 'A3' 'A4' 'A5' 'A6' 'A7'
                        'B1' 'B2' 'B3' 'B4' 'B5' 'B6' 'B7'
                        'C1' 'C2' 'C3' 'C4' 'C5' 'C6' 'C7'
                        'D1' 'D2' 'D3' 'D4' 'D5' 'D6' 'D7'
                        'E1' 'E2' 'E3' 'E4' 'E5' 'E6' 'E7'
                        'F1' 'F2' 'F3' 'F4' 'F5' 'F6' 'F7'
                        'G1' 'G2' 'G3' 'G4' 'G5' 'G6' 'G7'};
                    P.wellSpacingXY = [2448 2048];
                    P.wellDimensions = [2448 2048];
                    P.wellCurvature = [0 0];
                    % top left position is 22105      -23005
                    % bottom right position is 8254      -10248
                    % different is 13851 -12757
                    % six images by seven images
                    
                    
                case '50mm Matek Chamber'
                    P.numOfsubChambers = 1;
                    P.type = type;
                    P.sz = [6 6];
                    P.x0y0 = [];
                    P.wellSpacingXY = [5000 5000];
                    P.Wells = { 'Pos0' 'Pos1'    'Pos2'    'Pos3'    'Pos4'    'Pos5'    'Pos6'    'Pos7'    'Pos8'    'Pos9'    'Pos10'    'Pos11'    'Pos12'    'Pos13'    'Pos14'    'Pos15'    'Pos16' ...
                        'Pos17'    'Pos18'    'Pos19'    'Pos20'    'Pos21'    'Pos22'    'Pos23'    'Pos24'    'Pos25'    'Pos26'    'Pos27'    'Pos28'    'Pos29'    'Pos30' 'Pos31' 'Pos32' 'Pos33' 'Pos34' 'Pos35'};
                    P.wellDimensions = [5000 5000];
                    P.wellCurvature = [0 0];
                case '4 labtek slides in holder'
                    P.numOfsubChambers=16;
                    P.type = type;
                    P.sz = [4 4];
                    P.wellDimensions=[9000 9000];
                    P.wellCurvature = [0 0];
                    P.x0y0 = [ -17077   21954]; % define this at the top position you want to image in (assuming you use alignsites = top
                    %changed Ryan 7/1
                    P.directionXY = [-1 1];
                    P.wellSpacingXY = [27800 11700];
                    P.Wells = {'S1W1','S2W1','S3W1','S4W1'
                        'S1W2','S2W2','S3W2','S4W2'
                        'S1W3','S2W3','S3W3','S4W3'
                        'S1W4','S2W4','S3W4','S4W4'
                        };
                case 'ProPlate64'
                    P.numOfsubChambers=56;
                    P.type = type;
                    P.sz = [4 14];
                    P.wellDimensions=[3500 3500];
                    P.wellCurvature = [0 0];
                    P.x0y0 = []; %Has to be determined by Scope stage in ScopeStartup config file
                    P.wellSpacingXY = [4500 4500]; %needs to be recalibrated each time
                    P.Wells = {  'A01'    'A02'    'A03'    'A04'    'A05'    'A06'    'A07'    'A08'    'A09'    'A10' 'A11' 'A12' 'A13' 'A14'
                        'B01'    'B02'    'B03'    'B04'    'B05'    'B06'    'B07'    'B08'    'B09'    'B10' 'B11' 'B12' 'B13' 'B14'
                        'C01'    'C02'    'C03'    'C04'    'C05'    'C06'    'C07'    'C08'    'C09'    'C10' 'C11' 'C12' 'C13' 'C14'
                        'D01'    'D02'    'D03'    'D04'    'D05'    'D06'    'D07'    'D08'    'D09'    'D10' 'D11' 'D12' 'D13' 'D14'};
                otherwise
                    error('Unknown plate type - check for typo, or add another plate definition')
            end
            P.Fig(1).Wells = cell(P.sz);
            P.Fig.fig = 999;
        end
        
        function calibratePlateThroughPairs(Plt,MeasuredXY,FeatureNames)
            % identify a transformation for XY points based on sets of
            % features and their XY position.
            assert(numel(FeatureNames)>1,'Must provide at least two features to calibrate')
            assert(size(MeasuredXY,1)==numel(FeatureNames),'Must provide measured XY for each plate Feature used for calibration');
            AllFeatureNames = {Plt.Features.Name};
            assert(all(ismember(FeatureNames,AllFeatureNames)),'Selected features not define in plate configuration')
            AllFeatureXY = cat(1,Plt.Features.XY);
            TheoryXY = AllFeatureXY(ismember(AllFeatureNames,FeatureNames),:);
            Plt.tform = cp2tform(MeasuredXY,TheoryXY,'nonreflective similarity'); %#ok<DCPTF>
        end
        
        function [Xcenter,Ycenter] = getXY(Plt)
            grdx = 0:Plt.wellSpacingXY(1)*Plt.directionXY(1):(Plt.sz(2)-1)*Plt.wellSpacingXY(1)*Plt.directionXY(1);
            grdy = 0:Plt.wellSpacingXY(2)*Plt.directionXY(2):(Plt.sz(1)-1)*Plt.wellSpacingXY(2)*Plt.directionXY(2);
            if ~isempty(grdx)
                Xcenter = Plt.x0y0(1)+grdx;
            else
                Xcenter = Plt.x0y0(1);
            end
            if ~isempty(grdy)
                Ycenter = Plt.x0y0(2)+grdy;
            else
                Ycenter = Plt.x0y0(2);
            end
            Xcenter = repmat(Xcenter(:)',Plt.sz(1),1);
            Ycenter = repmat(Ycenter(:),1,Plt.sz(2));
            if ~isempty(Plt.tform)
                [Xcenter,Ycenter]=tformfwd(Plt.tform,Xcenter,Ycenter);
            end
        end
        
        function Xcenter = get.Xcenter(Plt)
            [Xcenter,~] = getXY(Plt);
        end
        
        function Ycenter = get.Ycenter(Plt)
            [~,Ycenter] = getXY(Plt);
        end
        
        function Labels = get.Labels(Plt)
            Labels = Plt.Wells;
        end
        
        function [dx,dy]=getWellShift(Plt,posalign)
            % TODO verify
            dx=0;
            dy=0;
            switch posalign
                case 'center'
                    % do nothing.
                case 'top'
                    % add
                    dy = -Plt.wellDimensions(2)/2*Plt.directionXY(2);
                case 'bottom'
                    dy= Plt.wellDimensions(2)/2*Plt.directionXY(2);
                case 'left'
                    dx = - Plt.wellDimensions(1)/2*Plt.directionXY(1);
                case 'right'
                    dx = Plt.wellDimensions(1)/2*Plt.directionXY(1);
                otherwise
                    error('Position alignment must be {center/top/bottom/left/right}')
            end
        end
        
        function xy = getXYbyLabel(Plt,label)
            [Xcntr,Ycntr] = Plt.getXY;
            x = Xcntr(ismember(Plt.Labels,label));
            y = Ycntr(ismember(Plt.Labels,label));
            xy=[x(:) y(:)];
        end
        
        function plotHeatMap(Plt,msk,varargin)
            
            if ~isempty(Plt.Fig)
                arg.fig = Plt.Fig(1).fig;
            else
                arg.fig = [];
            end
            arg.colormap = [0 0 0; jet(256)];
            arg = parseVarargin(varargin,arg);
            
            if isempty(arg.fig);
                arg.fig = figure;
                Plt.Fig(1).fig = arg.fig;
            end
            figure(arg.fig)
            set(arg.fig,'colormap',arg.colormap,'NumberTitle','off','Name','Position on plate','Position',[8 557 560 420]);
            Plt.Fig(1).Wells = cell(Plt.sz);
            
            %%
            msk = gray2ind(msk,256)+1;
            clr = arg.colormap;
            
            for i=1:Plt.sz(1)
                for j=1:Plt.sz(2)
                    rct = [Plt.Xcenter(i,j)-Plt.wellDimensions(1)/2 ...
                        Plt.Ycenter(i,j)-Plt.wellDimensions(2)/2 ...
                        Plt.wellDimensions(1:2)];
                    
                    Plt.Fig.Wells{i,j} = rectangle('Position',rct,...
                        'curvature',Plt.wellCurvature,...
                        'facecolor',clr(msk(i,j),:),...
                        'HitTest','off');
                end
            end
            
            ytcklabel=cell(Plt.sz(1),1);
            for i=1:Plt.sz(1)
                strt=uint8(Plt.Labels{1,1}(1))-1;
                ytcklabel{i} = char(strt+i); % assume that we start from A
            end
            
            [xtck,ordr]=sort(Plt.Xcenter(1,:));
            xtcklabel = 1:Plt.sz(2);
            xtcklabel=xtcklabel(ordr);
            
            [ytck,ordr]=sort(Plt.Ycenter(:,1));
            ytcklabel=ytcklabel(ordr);
            
            set(gca,'xtick',xtck,'xticklabel',xtcklabel,'ytick',ytck,'yticklabel',ytcklabel)
            axis xy
            if Plt.directionXY(1)==-1
                set(gca,'XDir','reverse')
            end
            if Plt.directionXY(2)==1
                set(gca,'YDir','reverse')
            end
            axis equal
            
        end
        
    end
end