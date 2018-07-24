function y = GaussianFit(beta, x)
ampl = beta(1);
pos = beta(2);
stdev = beta(3);y = ampl*exp(-(x - pos).^2/(2*stdev^2))/sqrt(2*pi)/stdev;
end