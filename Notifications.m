classdef Notifications
    properties
        
    end
    
    methods
        function [user,hook] = populateSlackAddresses(~,Scp)
            slack_users = load('notifications_handles.mat');
            slack_users = slack_users.slack_users;
%             slack_users = containers.Map;
            slack_users('Zach') = '@zehemminger';
            slack_users('Gaby') = '@gsanc011';
            slack_users('Thomas') = '@tomunderwood';
            slack_users('Haley') = '@hdeocampo';
            slack_users('Roy') = '@rwollman';
            slack_users('Timothy') = '@timothyliu04';
%             save('notifications_handles.mat', 'slack_users');
%             
%             slack_hooks = containers.Map;
%             slack_hooks('NinjaScope') = 'https://hooks.sla*BREAK*ck.com/services/T1GFB0*BREAK*T60/BEEP3EVUP/vI4n7XC5UNE*BREAK*5liMcIbG2J4E7';
%             slack_hooks('HypeScope') = 'https://hooks.sla*BREAK*ck.com/services/T1GFB0T60/BFBLP*BREAK*TG6A/xPW2dUqct9u6N*BREAK*WmnCaIGgaEA';
%             slack_hooks('RamboScope') = 'https://hooks.slac*BREAK*k.com/services/T1GFB0T60/B02GH*BREAK*EYPL21/Hf7VdmS9Sy1*BREAK*ck18exycEXnv6';
%             slack_hooks('FutureScope1') = 'https://hooks.sl*BREAK*ack.com/services/T1GFB0T60/B04TR*BREAK*SZCXPS/vqvaKIgaTE*BREAK*yaPGWgdeU7gQId';
%             slack_hooks('FutureScope2') = 'https://hooks.sl*BREAK*ack.com/services/T1GFB0T60/B04TR*BREAK*T9RUSC/2HwCAVDKwc0*BREAK*eLjH0cTGTk3Yx';
%             slack_hooks('FutureScope3') = 'https://hooks.sl*BREAK*ack.com/services/T1GFB0T60/B04T27*BREAK*F6N1Y/8cYXxibDESn*BREAK*kZdzoEqwDIrxK';
%             slack_hooks('FutureScope4') = 'https://hooks.sla*BREAK*ck.com/services/T1GFB0T60/B04SVK*BREAK*71K7G/4DBycce1Wh1*BREAK*qrPtjZ4oyvPFf';
%             slack_hooks('FutureScope5') = 'https://hooks.sla*BREAK*ck.com/services/T1GFB0T60/B04SMM*BREAK*FKB8F/71bNIh592y2*BREAK*ay8snnSw8hL6j';
%             slack_hooks('FutureScope6') = 'https://hooks.sl*BREAK*ack.com/services/T1GFB0T60/B04T28*BREAK*B2H98/nMyNmhJJPCz*BREAK*PMSbUi8Oigiaq';
%             save('notifications_addresses.mat', 'slack_hooks');
            
            if isKey(slack_users,Scp.Username)
                user = slack_users(Scp.Username);
            else
                user = '';
            end
                        
            slack_hooks = load('notifications_addresses.mat');
            slack_hooks = slack_hooks.slack_hooks;

            if isKey(slack_hooks,class(Scp))
                hook = slack_hooks(class(Scp));
            else
                hook = slack_hooks('NinjaScope');
            end  
        end
        
        function sendSlackMessage(A,Scp,message,varargin)
            arg.all = false;
            arg = parseVarargin(varargin,arg);

            labels = Scp.Pos.Labels(Scp.Pos.Hidden==0);
            if isempty(labels)
                Well = 'Empty Positions';
            else
                label = labels{1};
                label = strsplit(label,'_');
                Well = label{1};
                Well = strsplit(Well,'-');
                Well = Well{1};
            end
            message = [Scp.Dataset,' ',message,' ',Well];

            [user,hook] = A.populateSlackAddresses(Scp);
            if arg.all
                status = SendSlackNotification(hook,message);
                if strcmp(status,'ok')==0
                    msgbox([message,newline,'Slack Hook not set up correctly'])
                end
            elseif isempty(user)
                message = [message,newline,Scp.Username];
                status = SendSlackNotification(hook,message);
                if strcmp(status,'ok')==0
                    msgbox([message,newline,'Slack Hook not set up correctly'])
                end
            else
                status = SendSlackNotification(hook,message,user);
                if strcmp(status,'ok')==0
                    message = [message,newline,Scp.Username,newline,' Notification Class Slack Handle not correct'];
                    status = SendSlackNotification(hook,message);
                    if strcmp(status,'ok')==0
                        msgbox([message,newline,'Slack Hook not set up correctly'])
                    end
                end
            end
        end
    end
end