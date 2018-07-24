classdef Device < handle
    % intended as an interface - to be inhereted not implemented
    
    properties
        isInit
    end
    
    methods 
        initialize(dev)
        close(dev)
    end
    
end