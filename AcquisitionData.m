classdef AcquisitionData
   
    properties
        Bin
        Gain
        Exposure
        Channel
        dZ
        Marker
        Fluorophore
        Triggered = false; 
        Skip = 1; 
    end
    
end