function RelativeAutoFocus(Scp)
% FIX for when Scp.Pos.current = 0
if Scp.Pos.current ==0
    label = ['x_',int2str(round(Scp.X/10)*10),'_y_',int2str(round(Scp.Y/10)*10)];
else
    label = Scp.Pos.Labels{Scp.Pos.current+1,:}; % Position Specific Label Scp.Pos.
end
x = Scp.X;
y = Scp.Y;
z = Scp.Z;
xyz = horzcat(x,y,z);

% Detect Features
% Acquire Stack
Scp.Channel = Scp.Pos.Channel;
Scp.Exposure = Scp.Pos.Exposure;
% Acquire Stack
temp_dz = Scp.Pos.dz;
Scp.Pos.dz = 0.4;
dZ = linspace(Scp.Pos.dstart, Scp.Pos.dend, 1+(Scp.Pos.dend-Scp.Pos.dstart)/Scp.Pos.dz);
stk = zeros([Scp.Height Scp.Width length(dZ)]);
current_Z = Scp.Z;
for i = 1:length(dZ)
    Scp.Z = current_Z + dZ(i);
    stk(:,:,i) = Scp.snapImage();
end
Scp.Z = current_Z;
% Find Features
current_pixel_coordinates = findFeatures(stk);
% Covert to Stage Coordinates Move to function
current_coordinates = zeros(size(current_pixel_coordinates,1),3);
for i=1:size(current_coordinates,1)
    % Verify Camera Orientation
    current_coordinates(i,1:2)=Scp.rc2xy(current_pixel_coordinates(i,1:2),'cameratranspose',true,'cameradirection',[-1 1]);
end
current_coordinates(:,3) = Scp.Z + ((current_pixel_coordinates(:,3)*Scp.Pos.dz)-Scp.Pos.dstart);
Scp.Pos.dz = temp_dz;
% Are you the Reference Hybe
if isKey(Scp.Pos.PerPositionBeads,label)
    % If Not Load Refererence
    reference_coordinates = Scp.Pos.PerPositionBeads(label);
    %Pair Features and add as found local Reference Points
    indexPairs = matchFeatures(reference_coordinates,current_coordinates);
    reference_coordinates = reference_coordinates(indexPairs(:,1),:);
    current_coordinates = current_coordinates(indexPairs(:,2),:);
    % Toss Pairs that are too different
    diff = reference_coordinates-current_coordinates;
    median_diff = diff - median(diff);
    max_diff = max(abs(median_diff),[],2);
    % Toss pairs that are more than 1 um different from median difference
    idx = max_diff<1;
    reference_coordinates = reference_coordinates(idx,:);
    current_coordinates = current_coordinates(idx,:);
    % Calculate local Tform
    regParams = absor(transpose(reference_coordinates),transpose(current_coordinates));
    % Apply Tform
    dxyz = regParams.R*xyz' + regParams.t;
    if max(max(abs(dxyz-transpose(xyz))))>10
        disp(xyz)
        disp(dxzy)
        error(' Movement too Large Likely Wrong')
    end
    
    Scp.X = dxyz(1);
    Scp.Y = dxyz(2);
    Scp.Z = dxyz(3);
else
    % If Yes Set as Local Reference Points
    Scp.Pos.PerPositionBeads(label) = current_coordinates;
end

end
