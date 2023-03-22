classdef Notifications
    properties
        
    end
    
    methods
        function [user,hook] = populateSlackAddresses(~,Scp)
            slack_users = load('notifications_handles.mat');
            slack_users = slack_users.slack_users;
%             slack_users = containers.Map;
%             slack_users('Zach') = '@zehemminger';
%             slack_users('Gaby') = '@gsanc011';
%             slack_users('Thomas') = '@tomunderwood';
%             slack_users('Haley') = '@haleydeocampo';
%             slack_users('Roy') = '@rwollman';
%             slack_users('Timothy') = '@timothyliu04';
%             save('notifications_handles.mat', 'slack_users');
            
%             slack_hooks = containers.Map;
%             slack_hooks('NinjaScope') = 'https://hook*BREAK*s.slac*BREAK*k.com/services/T1GF*BREAK*B0T60/BEEP*BREAK*3EVUP/vI4n7XC5U*BREAK*NE5liMcIbG2J4E7';
%             slack_hooks('HypeScope') = 'https://hoo*BREAK*ks.slack*BREAK*.com/services/T1GFB*BREAK*0T60/BFBLPT*BREAK*G6A/xPW2dUqct9u*BREAK*6NWmnCaIGgaEA';
%             slack_hooks('RamboScope') = 'https://hoo*BREAK*ks.slac*BREAK*k.com/services/T1GFB0*BREAK*T60/B02GHEY*BREAK*PL21/Hf7VdmS9*BREAK*Sy1ck18exycEXnv6';
%             slack_hooks('FutureScope1') = 'https://ho*BREAK*oks.sla*BREAK*ck.com/services/T1GFB*BREAK*0T60/B04TRS*BREAK*ZCXPS/vqvaKIga*BREAK*TEyaPGWgdeU7gQId';
%             slack_hooks('FutureScope2') = 'https://hoo*BREAK*ks.sla*BREAK*ck.com/services/T1GFB*BREAK*0T60/B04TRT*BREAK*9RUSC/2HwCAVD*BREAK*Kwc0eLjH0cTGTk3Yx';
%             slack_hooks('FutureScope3') = 'https://hoo*BREAK*ks.slac*BREAK*k.com/services/T1GF*BREAK*B0T60/B04T2*BREAK*7F6N1Y/8cYXxibD*BREAK*ESnkZdzoEqwDIrxK';
%             slack_hooks('FutureScope4') = 'https://hoo*BREAK*ks.slac*BREAK*k.com/services/T1GF*BREAK*B0T60/B04SV*BREAK*K71K7G/4DBycce1*BREAK*Wh1qrPtjZ4oyvPFf';
%             slack_hooks('FutureScope5') = 'https://hoo*BREAK*ks.slac*BREAK*k.com/services/T1GF*BREAK*B0T60/B04SMM*BREAK*FKB8F/71bNIh59*BREAK*2y2ay8snnSw8hL6j';
%             slack_hooks('FutureScope6') = 'https://hoo*BREAK*ks.slac*BREAK*k.com/services/T1*BREAK*GFB0T60/B04T28B2*BREAK*H98/nMyNmhJJP*BREAK*CzPMSbUi8Oigiaq';
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
            label = labels{1};
            label = strsplit(label,'-');
            Well = label{1};
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