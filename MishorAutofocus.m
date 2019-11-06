classdef MishorAutofocus < handle
    properties
        Pos         
    end
    
    properties(Hidden=true)
        zInterp
    end
    
    methods
        %%
        function W = MishorAutofocus(Scp,wells,varargin)
            if numel(wells)<4
               error('Need at least 4 wells for this type of autofocus') 
            end
            
            
            manualFind = ParseInputs('manualFind',false,varargin);
            
            
            W.Pos = W.setAutofocusPositions(Scp, wells);
%             Scp.goto(W.Pos.Labels{1}, W.Pos)
%             figure(445)
%             set(445,'Windowstyle','normal','toolbar','none','menubar','none','Position',[700 892 300 75],'Name','Please find focus in first well','NumberTitle','off')
%             uicontrol(445,'Style', 'pushbutton', 'String','Done','Position',[50 20 200 35],'fontsize',13,'callback',@(~,~) close(445))
%             uiwait(445)
%             W.Pos.List(:,3) = Scp.Z;

            
            if ~manualFind
                Scp.goto(W.Pos.Labels{1}, W.Pos);
                figure(445)
                set(445,'Windowstyle','normal','toolbar','none','menubar','none','Position',[700 892 300 75],'Name','Please find focus in first well','NumberTitle','off')
                uicontrol(445,'Style', 'pushbutton', 'String','Done','Position',[50 20 200 35],'fontsize',13,'callback',@(~,~) close(445))
                uiwait(445)
                W.Pos.List(:,3) = Scp.Z;
                W.findFocusMarks(Scp,varargin{:});
            else
                for i=1:numel(W.Pos.Labels)
                    Scp.goto(W.Pos.Labels{i}, W.Pos);
                    figure(445)
                    set(445,'Windowstyle','normal','toolbar','none','menubar','none','Position',[700 892 300 75],'Name','Please find focus','NumberTitle','off')
                    uicontrol(445,'Style', 'pushbutton', 'String','Done','Position',[50 20 200 35],'fontsize',13,'callback',@(~,~) close(445))
                    uiwait(445)
                    W.Pos.List(i,3) = Scp.Z;
                end
                W.findFocusMarks(Scp,varargin{:});
            end
            
            
            dZ = zeros(numel(wells)-3,1);
            for i=4:numel(wells)
                dZ(i) = abs(W.Pos.List(i,3) - W.zInterp(W.Pos.List(i,1:2)));
            end
            %quality control%
            if max(dZ)>20
                sprintf('The plane found isn`t that great! Max residual is %.2f', max(dZ))
            else
                sprintf('Found nice plane! Max residual is %.2f', max(dZ))
            end
            
        end
        % create autofocus position list
        function Posit = setAutofocusPositions(W,Scp, wells)
        Posit = Scp.createPositions([],'wells',wells,'axis',{'X','Y','Z'},'tmp',true);
        end
        
        % find the focus plane at the given wells
        function findFocusMarks(W,Scp,varargin)
            for i=1:W.Pos.N
                Scp.goto(W.Pos.Labels{i}, W.Pos)
                Zfocus = Scp.ImageBasedFocusHillClimb(varargin{:});
                W.Pos.List(i,3) = Zfocus;
            end
        end
        
        
        % function that gets an XYZ of 3 points and returns a z
        % interpolation on a plane
        function zInterp = get.zInterp(W)
            XYZ = W.Pos.List;
            dXYZ = XYZ(1:3,:)-repmat(XYZ(3,:),3,1);
            pNorm = cross(dXYZ(1,:),dXYZ(2,:))./norm(cross(dXYZ(1,:),dXYZ(2,:)));
            zInterp = @(xy) -((pNorm(1:2)*(xy-XYZ(3,1:2))')/pNorm(3))+XYZ(3,3);
        end
        
        
        function Zpred = Zpredict(W,XY)
            Zpred = zeros(size(XY,1),1);
            for i=1:size(XY,1)
                Zpred(i) = W.zInterp(XY(i,:));
            end
        end
        
        
        
        
        
        
    end
end