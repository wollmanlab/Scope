function Tpnts = GUIgetTimepoints(varargin)

%%
arg.fig=[]; 
arg = parseVarargin(varargin,arg); 

if isempty(arg.fig)
    arg.fig = figure; 
end
figure(arg.fig)
clf
set(arg.fig,'color','w','position',[850 300 500 250]) %,'windowstyle','modal'

Units = {'sec','min','hour'};

% duration
uicontrol('style','text','position',[50 200 80 20],'string','Duration','fontsize',14);
hDuration = uicontrol('style','edit','position',[50 150 80 30],'fontsize',14); 
hDurationUnits = uicontrol('style','popupmenu','string',Units,'value',3,'position',[50 100 80 30],'fontsize',14);


uicontrol('style','text','position',[150 200 80 20],'string','Interval','fontsize',14);
hInterval = uicontrol('style','edit','position',[150 150 80 30],'fontsize',14); 
hIntervalUnits = uicontrol('style','popupmenu','string',Units,'value',2,'position',[150 100 80 30],'fontsize',14);

uicontrol('style','text','position',[250 200 80 20],'string','End','fontsize',14);
hEnd = uicontrol('style','edit','position',[250 150 100 30],'fontsize',12); 

uicontrol('style','text','position',[370 200 80 20],'string','Iterations','fontsize',14);
hIter = uicontrol('style','edit','position',[370 150 80 30],'fontsize',14); 

uicontrol('position',[125 20 100 50],'string','Calculate','callback',@calc,'fontsize',14);


uicontrol('position',[250 20 130 50],'string','Save & Close','callback',@saveAndClose,'fontsize',14);

dt=0; 
N=0; 
Duration = 0;
Tend=[]; 
Tpnts = Timepoints; 
waitfor(arg.fig);

%% nested functions
    function calc(~,~,~)
        Values = {get(hInterval,'string'),get(hIter,'string'),...
                  get(hDuration,'string'),get(hEnd,'string')};
        e = ~cellfun(@isempty,Values); 
        if sum(e)~=2 
            msgbox('Fill only two of the four!')
            return
        end
        if e(3) && e(4)
            msgbox('Need either Iteration or Interval instead of Dutation or Endtime'); 
        end
        
        % calculate overall duration
        if e(4) || e(3)
            if e(4) % got end time - calc duration
                Tend = datenum(get(hEnd,'string'),'HH:MM dd/mm'); 
                Duration = (Tend-now)*24;
            else % got Duration - move to units of hours
                unt = Units{get(hDurationUnits,'value')};
                switch unt
                    case 'sec'
                        unitconversion = 3600;
                    case 'min'
                        unitconversion = 60 ;
                    case 'hour'
                        unitconversion = 1;
                end
                Duration = str2double(get(hDuration,'string'));
                Duration = Duration/unitconversion; 
                Tend = now+Duration/24;
            end
            % we got Duration / Tend - now get dt/N
            if e(1) % got interval - calculate iter and round up all other numbers
                unt = Units{get(hIntervalUnits,'value')};
                switch unt
                    case 'sec'
                        unitconversion = 3600;
                    case 'min'
                        unitconversion = 60 ;
                    case 'hour'
                        unitconversion = 1;
                end
                dt = str2double(get(hInterval,'string'))/unitconversion;
                N = floor(Duration./dt);
            else
                N = str2double(get(hIter,'String')); 
                dt = Duration / N; 
            end
            
            Duration = N*dt; % in hours
            Tend = now+Duration/24; 
            
        else % got iteration and interval - calc Duration/Tend
            unt = Units{get(hIntervalUnits,'value')};
            switch unt
                case 'sec'
                    unitconversion = 3600; 
                case 'min'
                    unitconversion = 60 ;
                case 'hour'
                    unitconversion = 1; 
            end
            dt = str2double(get(hInterval,'string'));
            N = str2double(get(hIter,'string')); 
            Duration = N*dt/unitconversion;
            Tend = now+Duration/24; 
        end
        
        % update display
        set(hIter,'string',num2str(N));
                
        % update Duration and end after rounding down
        set(hDuration,'string',num2str(Duration))
        set(hDurationUnits,'value',3)
        
        set(hInterval,'string',num2str(dt*60))
        set(hIntervalUnits,'value',2)
                
        set(hEnd,'string',datestr(Tend,'HH:MM dd/mm'));
     
    end

    function saveAndClose(~,~,~)
        Tpnts = createEqualSpacingTimelapse(Tpnts,N,dt,'units', 'hours');
        delete(arg.fig);
    end
        

end