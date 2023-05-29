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
$body = @{
    title = $title
    message = $message
    priority = $priority
}

if ($vm.Statuses[1].DisplayStatus -eq "VM running") {
    # if it's running now, then send a notification and exit
    Write-Host $message
    invoke-webrequest -uri $gotify_url -Method POST -Body $body
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $body
        })
    exit 0
} else {
    Select-AzSubscription -SubscriptionID $subscriptionId -TenantID $tenantId
    Start-AzVM -ResourceGroupName $rsgName -Name $vmName
    Start-Sleep -Seconds 21
    $vm=((Get-AzVM -Name 'V' -ResourceGroupName 'virtual-machine' -Status))
    Write-Host "$($vm.Name) status is $($vm.Statuses[1].DisplayStatus)"
    if ($vm.Statuses[1].DisplayStatus -eq "VM starting" -or $vm.Statuses[1].DisplayStatus -eq "VM running") {
        Write-Host $message
        invoke-webrequest -uri $gotify_url -Method POST -Body $body
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body = $body
        })
        exit 0
    } else {
        # if not running and not starting, then it's failed, as a last ditch effort, try to start it again
        # while also sending a notification to check the VM
        Write-Host $message
        invoke-webrequest -uri $gotify_url -Method POST -Body $body
        Start-AzVM -ResourceGroupName $rsgName -Name $vmName
        Start-Sleep -Seconds 20
        $vm=((Get-AzVM -Name 'virtual-machine-1' -ResourceGroupName 'virtual-machine' -Status))
        $message= "$($vm.Name) is showing abnormal status to start command, current status is $($vm.Statuses[1].DisplayStatus), Requires further investigation"
        invoke-webrequest -uri $gotify_url -Method POST -Body $body
        # exit with error code 1 and http response code 503 to indicate service unavailable
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::ServiceUnavailable
        Body = $body
        })
        exit 1
    }
}
