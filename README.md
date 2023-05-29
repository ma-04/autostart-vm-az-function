## Autostart Azure Spot Virtual Machine and send webhook notification ##

#This azure function is used to start a VM if it is not running, and send a notification to gotify if it is running
#This is used to start a spot VM that is stopped due to low capacity
#This is triggered by a webhook, But can be triggered by a timer or queue if needed
