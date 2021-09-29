function xyz = findFeatures(stk)
% Upgrade to move hard code to varargin

% Detect Features within Volume to use as Reference Points
% Background Subtraction full stack
for i=1:size(stk,3)
    img = stk(:,:,i);
    img = imgaussfilt(img,1);
    bkg = imgaussfilt(img,2);
    img = img-bkg;
    %img = imgaussfilt(img,2);
    stk(:,:,i) = img;
end
% Max Project
img = max(stk,[],3);
% Background
bkg = imgaussfilt(img,5);
% Subtract
img = img-bkg;
img(img<0) = 0;
% smooth
img = imgaussfilt(img,15);
% Call peaks
thresh = prctile(reshape(img,1,[]),99);
%img(img<thresh) = thresh;
img = img-thresh;
img(img<0) = 0;
peaks = FastPeakFind(img);
x = peaks(1:2:end); 
y = peaks(2:2:end); 
border = 100;
mask = (x<border)|(x>(size(img,2)-border))|(y<border)|(y>(size(img,1)-border));
mask = mask==0;
x = x(mask);
y = y(mask);
% Call Peak in Z
% Needs to be more Robust%
% Could interpolate for better accuracy?
z = zeros(length(y),1);
%figure(6)
xq = linspace(1,size(stk,3),200);
%hold on
for i=1:length(x)
    v = stk(y(i),x(i),:);
    nv = interp1(1:size(stk,3),v(:),xq(:),'spline');
    [~,argmax] = max(nv(:));
    z(i) = xq(argmax);
    %plot(xq(:),nv(:));
    %plot(1:size(stk,3),v(:));
end
%hold off
xyz = zeros(length(z),3);
xyz(:,1) = x; 
xyz(:,2) = y;
xyz(:,3) = z;

end