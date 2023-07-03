using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$subscriptionId = "[SubscriptionID_Paste_HERE]"
$tenantId = "TENANT_ID_PASTE_HERE"

$ResourceGroupName = 'resource_group_name'
$VMName = 'VMName'

# Optional gotify settings for notifications, if you don't want to use gotify, comment out the following 3 lines
$gotify_url= "https://gotify.url/message?token=asdasdasdsd"
$gotify_title = "$VMName Status"
$gotify_priority = 1

Select-AzSubscription -SubscriptionID $subscriptionId -TenantID $tenantId

function Get-Current-AzVMStatus {
    $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status
    $vm.Statuses[1].DisplayStatus
}
function start_vm {
    Start-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName
}
function status_message {
    "$VMName status is $(Get-AzVMStatus)"
}
function error_message {
    "$VMName is showing abnormal status to start command, current status is $(Get-Current-AzVMStatus), Requires further investigation"
}
function body {
    @{title=$gotify_title;message=$status_message;priority=$gotify_priority}
}
function gotify_message_ok {
    invoke-webrequest -uri $gotify_url -Method POST -Body $body
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $body
    })
}
function gotify_message_error {
    invoke-webrequest -uri $gotify_url -Method POST -Body @{title=$gotify_title;message=$error_message;priority=$gotify_priority}
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::ServiceUnavailable
    Body = $body
    })
}

if ($(Get-Current-AzVMStatus) -eq "VM running") {
    Write-Host $message
    Write-Host "VM is already running, no action taken"
    exit 0
} else {
    start_vm
    Write-Host "VM is not running, attempting to start it, Sleeping for 20 seconds to allow VM to start"
    Start-Sleep -Seconds 20
    Write-Host $status_message
    if ($(Get-Current-AzVMStatus) -eq "VM starting" -or $(Get-Current-AzVMStatus) -eq "VM running") {
        Write-Host $message
        Write-Host "VM is starting/Running, no action taken"
        exit 0
    } else {
        # if not running and not starting, then it's failed, as a last ditch effort, try to start it again
        # while also sending a notification to check the VM
        start_vm
        Start-Sleep -Seconds 20
        Write-Host $error_message
        gotify_message_errors
        exit 1
    }
}
