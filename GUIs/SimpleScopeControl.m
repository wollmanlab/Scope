function SimpleScopeControl

% get the Scp object and if missing create it in the base workspace
try
    Scp = evalin('base', 'Scp');
catch %#ok<CTCH>
    Scp = IncuScope;
    assignin('base', 'Scp',Scp)
end

Pos = []; 
Tpnts = []; 
AcqData = []; 
MD = []; 

figure(1)
clf
set(1,'position',[ 150   200   600   600]);

hPositions = uicontrol('string','CRISP','BackgroundColor','m','callback',@CrispPlugin,'position',[50 500 150 100],'fontsize',20);

hPositions = uicontrol('string','Position','BackgroundColor','m','callback',@getPositions,'position',[50 350 150 100],'fontsize',20);

hTimepoints = uicontrol('string','Timepoints','BackgroundColor','m','callback',@getTimepoints,'position',[225 350 150 100],'fontsize',20);

Actions = {'Acquire T(S)','Acquire S(T)','Kill'};
hAction = uicontrol('style','popupmenu','string',Actions,'position',[400 325 150 100],'fontsize',16,'value',1);

hMetadata = uicontrol('string','Metadata','BackgroundColor','r','callback',@getMetadata,'position',[50 200 150 100],'fontsize',20);
gotMetadata = false; 

hChannels = uicontrol('string','Channels','BackgroundColor','r','callback',@getChannels,'position',[225 200 150 100],'fontsize',20);
gotChannels = false; 

hUserdata = uicontrol('string','Userdata','BackgroundColor','r','callback',@getUserdata,'position',[400 200 150 100],'fontsize',20);
gotUserdata = false; 

% avaliableObj = Scope.java2cell(Scp.mmc.getAllowedPropertyValues(Scp.DeviceNames.Objective,'Label')); 
avaliableObj = {'4x','10x','20x','10Xnew'};

v=find(cellfun(@(s) ~isempty(strfind(Scp.Objective,s)),avaliableObj));

hObj = uicontrol('style','popupmenu','string',avaliableObj,'position',[50 50 150 100],'fontsize',20,'value',v,'callback',@changeObj);

fDiaphragm = @(~,~,~) GUIadjustDiaphragmToTargetSize(Scp); 

uicontrol('string','Diaphragm','callback',fDiaphragm,'position',[50 50 150 40],'fontsize',15)

uicontrol('string','Navigate','BackgroundColor','c','callback',@SimpleScopeNavigation,'position',[225 50 150 100],'fontsize',20);

uicontrol('string','Run','BackgroundColor',[ 1.0000    0.6275         0],'callback',@run,'position',[400 50 150 100],'fontsize',20);


%% Nested functions

    function changeObj(~,~,~)
        Scp.Objective = avaliableObj{get(hObj,'Value')}; 
        Scp.mmc.waitForDevice(Scp.DeviceNames.Objective);
    end

    function getPositions(~,~,~)
        if ~gotMetadata
            waitfor(msgbox('Please load Metadata first before defining positions'))
            return
        end
        figure(2)
        set(2,'position',[850 300 600 400])
        markPlatePosition(Scp,'fig',2,'experimentdata',MD);
        set(hPositions,'BackgroundColor','g');
    end

    function getChannels(~,~,~)
        figure(2)
        set(2,'position',[850 300 300 400])
        AcqData = GUIgetChannels(Scp,'fig',2);
        set(hChannels,'BackgroundColor','g');
        gotChannels = true; 
    end

    function getMetadata(~,~,~)
        figure(2)
        set(2,'position',[850 300 600 400])
        [MD,Desc] = GUIgetMetadata(Scp,'fig',2); 
        Scp.ExperimentDescription = Desc; 
        waitfor(2);
        if ~isempty(MD)
            set(hMetadata,'BackgroundColor','g');
            gotMetadata = true;
        end
    end

    function getUserdata(~,~,~)
        GUIgetUserData(Scp,'fig',2)
        set(hUserdata,'BackgroundColor','g');
        gotUserdata = true;
    end

    function getTimepoints(~,~,~)
        figure(2)
        set(2,'position',[850 300 600 400])
        Tpnts = GUIgetTimepoints('fig',2); 
        if ~isempty(Tpnts.T)
            Scp.Tpnts=Tpnts;
            set(hTimepoints,'BackgroundColor','g');
        end
    end

    function run(~,~,~)
        if ~gotMetadata
            msgbox('Need Experiment Metadata')
            return
        end
        if ~gotUserdata
            msgbox('Need Username / Projectname / Datasetname')
            return
        end
        if ~gotChannels
            msgbox('Need Channls to acquire - come on!')
            return
        end
        
        %% decide if we are acquiring or doing something else
        switch Actions{get(hAction,'value')}
            case 'Kill'
                func = @() lightExposure(Scp,AcqData(1).Channel,AcqData(1).Exposure,'units','sec');
                Scp.multiSiteAction(func); 
            case 'Acquire T(S)'
                Scp.acquire(AcqData,'type','time(site)');
            case 'Acquire S(T)'
                Scp.acquire(AcqData,'type','site(time)');
%             case 'Uncage And Image'
%                 func = @() UncageAndImage(Scp,AcqData); 
%                 Scp.multiSiteAction(func);
        end
        disp finished
        
    end


end

