classdef PerfectFocus < AutoFocus
   properties
       autofocusTimeout = 3;
   end
   methods
       function AF = checkFocus(AF,Scp,varargin)
           t0 = now;
           Scp.mmc.enableContinuousFocus(true);
           while ~Scp.mmc.isContinuousFocusLocked && (now-t0)*24*3600 < AF.autofocusTimeout
               pause(Scp.autofocusTimeout/1000)
           end
           if Scp.mmc.isContinuousFocusLocked
               AF.foundFocus = true;
           end
       end
       
       function AF = turnOffAutoFocus(AF,Scp,varargin)
           Scp.mmc.enableContinuousFocus(false);
       end
   end
end