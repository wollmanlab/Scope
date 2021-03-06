%
% Implementation of Exposure Fusion
%
% written by Tom Mertens, Hasselt University, August 2007
% e-mail: tom.mertens@gmail.com
%
% This work is described in
%   "Exposure Fusion"
%   Tom Mertens, Jan Kautz and Frank Van Reeth
%   In Proceedings of Pacific Graphics 2007
%
%
% Usage:
%   result = exposure_fusion(I,m);
%   Arguments:
%     'I': represents a stack of N color images (at double
%       precision). Dimensions are (height x width x 3 x N).
%     'm': 2-tuple that controls the per-pixel measures. The elements 
%     control contrast, and well-exposedness, respectively.
%
% Example:
%   'figure; imshow(exposure_fusion(I, [0 0 1]);'
%   This displays the fusion of the images in 'I' using only the well-exposedness
%   measure
%

function R = exposure_fusion_mono(I,m)

r = size(I,1);
c = size(I,2);
N = size(I,3);

W = ones(r,c,N);

%compute the measures and combines them into a weight map
contrast_parm = m(1);
wexp_parm = m(2);

if (contrast_parm > 0)
    W = W.*contrast(I).^contrast_parm;
end
if (wexp_parm > 0)
    W = W.*well_exposedness(I).^wexp_parm;
end

%normalize weights: make sure that weights sum to one for each pixel
W = W + 1e-12; %avoids division by zero
W = W./repmat(sum(W,3),[1 1 N]);

% create empty pyramid
pyr = gaussian_pyramid(zeros(r,c));
nlev = length(pyr);

% multiresolution blending
for i = 1:N
    % construct pyramid from each input image
	pyrW = gaussian_pyramid(W(:,:,i));
	pyrI = laplacian_pyramid(I(:,:,i));
    
    % blend
    for l = 1:nlev
        w = repmat(pyrW{l},[1 1]);
        pyr{l} = pyr{l} + w.*pyrI{l};
    end
end

% reconstruct
R = reconstruct_laplacian_pyramid(pyr);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% contrast measure
function C = contrast(I)
h = [0 1 0; 1 -4 1; 0 1 0]; % laplacian filter
N = size(I,3);
C = zeros(size(I,1),size(I,2),N);
for i = 1:N
    mono = mat2gray(I(:,:,i));
    C(:,:,i) = abs(imfilter(mono,h,'replicate'));
end


% well-exposedness measure
function C = well_exposedness(I)
sig = .2;
N = size(I,3);
C = zeros(size(I,1),size(I,2),N);
for i = 1:N
    C(:,:,i) = exp(-.5*(I(:,:,i) - .5).^2/sig.^2);
end


