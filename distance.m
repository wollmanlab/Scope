function d = distance(a,b)
if (nargin ~= 2)
    error('Not enough input arguments');
end

if (size(a,1) ~= size(b,1))
    error('A and B should be of same dimensionality');
end

% d = sqrt(bsxfun(@plus,dot(a,a,1)',dot(b,b,1))-2*a'*b);


% aa = sum(bsxfun(@times,a,a),1); 

aa=sum(a.^2,1); 
bb=sum(b.^2,1); 
ab=a'*b;
d = sqrt(abs(repmat(aa',[1 size(bb,2)]) + repmat(bb,[size(aa,2) 1]) - 2*ab));



end