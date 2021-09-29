classdef Notifications
    properties
        
    end
    
    methods
        function [user,hook] = populateSlackAddresses(~,Scp)
            slack_users = load('notifications_handles.mat');
            slack_users = slack_users.slack_users;
            
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