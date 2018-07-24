%% Init
clear all
clc
close all

Scp = Scope; 

%% Define critical experiment parameters: 
Username = 'rwollman'; % your OME username!
Project = 'yourProjectName'; % the project this dataset correspond to 
Dataset = 'yourDatasetName'; % the name of this specific image dataset - i.e. this experiment. 

ExperimentID = 11; % the ID you got when you uploaded your experiment (created with the OMERO.editor) to the OMERO database. 

%% define AcqData
AcqData = AcquisitionData; 
AcqData(1).Channel='Cy5'; 
AcqData(1).Exposure=300; 

AcqData(2).Channel='DAPI'; 
AcqData(2).Exposure=300; 

AcqData(3).Channel='FITC'; 
AcqData(3).Exposure=300;

%% define positions to screen 
Plt = Plate('Cosair96 (3904)');
Scp.Chmbr = Plt;  % optional - Scope doesn't have to know what chamebr it has
                  % but it allows it to use the goto(label) function

Scp.goto('A01'); %can goto any Chamber label. 

%% Make sure properties that determine resolution are defined
Scp.Objective = '10x';

%%  create default position list - one site per well entire plate single run
Pos = Plt.createPositions(Scp,'SitesPerWell',[2 2],'Wells',{'A02','B01'});
Pos.circular = false; 
Pos = optimizeOrder(Pos);
plot(Pos,'fig',1);

%% start acqusition
Scp.acqMultiChannelMultiSite(AcqData,Pos,Username,Project,Dataset,ExperimentID);
