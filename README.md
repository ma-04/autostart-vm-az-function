## Autostart Azure Spot Virtual Machine and send webhook notification ##

#This azure function is used to start a VM if it is not running, and send a notification to gotify if it is running#
#This is used to start a spot VM that is stopped due to low capacity#
#This is triggered by a webhook, But can be triggered by a timer or queue if needed#


##How to use##
1. Create a new Azure Function
2. Create a new HTTP Trigger function
3. Copy the code from the run.ps1 file into the function

Inspired by
http://web.archive.org/web/20230328044754/https://edi.wang/post/2020/6/18/use-azure-function-to-schedule-auto-start-for-vms
