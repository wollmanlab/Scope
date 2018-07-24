%% Init
clear all
clc
close all

Scp = Scope;

%% Define critical experiment parameters: 
Username = 'rwollman'; % your OME username!
Project = 'yourProjectName'; % the project this dataset correspond to 
Dataset = 'yourDatasetName2'; % the name of this specific image dataset - i.e. this experiment. 

ExperimentID = 11; % the ID you got when you uploaded your experiment (created with the OMERO.editor) to the OMERO database. 

%% define AcqData
AcqData = AcquisitionData; 
AcqData(1).Channel='FarRed'; 
AcqData(1).Exposure=5; 

AcqData(2).Channel='Red'; 
AcqData(2).Exposure=5; 

%% Acquire
Scp.acqMultiChannel(AcqData,Username,Project,Dataset,ExperimentID,'save',false);

