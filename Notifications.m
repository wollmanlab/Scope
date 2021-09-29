classdef Notifications
    properties
        
    end
    
    methods
        function [user,hook] = populateSlackAddresses(~,Scp)
            slack_users = containers.Map;
            slack_users('Zach') = '@zehemminger';
            slack_users('Maeve') = '@mnagle7';
            slack_users('Gaby') = '@gsanc011';
            slack_users('Roy') = '@rwollman';
            slack_users('Jonathan') = '@froblinkin';
            slack_users('Christine') = '@cmminor';
            slack_users('Lisa') = '@huiqinwang';
            
            if isKey(slack_users,Scp.Username)
                user = slack_users(Scp.Username);
            else
                user = '';
            end
                        
            slack_hooks = containers.Map;
            slack_hooks('NinjaScope') = 'https://hooks.slack.com/services/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';
            slack_hooks('HypeScope') = 'https://hooks.slack.com/services/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';
            
            if isKey(slack_hooks,Scp.Microscope)
                hook = slack_hooks(Scp.Microscope);
            else
                hook = slack_hooks('NinjaScope');
            end  
        end
        
        function sendSlackMessage(A,Scp,message,varargin)
            [user,hook] = A.populateSlackAddresses(Scp);
            if isempty(user)
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