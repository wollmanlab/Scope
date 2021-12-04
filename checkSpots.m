function checkSpots(Scp,varargin)
arg.std_thresh = 5; % 5 std above background
arg.npix_pos_thresh = 2000;
arg.npix_pos_percent_thresh = 0.8; % 80% of positions must pass
arg.signal_thresh = 2;
arg.background_sigma = 10;
arg.smooth = 2;
arg.time = 10;
arg.npos = 10;
arg.step = 5;
arg.Channel = 'FarRed';
arg.Exposure = 500;
arg = parseVarargin(varargin,arg);

Scp.Channel = arg.Channel;
Scp.Exposure = arg.Exposure;
%% First Check For Spots
rand_pos = datasample(Scp.Pos.Labels,arg.npos);
npix_pos_list = zeros(length(rand_pos),1);
img_container = containers.Map;
for i=1:length(rand_pos)
    pos = char(rand_pos(i));
    Scp.goto(pos, Scp.Pos)
    Scp.autofocus
    current_z = Scp.Z;
    Scp.mmc.enableContinuousFocus(false);
    Scp.Z = current_z+arg.step;
    img = Scp.snapImage;
    img_container(pos) = img;
    img = imgaussfilt(img-imgaussfilt(img,arg.background_sigma),arg.smooth);
    img = img/std(img(:));
    npix_pos_list(i) = sum(sum(img>arg.std_thresh));
    Scp.Z = current_z;
end
if sum(npix_pos_list>arg.npix_pos_thresh)/length(npix_pos_list)<arg.npix_pos_percent_thresh
    % Issue Detected
    percent = int2str(round(100*sum(npix_pos_list>arg.npix_pos_thresh)/length(npix_pos_list)));
    message = ['Not Enough Spots Detected',newline,percent,'% of positions have spots'];
    Scp.Notifications.sendSlackMessage(Scp,message);
    uiwait(msgbox(message));
end
%% Next Check PhotoBleaching
[~,loc] = max(npix_pos_list); % Chose Best Position for check
pos = char(rand_pos(loc));
Scp.goto(pos, Scp.Pos)
Scp.autofocus
current_z = Scp.Z;
Scp.AF.turnOffAutoFocus(Scp);
Scp.Z = current_z+5;
npix_time_list = zeros(arg.time,1);
for i=1:arg.time
    img = Scp.snapImage;
    img = imgaussfilt(img-imgaussfilt(img,arg.background_sigma),arg.smooth);
    img = img/std(img(:));
    npix_time_list(i) = sum(sum(img>arg.std_thresh));
end
Scp.Z = current_z;
if npix_time_list(1)/npix_time_list(length(npix_time_list))>arg.signal_thresh
    % Photobleach detected
    plot(1:arg.time,npix_time_list)
    message = 'PhotoBleaching Detected';
    Scp.Notifications.sendSlackMessage(Scp,message);
    uiwait(msgbox(message));
end
end