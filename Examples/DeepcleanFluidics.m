Scp = BlueScope;
Scp.Username = 'Gaby'; % your username!
%%
Scp.FlowData.start_Gui()
Scp.FlowData.start_Fluidics()
%%
% Ethanol wash
Scp.FlowData.wait_until_available()
command = Scp.FlowData.build_command('ReverseFlush',[''],'TBS+3');
Scp.FlowData.send_command(command,Scp)
Scp.FlowData.wait_until_available()

command = Scp.FlowData.build_command('Prime',[''],'Waste+2');
Scp.FlowData.send_command(command,Scp)
Scp.FlowData.wait_until_available()

command = Scp.FlowData.build_command('ReverseFlush',[''],'Air+3');
Scp.FlowData.send_command(command,Scp)
Scp.FlowData.wait_until_available()

Scp.Notifications.sendSlackMessage(Scp,'Ethanol Wash Done')
uiwait(msgbox('Ready to proceed?'))
%%
% 1xTBS/ultra pure water wash
Scp.FlowData.wait_until_available()
command = Scp.FlowData.build_command('ReverseFlush',[''],'TBS+3');
Scp.FlowData.send_command(command,Scp)
Scp.FlowData.wait_until_available()

command = Scp.FlowData.build_command('Prime',[''],'Waste+2');
Scp.FlowData.send_command(command,Scp)
Scp.FlowData.wait_until_available()

command = Scp.FlowData.build_command('ReverseFlush',[''],'Air+3');
Scp.FlowData.send_command(command,Scp)
Scp.FlowData.wait_until_available()

Scp.Notifications.sendSlackMessage(Scp,'Ultra Pure Water Wash Done')

