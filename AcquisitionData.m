classdef AcquisitionData
   
    properties
        Bin
        Gain
        Exposure
        Channel
        dZ
        Marker
        Fluorophore
        Delay = 0; 
        Triggered = false; 
        Skip = 1; 
    end
    
end