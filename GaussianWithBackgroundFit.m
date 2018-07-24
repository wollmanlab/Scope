function y = GaussianWithBackgroundFit(beta, x)
ampl = beta(1);
pos = beta(2);
stdev = beta(3);
Background = beta(4);

y = Background + ampl*exp(-(x - pos).^2/(2*stdev^2))/sqrt(2*pi)/stdev;

end

