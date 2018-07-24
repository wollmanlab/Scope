%% Initialize Micro-manager within Matlab working environment
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
AcqData(1).Channel='Epi-Blue'; 
AcqData(1).Exposure=100; 

AcqData(2).Channel='Epi-Green'; 
AcqData(2).Exposure=300; 

AcqData(3).Channel='Epi-Red'; 
AcqData(3).Exposure=300;

%% define the timepoints you would image in
Tpnts = Timepoints; 
Tpnts = createEqualSpacingTimelapse(Tpnts,2,10,'units','sec'); 

%%  create a position list - one site per well entire plate single run
Pos=Positions('DemoPositionList.pos');

%% setup autofocus and its parameters
Pos.axis={'X','Y'}; % disable Z component of position
Scp.mmc.enableContinuousFocus(true)
Scp.mmc.setAutoFocusOffset(40); %% Change offset value here

%% Acquire all sites once
% start timer
Tpnts = start(Tpnts); 
% acquire
Scp.acqMultiChannelMultiSiteTimelapse(AcqData,Pos,Tpnts,Username,Project,Dataset,Exp