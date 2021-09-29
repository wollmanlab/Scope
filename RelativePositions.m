classdef RelativePositions < Positions
    
    properties
       RefFeaturesLabels = {}; % names of reference 
       RefFeatureList = []; % a 3D matrix time x XYZ x Features
       RefFeatureTimestamps = []; % a 1D vector of timepoints
             
    end
    
    methods
        
        function Pos = RelativePositions(fullfilename,varargin)
            Pos@Positions(fullfilename,varargin)
        end
        
        function addRefPointsFromImage(Pos,Scp,Labels,varargin)
            arg.channel='Brightfield'; 
            arg.pixelsize = Scp.PixelSize;
            arg.exposure = 75; 
            arg.cameradirection = [1 -1];
            arg.pixelsize = Scp.PixelSize;
            arg.fig=[];
            arg.t=now; 
            arg = parseVarargin(varargin,arg);
            
            if isempty(arg.fig)
                arg.fig=figure; 
            end
            
            %% snap an image
            Scp.Channel=arg.channel; 
            Scp.Exposure = arg.exposure; 
            img=Scp.snapImage;
            
            %%
            figure(arg.fig); 
            imshow(imadjust(img, [prctile(img(:), 20) prctile(img(:), 97)]))
            hold on
            rc=nan(1,2); 
            Tnow=arg.t;
            for i=1:numel(Labels)
                title(Labels{i})
                rc([2 1])=ginput(1); % rc first coordinate is y and second coordinate is x in image
                text(rc(2),rc(1),Labels{i},'fontsize',14,'color','red')
                disp(rc)
                xy=Scp.rc2xy(rc, 'cameradirection', arg.cameradirection, 'pixelsize', arg.pixelsize); 
                if strcmp(Pos.axis,'XY')
                    z=0; 
                else
                    z=Scp.Z; 
                end
                disp(xy)
                addRefPoint(Pos,Labels{i},[xy z],Tnow)
            end

        end
        
        function addRefPoint(Pos,Label,coord,T)
            % edge case - first point we are added, just assign
            if isempty(Pos.RefFeatureList)
                Pos.RefFeatureList=coord(:)';
                Pos.RefFeaturesLabels{1}=Label; 
                Pos.RefFeatureTimestamps(1)=T; 
                return
            end
            assert(numel(coord)==size(Pos.RefFeatureList,2),'You were not consistent in the number of axis in Ref were you?')
            % if we are here, that means that we are adding a point
            % first see if we need to add a label
            ix_label = find(ismember(Pos.RefFeaturesLabels,Label),1); 
            if isempty(ix_label)
                ix_label=numel(Pos.RefFeaturesLabels)+1;
                Pos.RefFeaturesLabels{ix_label}=Label; 
                Pos.RefFeatureList(:,:,ix_label)=nan; 
            end
            % see if we need to add a time
            if isempty(Pos.RefFeatureTimestamps) || T>max(Pos.RefFeatureTimestamps) 
                ix_t=numel(Pos.RefFeatureTimestamps)+1; 
                Pos.RefFeatureTimestamps(ix_t)=T;
                Pos.RefFeatureList(ix_t,:,:)=nan; 
            elseif Pos.RefFeatureTimestamps(end)==T
                ix_t=numel(Pos.RefFeatureTimestamps); 
            else 
                error('cannot add a ref point at time smaller than a previously inserted refpoint time'); 
            end
            % add
            Pos.RefFeatureList(ix_t,:,ix_label)=coord(:)'; 
        end
        
        
        function coord = getRefPoint(Pos,Label,T)
            if ischar(T) && strcmp(T,'last')
                T=Pos.RefFeatureTimestamps(end); 
            end
            ix_t = find(Pos.RefFeatureTimestamps>=T,1);
            ix_label = ismember(Pos.RefFeaturesLabels,Label); 
            coord = Pos.RefFeatureList(ix_t,:,ix_label);
        end
        

        function [xyzrtrn,xyzorg] = getPositionFromLabel(Pos,label)
            % first get xyz without in relative units
            xyz = getPositionFromLabel@Positions(Pos,label);
            xyzorg=xyz; 
            if isempty(Pos.RefFeatureList())
                xyzrtrn = xyzorg;
                % check that there are enough ref points
                %assert(size(Pos.RefFeatureList,1)>0,'Missing Ref Points')
            else
                % get transformation
                % Why calculate this each time???
                regParams = getTform(Pos);
                
                % transform
                if strcmp(Pos.axis,'XY')
                    xyzrtrn = regParams.R(1:2,1:2)*xyz' + regParams.t(1:2);
                else
                    xyzrtrn = regParams.R*xyz' + regParams.t;
                end
            end
            
        end
        
        function regParams = getTform(Pos,varargin)
            
            % might not work well for multi-reference stuff. 
            % TODO fix this.... 
            arg.tcurrent = Pos.RefFeatureTimestamps(end); 
            arg.tstart = Pos.RefFeatureTimestamps(1);
            arg = parseVarargin(varargin,arg); 
            
            % getting positions for ALL labels from first timepoints that is 
            % after or equal requested time
            ix_start = find(Pos.RefFeatureTimestamps>=arg.tstart,1); 
            ix_current = find(Pos.RefFeatureTimestamps>=arg.tcurrent,1);
                        
            coord_start = squeeze(Pos.RefFeatureList(ix_start,:,:)); 
            coord_current = squeeze(Pos.RefFeatureList(ix_current,:,:)); 
            
            regParams = absor(coord_start,coord_current);
        end
        
    end
    
end