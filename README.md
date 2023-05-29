## Autostart Azure Spot Virtual Machine and send webhook notification ##

#This azure function is used to start a VM if it is not running, and send a notification to gotify if it is running#
#This is used to start a spot VM that is stopped due to low capacity#
#This is triggered by a webhook, But can be triggered by a timer or queue if needed#

##Why the convulated mess with the variables?##
Im still learning so not sure how to resolve some of the errors that were arising with new variable input not being used


Inspired by
http://web.archive.org/web/20230328044754/https://edi.wang/post/2020/6/18/use-azure-function-to-schedule-auto-start-for-vms
