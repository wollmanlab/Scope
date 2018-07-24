function AcqData = GUIgetChannels(Scp,varargin)

%% if no input argument get Scp from base
if nargin==0
    Scp = evalin('base', 'Scp');
end

%%
arg.fig=[]; 
arg = parseVarargin(varargin,arg); 

if isempty(arg.fig)
    arg.fig = figure; 
end
figure(arg.fig)
clf
set(arg.fig,'color','w','position',[850 300 500 500],'windowstyle','modal')

%% get data from MM
str = Scp.mmc.getAvailableConfigs('Channel');
AvaliableChannels=cell(str.size,1); for i=1:str.size; AvaliableChannels{i}=char(str.get(i-1)); end
AvaliableChannels=[{''}; AvaliableChannels];

%%
AcqData = AcquisitionData; 
N=6; 
handles = nan(N,3);
for i=1:N
    handles(i,1) = uicontrol('style','popupmenu','string',AvaliableChannels,'position',[25 400-(10+i*50) 80 20],'fontsize',14);
    uicontrol('style','text','string','Channel','fontsize',14,'position',[25 (75+N*50) 80 20]);
    
    handles(i,2) = uicontrol('style','edit','string','','position',[125 400-(20+i*50) 80 20],'fontsize',14);
    uicontrol('style','text','string','Exposure','fontsize',14,'position',[120 (75+N*50) 90 20]);
    
    handles(i,3) = uicontrol('style','edit','string','0','position',[230 400-(20+i*50) 30 20],'fontsize',14);
    uicontrol('style','text','string','dZ','fontsize',14,'position',[230 (75+N*50) 30 20]);
   
    handles(i,4) =  uicontrol('style','edit','string','','position',[300 400-(20+i*50) 80 20],'fontsize',14);
    uicontrol('style','text','string','Fluorophore','fontsize',14,'position',[285 (75+N*50) 110 20]);
    
    handles(i,5) =  uicontrol('style','edit','string','','position',[400 400-(20+i*50) 80 20],'fontsize',14);
    uicontrol('style','text','string','Marker','fontsize',14,'position',[390 (75+N*50) 90 20]);
end

uicontrol('string','Save & Close','callback',@saveAndClose,'position',[200 20 100 30],'fontsize',12)
set(arg.fig,'CloseRequestFcn',@saveAndClose)

waitfor(arg.fig)

%%
    function saveAndClose(~,~,~)
        for ii=1:N
            c=AvaliableChannels{get(handles(ii,1),'value')};
            e=str2double(get(handles(ii,2),'string'));
            f=get(handles(ii,4),'string');
            m=get(handles(ii,5),'string');
            dz = str2double(get(handles(ii,3),'string'));
            if ~isempty(c)
                if isnan(e) || isempty(f) || isempty(m)
                    waitfor(msgbox('Fill all values for each channel'));
                    return
                end
                AcqData(ii).Channel = c;
                AcqData(ii).Exposure = e;
                AcqData(ii).dZ = dz;
                AcqData(ii).Fluorophore = f;
                AcqData(ii).Marker = m;
            end
        end
        delete(arg.fig)
    end
end