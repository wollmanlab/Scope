classdef HypeScope < Scope
    % Subclass of Scope that makes certain behavior specific to the
    % zeiss scope.
    
    properties
        last_channel = '0';
        good_focus_z = [];
        focus_fail = 0;
    end
    
    
    
    methods
        
        %         function acquire(Scp,AcqData,varargin)
        %
        %             %% parse optional input arguments
        %
        %             arg.baseacqname='acq';
        %             arg.show=Scp.acqshow;
        %             arg.save=Scp.acqsave;
        %             arg.closewhendone=false;
        %             arg.type = 'time(site)';
        %             arg.func = [];
        %             arg.acqname = '';
        %             arg.dz=[];
        %             arg.channelfirst = true; % used for Z stack
        %             arg = parseVarargin(varargin,arg);
        %
        %             %% Flush the Zyla42 image buffer
        %             Scp.mmc.setCameraDevice('Zyla42');
        %             %             Scp.mmc.getImage();
        %             %             Scp.mmc.setCameraDevice('ZeissAxioCam');
        %             %% Init Acq
        %             if isempty(arg.acqname)
        %                 acqname = Scp.initAcq(AcqData,arg);
        %             else
        %                 acqname = arg.acqname;
        %             end
        %
        %
        %             %% move scope to camera port
        %             %             Scp.mmc.setProperty(Scp.LightPath{1},Scp.LightPath{2},Scp.LightPath{3});
        %
        %             %% set up acq function
        %             if isempty(arg.func)
        %                 if isempty(arg.dz)
        %                     arg.func = @() acqFrame(Scp,AcqData,acqname);
        %                 else
        %                     arg.func = @() acqZstack(Scp,AcqData,acqname,arg.dz,'channelfirst',arg.channelfirst);
        %                 end
        %             end
        %
        %
        %             %% start a mutli-time / Multi-position / Multi-Z acquisition
        %             switch arg.type
        %                 case 'time(site)'
        %                     func = @() multiSiteAction(Scp,arg.func);
        %                     multiTimepointAction(Scp,func);
        %                 case 'site(time)'
        %                     func = @() multiTimepointAction(Scp,arg.func);
        %                     multiSiteAction(Scp,func);
        %             end
        %
        %             Scp.MD.saveMetadata(fullfile(Scp.pth,acqname));
        %             Scp.MD.exportMetadata(fullfile(Scp.pth,acqname));
        %
        %         end
        function acqZcalibration(Scp, AcqData, acqname, dZ, varargin)
            %disp('starting z stack')
            % acqZstack acquires a whole Z stack
            arg.channelfirst = true; % if True will acq multiple channels per Z movement.
            % False will acq a Z stack per color.
            arg = parseVarargin(varargin,arg);
            Scp.autofocus;
            Z0 = Scp.Z;
            AFmethod = Scp.AutoFocusType;
            
            % turn autofocus off
            Scp.AutoFocusType='none';
            pos = Scp.Pos.peek; 

            % acquire a Z stack and do all colors each plane
            xy = Scp.XY;
            if arg.channelfirst
                for i=1:numel(dZ)
                    Scp.Z=Z0+dZ(i);
                    acqFrame(Scp,AcqData,acqname,'z',i);
                    [l fimg] = Scp.Devices.df.snapFocus(1);
                    filename = sprintf('focusimg_%09g_%09g_%s_000.tif',i,randi(99999),'definite_focus');
                    if Scp.Pos.N>1 % add position folder
                    filename =  fullfile(sprintf('Pos%g',Scp.Pos.current-1),filename);
                    end
                    Scp.MD.addNewImage(filename, 'Channel', 'DefiniteFocus', 'Position',pos, 'acq',acqname,'XY',xy,'PixelSize',Scp.Devices.df.pixel_size,'Z',Scp.Z,'Zindex',dZ(i));
                    imwrite(uint16(mat2gray(fimg)*2^16-1),fullfile(Scp.pth,acqname,filename));
                end
            else % per color acquire a Z stack
                for j=1:numel(AcqData)
                    Scp.AutoFocusType = AFmethod;
                    Scp.autofocus
                    disp('Autofocus time')
                    Scp.AutoFocusType='none';
                    for i=1:numel(dZ)
                        Scp.Z=Z0+dZ(i);
                        acqFrame(Scp,AcqData(j),acqname,'z',i);
                    end
                end
            end
            
            % return to base and set AF back to it's previous state
            Scp.AutoFocusType = AFmethod;
            Scp.Z=Z0;
        end
            
        function acqZstack(Scp,AcqData,acqname,dZ,varargin)
            %disp('starting z stack')
            % acqZstack acquires a whole Z stack
            arg.channelfirst = true; % if True will acq multiple channels per Z movement.
            % False will acq a Z stack per color.
            arg = parseVarargin(varargin,arg);
            Scp.autofocus;
            Z0 = Scp.Z;
            AFmethod = Scp.AutoFocusType;
            
            % turn autofocus off
            Scp.AutoFocusType='none';
            
            % acquire a Z stack and do all colors each plane
            if arg.channelfirst
                for i=1:numel(dZ)
                    Scp.Z=Z0+dZ(i);
                    acqFrame(Scp,AcqData,acqname,'z',i);
                end
            else % per color acquire a Z stack
                for j=1:numel(AcqData)
                    Scp.AutoFocusType = AFmethod;
                    Scp.autofocus
                    disp('Autofocus time')
                    Scp.AutoFocusType='none';
                    for i=1:numel(dZ)
                        Scp.Z=Z0+dZ(i);
                        acqFrame(Scp,AcqData(j),acqname,'z',i);
                    end
                end
            end
            
            % return to base and set AF back to it's previous state
            Scp.AutoFocusType = AFmethod;
            Scp.Z=Z0;
        end
        function PixelSize = getPixelSize(Scp)
            PixelSize = Scp.mmc.getPixelSizeUm;
        end
        
        function img = snapImage(Scp)
            img = snapImage@Scope(Scp);
            img = flipud(img);
            img = fliplr(img);
        end
        
        
        function [worked confidence] = autofocus(Scp,AcqData)
            %             persistent XY;
            z=nan;
            s=nan;
            predicted_movement=nan;
            total_movement=0;
            worked=1;
            if strcmp('6-Plan-Apochromat 63x/1.40 Oil M27', Scp.mmc.getProperty('ZeissObjectiveTurret', 'Label'))
                min_movement = 0.10;
            else
                min_movement=0.4;
            end
            
            
            switch lower(Scp.AutoFocusType)
                case 'hardware'
                    tic
                    confidence_thresh = 1000;
                    course_search_range = 75;
                    tolerance = 100;
                    [move confidence pos] = Scp.Devices.df.checkFocus();
                    predicted_movement=move;
                    disp(['Movement (um):', num2str(move), ' with ', num2str(confidence), ' confidence.'])
                    if confidence > confidence_thresh
                        move_magnitude = 10000;
                        if abs(move)<min_movement
                            disp('Movement too small.')
                            return
                        end
                        while (abs(move) < move_magnitude) & (abs(move) > min_movement)
                            Scp.move_focus(move);
                            total_movement = total_movement+move;
                            move_magnitude = abs(move);
                            [move confidence pos] = Scp.Devices.df.checkFocus();
                        end
                        Scp.good_focus_z = [Scp.good_focus_z Scp.Z];
                        total_movement./predicted_movement;
                        
                    else
                        current_focus = Scp.Z;
                        found_focus = 0;
                        disp('Trying course grain focus find.')
                        ave_z = nanmedian(Scp.good_focus_z);
                        search_range = linspace(ave_z-course_search_range, ave_z+course_search_range, 7);
                        if max(search_range)>ave_z+tolerance
                            error('Range max bigger tolerance.')
                        end
                        attempt_counter = 1;
                        for z_val = search_range
                            Scp.Z = z_val;
                            [move confidence mi] = Scp.Devices.df.checkFocus();
                            if confidence > confidence_thresh
                                move_magnitude = 10000;
                                while (abs(move) < move_magnitude) & (abs(move) > min_movement)%& (max(search_range)<ave_z+tolerance)
                                    Scp.move_focus(move);
                                    move_magnitude = abs(move);
                                    [move confidence mi] = Scp.Devices.df.checkFocus();
                                end
                                if confidence < confidence_thresh
                                    continue
                                else
                                    found_focus=1;
                                    move_magnitude = 10000;
                                    if abs(move)<min_movement
                                        disp('Movement too small.')
                                        return
                                    end
                                    while (abs(move) < move_magnitude) & (abs(move) > min_movement)
                                        Scp.move_focus(move);
                                        total_movement = total_movement+move;
                                        move_magnitude = abs(move);
                                        [move confidence pos] = Scp.Devices.df.checkFocus();
                                    end
                                    if confidence<confidence_thresh
                                        continue
                                    else
                                        Scp.good_focus_z = [Scp.good_focus_z Scp.Z];
                                        break
                                    end
                                end
                            end
                            
                        end
                        if found_focus
                            disp('Woo hoo found course focus')
                            
                        else
                            Scp.Z = current_focus;
                            Scp.Z = ave_z;
                            disp('Did not have confidence in finding focus. Should implement better course find if this happens a lot.')
                            worked=0;
                            Scp.focus_fail = Scp.focus_fail+1;
                        end
                        
                    end
                    toc
                    %                     Scp.mmc.sleep(1);
                case 'none'
                    disp('No autofocus used')
                    
                    
            end
            
        end
        
        
        
        function move_focus(Scp, movement)
            if abs(movement>50)
                error('Movement too large. I am afraid to break the coverslip.')
            else
                Scp.Z = Scp.Z + movement;
            end
        end
        
        function hybe_acq(Scp, number_hybes, varargin)
            arg.baseacqname='hybe';
            arg.show=Scp.acqshow;
            arg.save=Scp.acqsave;
            arg.closewhendone=false;
            arg.type = 'time(site)';
            arg.func = [];
            arg.acqname = '';
            arg.dz=[];
            arg.channelfirst = true; % used for Z stack
            arg = parseVarargin(varargin,arg);
            %% Flush the Zyla42 image buffer
            Scp.mmc.setCameraDevice('Zyla42');
            Scp.mmc.getImage();
            %% Init Acq
            if isempty(arg.acqname)
                acqname = Scp.initAcq(AcqData,arg);
            else
                acqname = arg.acqname;
            end
            
            
            %% move scope to camera port
            %             Scp.mmc.setProperty(Scp.LightPath{1},Scp.LightPath{2},Scp.LightPath{3});
            
            %% set up acq function
            if isempty(arg.func)
                if isempty(arg.dz)
                    arg.func = @() acqFrame(Scp,AcqData,acqname);
                else
                    arg.func = @() acqZstack(Scp,AcqData,acqname,arg.dz,'channelfirst',arg.channelfirst);
                end
            end
            
            
            %% start a mutli-time / Multi-position / Multi-Z acquisition
            switch arg.type
                case 'hybe(site)'
                    func = @() multiSiteAction(Scp,arg.func);
                    multiTimepointAction(Scp,func);
                case 'site(time)'
                    func = @() multiTimepointAction(Scp,arg.func);
                    multiSiteAction(Scp,func);
            end
            Scp.MD.saveMetadata(fullfile(Scp.pth,acqname));
            
        end
        
    end
    
    
    
end
