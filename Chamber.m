classdef Chamber < handle
   properties (Abstract)
      type
      numOfsubChambers
      Labels
      Fig
   end
   
   methods (Abstract)
       xy = getXYbyLabel(Chmbr,label);
   end
   
end