%% Init
clear all
clc
close all

Scp = Scope; 

%% Define critical experiment parameters: 
Username = 'rwollman'; % your OME username!
Project = 'testProject'; % the project this dataset correspond to 
Dataset = 'yourDatasetName2'; % the name of this specific image dataset - i.e. this experiment. 

ExperimentID = 11; % the ID you got when you uploaded your experiment (created with the OMERO.editor) to the OMERO database. 

%% define AcqData
AcqData = AcquisitionData; 
AcqData(1).Channel='Cy5'; 
AcqData(1).Exposure=300; 

AcqData(2).Channel='DAPI'; 
AcqData(2).Exposure=300; 

AcqData(3).Channel='FITC'; 
AcqData(3).Exposure=300;

%% define Timepoints
Tpnts = Timepoints; 
Tpnts = createEqualSpacingTimelapse(Tpnts,3,1,'units','sec'); 

%% start timelapse
Tpnts = start(Tpnts);
Scp.acqMultiChannelTimeLapse(AcqData,Tpnts,Username,Project,Dataset,ExperimentID);

