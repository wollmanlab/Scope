classdef Timepoints < handle
   properties
       T
       Tsec
       Tabs
       units='seconds';
       current = 0;
   end
   
   properties (Dependent = true)
      num
      N
   end
   
   methods
       
       function initAsNow(Tpnts)
           Tpnts.T=0; 
           Tpnts.Tsec=0; 
       end
       
       function Tpnts = createEqualSpacingTimelapse(Tpnts,N,dt,varargin)
           arg.units = Tpnts.units; 
           arg = parseVarargin(varargin,arg);
           switch arg.units
               case {'sec','Seconds','Sec','seconds'}
                   Tpnts.T = linspace(0,N*dt,N+1);
                   Tpnts.Tsec = Tpnts.T;
               case {'minutes','Minutes','min','Min'}
                   Tpnts.units = 'minutes'; 
                   Tpnts.T = linspace(0,N*dt,N+1);
                   Tpnts.Tsec = Tpnts.T*60; 
               case {'Hours','hours','hrs'}
                   Tpnts.units = 'hours';
                   Tpnts.T = linspace(0,N*dt,N+1);
                   Tpnts.Tsec = Tpnts.T*3600; 
           end
       end
       
       function Tnxt = next(Tpnts)
           Tnow = now*24*3600; 
           if isempty(Tpnts.Tabs)
               Tnxt=[]; 
               warning('Can only return next timepoint when working in absolute timeframe, you didn''t call start method'); %#ok<WNTAG>
           else
               % next line can potentially skip items in T based on "real
               % time"
               Tpnts.current = max(find(Tpnts.Tabs>Tnow,1),Tpnts.current+1);
               if Tpnts.current>Tpnts.N
                   Tnxt=[]; 
               else
                   Tnxt = Tpnts.Tabs(Tpnts.current);
               end
           end
       end
       
       function Tpeek = peek(Tpnts)
           % Tpeek will return the time accurding to counter, not using
           % real time. 
           if isempty(Tpnts.Tabs)
               Tpeek=[];
               warning('Can only peek at timepoint when working in absolute timeframe'); %#ok<WNTAG>
           else
               ix = min(Tpnts.N,Tpnts.current+1);
               Tpeek = Tpnts.Tabs(ix);
           end
       end
       
       function num = get.num(Tpnts)
           num = numel(Tpnts.T);
       end
       
       function N = get.N(Tpnts)
          N = Tpnts.num;  
       end
       
       function Tpnts = start(Tpnts,delay)
           Tpnts.current=0; 
           Tpnts.Tabs = Tpnts.Tsec+now*86400;
           Tpnts.Tabs = Tpnts.Tabs+delay; 
           % added a short delay to allow the first timepoint to image...
       end
       
           
   end
end