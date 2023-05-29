using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$subscriptionId = "[SubscriptionID_Paste_HERE]"
$tenantId = "[TENANT_ID_PASTE_HERE"
$vm=((Get-AzVM -Name 'virtual-machine-1' -ResourceGroupName 'virtual-machine-group' -Status))

$rsgName = $vm.ResourceGroupName
$vmName = $vm.Name
$message= "$($vm.Name) status is $($vm.Statuses[1].DisplayStatus)"

# gotify webhook notification is used here, u can change it to anything you want
$gotify_url= "https://gotify.domain/message?token=asdsadsadsadd"
$gotify_title = "Virtual Machine Status"
$gotify_priority = 1
#$body = @{title=$gotify_title;message=$message;priority=$gotify_priority}

Select-AzSubscription -SubscriptionID $subscriptionId -TenantID $tenantId
$vm=((Get-AzVM -Name $vmName -ResourceGroupName $rsgName -Status))
if ($vm.Statuses[1].DisplayStatus -eq "VM running") {
    # if it's running now, then send a notification and exit
    $message= "$vmName status is $(((Get-AzVM -Name $vmName -ResourceGroupName $rsgName -Status)).Statuses[1].DisplayStatus)"
    Write-Host $message
    Write-Host "VM is already running, no action taken"
    invoke-webrequest -uri $gotify_url -Method POST -Body @{title=$gotify_title;message=$message;priority=$gotify_priority}
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $body
        })
    exit 0
} else {
    Start-AzVM -ResourceGroupName $rsgName -Name $vmName
    Write-Host "VM is not running, attempting to start it, Sleeping for 20 seconds to allow VM to start"
    Start-Sleep -Seconds 20
    $vm=((Get-AzVM -Name $vmName -ResourceGroupName $rsgName -Status))
    Write-Host "$vmName status is $($vm.Statuses[1].DisplayStatus)"
    if ($vm.Statuses[1].DisplayStatus -eq "VM starting" -or $vm.Statuses[1].DisplayStatus -eq "VM running") {
        $message= "$vmName status is $($vm.Statuses[1].DisplayStatus)"
        Write-Host $message
        Write-Host "VM is starting/Running, no action taken"
        invoke-webrequest -uri $gotify_url -Method POST -Body @{title=$gotify_title;message=$message;priority=$gotify_priority}
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body = $body
        })
        exit 0
    } else {
        # if not running and not starting, then it's failed, as a last ditch effort, try to start it again
        # while also sending a notification to check the VM
        Start-AzVM -ResourceGroupName $rsgName -Name $vmName
        Start-Sleep -Seconds 20
        $message= "$vmName is showing abnormal status to start command, current status is $(((Get-AzVM -Name $vmName -ResourceGroupName $rsgName -Status)).Statuses[1].DisplayStatus), Requires further investigation"
        Write-Host $message
        invoke-webrequest -uri $gotify_url -Method POST -Body @{title=$gotify_title;message=$message;priority=$gotify_priority}
        # exit with error code 1 and http response code 503 to indicate service unavailable
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::ServiceUnavailable
        Body = $body
        })
        exit 1
    }
}
