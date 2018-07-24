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

%%  create default position list - one site per well entire plate single run
Pos=Positions('DemoPositionList.pos');
Pos.circular = true; 
Pos = optimizeOrder(Pos);
plot(Pos,'fig',1);

%% setup autofocus and its parameters
Pos.axis={'X','Y'}; % disable Z component of position
Scp.mmc.enableContinuousFocus(true)
Scp.mmc.setAutoFocusOffset(40); %% Change offset value here

%% Acquire all sites once
Scp.acqMultiChannelMultiSite(AcqData,Pos,Username,Project,Dataset,ExperimentID,'autofocus',true)

