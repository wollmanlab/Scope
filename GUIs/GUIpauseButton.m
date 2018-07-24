function GUIpauseButton(Scp)

%%
figure(333)
clf
set(333,'toolbar','none')
set(333,'menu','none')
set(333,'position',[1600 100 80 50])

hPause = uicontrol('style','togglebutton','value',1,'position',[10 5 80 40],'string','pause','fontsize',13,'callback',@pause);

    function pause(~,~,~)
        Scp.Pause = get(hPause,'value'); 
    end

end