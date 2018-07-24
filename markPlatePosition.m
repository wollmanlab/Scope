function Pos = markPlatePosition(Scp,varargin)

if ~isa(Scp.Chamber,'Plate')
    error('Can only mark wells after a plate was loaded to Scope')
end

arg.fig=[]; 
arg.experimentdata = []; 
arg.msk =  false(Scp.Chamber.sz);
arg = parseVarargin(varargin,arg); 

%% setup figure
if isempty(arg.fig)
    Scp.Chamber.Fig(1).fig = figure;
else
    Scp.Chamber.Fig(1).fig = arg.fig;
end
figure(arg.fig); 
clf

%%
mp = arg.msk; 
msk = arg.msk; 
Scp.Chamber.plotHeatMap(msk)

%% Add callbacks
uicontrol('position',[10 0 60 20],'string','Rectangle','callback',@markRectangle)
uicontrol('position',[80 0 100 20],'string','Save & Close','callback',@makePositionListAndClose)
uicontrol('position',[190 0 40 20],'string','sites','style','text');
sitesrow = uicontrol('position',[235 0 15 20],'string','1','style','edit');
uicontrol('position',[250 0 10 20],'string','x','style','text');
sitescol = uicontrol('position',[260 0 15 20],'string','1','style','edit');
set(gca,'ButtonDownFcn',@updateMaskWithClick)
set(Scp.Chamber.Fig.fig,'CloseRequestFcn',@makePositionListAndClose,'WindowStyle','modal')

%% wait for user to close
waitfor(Scp.Chamber.Fig.fig)

%% Nested functions
    function makePositionListAndClose(~,~)
        sitesperwell = [str2double(get(sitesrow,'String')) ...
                        str2double(get(sitescol,'String'))];
        if isa(Scp,'Scope')            
            Pos = Scp.createPositions([],'msk',msk,'sitesperwell',sitesperwell,'experimentdata',arg.experimentdata);
        else
            Pos = Scp.Chamber.Labels(msk==1); 
        end
        delete(Scp.Chamber.Fig.fig)
    end

    function updateMaskWithClick(hObject,~)
        pnt = get(hObject,'CurrentPoint');
        pnt  = pnt(1,1:2);
        d=distance(pnt',[Scp.Chamber.Xcenter(:) Scp.Chamber.Ycenter(:)]');
        [~,mi]=min(d); 
        if msk(mi)<1
            msk(mi)=1; 
        else
            msk(mi)=mp(mi); 
        end
        Scp.Chamber.plotHeatMap(msk)
    end

    function markRectangle(~,~)
        k = waitforbuttonpress; %#ok<NASGU>
        point1 = get(gca,'CurrentPoint');    % button down detected
        finalRect = rbbox;                   %#ok<NASGU> % return figure units
        point2 = get(gca,'CurrentPoint');    % button up detected
        point1 = point1(1,1:2);              % extract x and y
        point2 = point2(1,1:2);
        p1 = min(point1,point2);             % calculate locations
        offset = abs(point1-point2);         % and dimensions
        x = [p1(1) p1(1)+offset(1) p1(1)+offset(1) p1(1) p1(1)];
        y = [p1(2) p1(2) p1(2)+offset(2) p1(2)+offset(2) p1(2)];
        mi = inpolygon(Scp.Chamber.Xcenter(:),Scp.Chamber.Ycenter(:),x,y);
        msk(mi) = ~msk(mi);
        Scp.Chamber.plotHeatMap(msk)
    end

    function d = distance(a,b)
        if (nargin ~= 2)
            error('Not enough input arguments');
        end
        
        if (size(a,1) ~= size(b,1))
            error('A and B should be of same dimensionality');
        end
        
        aa=sum(a.*a,1); bb=sum(b.*b,1); ab=a'*b;
        d = sqrt(abs(repmat(aa',[1 size(bb,2)]) + repmat(bb,[size(aa,2) 1]) - 2*ab));
        
    end

end