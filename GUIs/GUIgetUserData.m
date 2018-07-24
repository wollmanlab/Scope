function GUIgetUserData(Scp,varargin)


%%
arg.fig=[]; 
arg = parseVarargin(varargin,arg); 

if isempty(arg.fig)
    arg.fig = figure; 
end
figure(arg.fig)
clf
set(arg.fig,'color','w','position',[850 300 300 300]) %,'windowstyle','modal'

usr = dir(Scp.basePath); 
usr(~[usr.isdir])=[]; 
usr = usr(3:end); 
usr={usr.name}; 
usr=[{''}; usr(:)];

hUser = uicontrol('style','popupmenu','string',usr,'callback',@updateProjects,'position',[120 200 100 30],'fontsize',14); 
uicontrol('style','text','position',[20 200 100 30],'string','Username','fontsize',14);

prj = {''}; 
hPrj = uicontrol('style','popupmenu','string',prj,'position',[120 150 100 30],'fontsize',14); 
uicontrol('style','text','position',[20 150 100 30],'string','Project','fontsize',14);

hDset = uicontrol('style','edit','string','','position',[120 100 170 30],'fontsize',12); 
uicontrol('style','text','position',[20 100 80 30],'string','Dataset','fontsize',14);

uicontrol('string','Save and Close','callback',@saveAndClose,'fontsize',14,'Position',[60 30 150 30])

waitfor(arg.fig)

    function updateProjects(~,~,~)
        prj = dir(fullfile(Scp.basePath,usr{get(hUser,'Value')})); 
        prj(~[prj.isdir])=[]; 
        prj = prj(3:end); 
        prj={prj.name};
        prj = [{''}; prj(:)];
        set(hPrj,'String',prj);
    end

    function saveAndClose(~,~,~)
        curruser = usr{get(hUser,'Value')}; 
        if isempty(curruser)
            waitfor(msgbox('Please choose a username!'))
            return
        end
        Scp.Username = curruser; 

        currprj = prj{get(hPrj,'Value')};
        if isempty(currprj)
            waitfor(msgbox('Please choose a project!'))
            return
        end
        Scp.Project = currprj; 
        
        dset = get(hDset,'string');
        if isempty(dset)
            waitfor(msgbox('Please enter a dataset name!'))
            return
        end
        Scp.Dataset=dset; 
        delete(arg.fig);
    end

end