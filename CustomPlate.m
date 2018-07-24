classdef CustomPlate < Chamber
    
    properties
        sz;
        Wells = {};
        
        Xcenter
        Ycenter
        
        %% from the Chamber interface
        type = 'Custom'; 
        numOfsubChambers
        Labels
        Fig = struct('fig',[],'Wells',{});
    end
    
    methods
        
        function CP = CustomPlate(Wells,Coordinates)
            if nargin==0; 
                return
            end
            
            CP.Wells = Wells; 
            CP.Xcenter = Coordinates(:,1);
            CP.Ycenter = Coordinates(:,2);
            CP.sz = size(Wells); 
            CP.numOfsubChambers=numel(Wells);
          
        end
        
        function [Xcenter,Ycenter] = getXY(Plt)
            Xcenter=Plt.Xcenter; 
            Ycenter=Plt.Ycenter; 
        end

        
        function Labels = get.Labels(Plt)
            Labels = Plt.Wells;
        end
        
        function xy = getXYbyLabel(Plt,label)
            [Xcntr,Ycntr] = Plt.getXY;
            x = Xcntr(ismember(Plt.Labels,label));
            y = Ycntr(ismember(Plt.Labels,label));
            xy=[x(:) y(:)];
        end
        
        function plotHeatMap(~,~,~)
        end
        
         function [dx,dy]=getWellShift(~,~)
             dx=0; 
             dy=0; 
         end
        
    end
end