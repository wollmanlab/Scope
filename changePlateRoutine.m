function changePlateRoutine(Scp,PlateName,x0y0)

Scp.Chamber = Plate(PlateName);

Scp.mmc.setProperty('Focus','Load Position',1);
Scp.mmc.setSerialPortCommand('COM1', 'HOME X', '\r');
Scp.X;
pause(5)

Scp.mmc.setSerialPortCommand('COM1', 'HOME Y', '\r');
Scp.Y;
pause(5)
Scp.Chamber.x0y0 = Scp.XY+x0y0;
Scp.Chamber.directionXY = [1 1];
Scp.reduceAllOverheadForSpeed=true;
Scp.mmc.setProperty('Focus','Load Position',0);