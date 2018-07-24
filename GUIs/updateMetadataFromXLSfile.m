function updateMetadataFromXLSfile

%% Chose XLS file path
MDstruct = GUIgetMetadata;
fields=fieldnames(MDstruct); 

%% Choose the dataset path
pth=uigetdir(pwd,'Choose Dataset pth');

%% find Metadata files in this path
if ispc
    str=dirrec(pth,'Metadata*'); 
    MDfiles=regexprep(str,'Metadata.mat',''); 
else
    [~,str]=system(sprintf('find %s -name Metadata.mat',pth)); 
    str=regexprep(str,'Metadata.mat',''); 
    MDfiles=regexp(str,'\n','split');
end
MDfiles(cellfun(@isempty,MDfiles))=[]; 

%% create a Plate object for well names
Plt=Plate; 

%% change all the information in each Metadata files
for i=1:numel(MDfiles)
    MD=Metadata(MDfiles{i}); 
    %% update all metadata in this file
    for j=1:numel(fields)
        %% convert numerical matrix to cell if needed not to worry later-on
        if ~iscell(MDstruct.(fields{j})) 
            MDstruct.(fields{j})=num2cell(MDstruct.(fields{j})); 
        end
        ix=find(~cellfun(@ (m) any(isnan(m)),MDstruct.(fields{j})));  
        for p=1:numel(ix)
            indxOfImagesInPosition=MD.getIndex({'Position'},{Plt.Wells(ix(p))}); 
            MD.addToImages(indxOfImagesInPosition,fields{j},MDstruct.(fields{j}){ix(p)}); 
        end
    end
    MD.saveMetadata; 
end