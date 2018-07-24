function [MD,Desc,PathName] = GUIgetMetadata(varargin)


%% set figure
arg.fig=[]; 
arg.fullfilename = ''; 
arg = parseVarargin(varargin,arg); 

if isempty(arg.fig)
    arg.fig = figure; 
end

if ~isempty(arg.fullfilename)
    getDataFromXLS(arg.fullfilename)
    return
end

figure(arg.fig)
clf
set(arg.fig,'color','w','position',[850 300 200 300],'windowstyle','modal') 

%% set two buttons - for xls based / for variable based
st=evalin('base','whos');
tf = strcmp({st.class},'struct'); 
st = {st.name};
st = st(tf); 

st = [{''} st]; 

%%
hmenu = uicontrol('style','popupmenu','string',st,'position',[15 220 160 20],'fontsize',14,'callback',@updateMD);
uicontrol('style','text','string','Choose struct','fontsize',14,'position',[5 250 160 20]);

uicontrol('string','Choose Files','position',[15 70 160 30],'fontsize',14,'callback',@chooseXLS);
uicontrol('style','text','string','OR','fontsize',14,'position',[70 160 40 20]);
uicontrol('style','text','string','Import XLS','fontsize',14,'position',[15 100 160 20]);

uicontrol('string','Save & Close','position',[15 20 160 30],'fontsize',14,'callback',@updateMD);

MD=[]; 
Desc={}; 
waitfor(arg.fig)

%% nested functions

    function updateMD(~,~,~)
        if get(hmenu,'Value') == 1
            waitfor(msgbox('Either choose a struct from the list - or chose a file!'))
            return
        end
        MD = evalin('base',st{get(hmenu,'Value')});
        delete(arg.fig)
    end

    function chooseXLS(~,~,~)
        [FileName,PathName] = uigetfile('*.xls?','Chose XLS / XLSX file with metadata');
        fullfilename = fullfile(PathName,FileName); 
        getDataFromXLS(fullfilename); 
    end

    function getDataFromXLS(fullfilename)
        
        [status,sheets]= xlsfinfo(fullfilename);
        if isempty(status)
            waitfor(msgbox('Not a proper xls file! - please choose again'))
            return
        end
        % remove sheets that say "empty" in them
        sheets(cellfun(@(m) ~isempty(strfind(m,'empty')),sheets))=[]; 
        % read experiment description: 
        desc_ix = ismember(lower(sheets),'description'); 
        [~,~,Desc] = xlsread(fullfilename,sheets{desc_ix}); 
        sheets(desc_ix)=[]; 
        
        WellsWithSomething = cell(numel(sheets),1);
        
        for i=1:numel(sheets)
            [~,txt,raw] = xlsread(fullfilename,sheets{i},'B08:M15');
            WellsWithSomething{i} = find(cellfun(@(m) any(isnan(m)),raw)==0); 
            if isempty(txt)
                MD.(sheets{i})= cell2mat(raw); 
            else
                MD.(sheets{i})=raw; 
            end
            
        end
        if numel(WellsWithSomething)>1 && ~isequal(WellsWithSomething{:})  
            errordlg('There is an error in the excell file - make sure that the well used are the same in all sheets!')
            delete(arg.fig)
            error('There is an error in the excell file - make sure that the well used are the same in all sheets!'); 
        end
        delete(arg.fig)
    end

end
