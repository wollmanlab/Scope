%% Init
clear all
clc
close all

Scp = Scope;

%% Define critical experiment parameters: 
Scp.Username = 'rwollman'; % your OME username!
Scp.Project = 'yourProjectName'; % the project this dataset correspond to 
Scp.Dataset = 'yourDatasetName'; % the name of this specific image dataset - i.e. this experiment. 

%% define AcqData
AcqData = AcquisitionData; 
AcqData(1).Channel='DAPI'; 
AcqData(1).Exposure=5; 

AcqData(2).Channel='Cy5'; 
AcqData(2).Exposure=5; 

%% create position list
msk = false(8,12);
msk(3:4,1:2)=true; 
Scp.createPositions('msk',msk,'sitesperwell',[2 2]);

%%
Tpnts = Timepoints; 
Tpnts.createEqualSpacingTimelapse('units','min','dt',5);

%% Acquire
Scp.acqMultiChannelMultiSiteTimelapse(AcqData,Pos,Tpnts,'save',false);

