function SimpleScopeNavigation(varargin)

% get the Scp object and if missing create it in the base workspace
try
    Scp = evalin('base', 'Scp');
catch %#ok<CTCH>
    Scp = Scope;
    assignin('base', 'Scp',Scp)
end

fig=99; 

%% setup figure
Scp.Chamber.Fig(1).fig = fig;
figure(fig); 
set(fig,'position',[ 785   534   560   420]);
clf

%%
msk = false(Scp.Chamber.sz);
d=distance(Scp.XY',[Scp.Chamber.Xcenter(:) Scp.Chamber.Ycenter(:)]');
[~,mi]=min(d);
msk(mi)=true; 
Scp.Chamber.plotHeatMap(msk,'colormap',gray(256),'fig',fig)

%% Add callbacks
set(gca,'ButtonDownFcn',@updateMaskWithClick)
% set(Scp.Chamber.Fig.fig,'WindowStyle','modal')

%% Nested functions
    function updateMaskWithClick(hObject,~)
        pnt = get(hObject,'CurrentPoint');
        pnt  = pnt(1,1:2);
        d=distance(pnt',[Scp.Chamber.Xcenter(:) Scp.Chamber.Ycenter(:)]');
        [~,mi]=min(d); 
        msk = false(Scp.Chamber.sz);
        msk(mi) = ~msk(mi);
        Scp.Chamber.plotHeatMap(msk,'fig',fig,'colormap',gray(256))
        Scp.goto(Scp.Chamber.Wells{mi},[],'plot',false); 
    end

end