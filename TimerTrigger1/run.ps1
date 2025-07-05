# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' porperty is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

# Write an information log with the current time.
Write-Host "PowerShell timer trigger function ran! TIME: $currentUTCtime"
Write-Host "Current Subscription ID: $env:SUBSCRIPTION_ID"
# Add the Azure Subscription Ids that this script should read and execute on
$subscriptionIds = @"
[
"$env:SUBSCRIPTION_ID"
]
"@ | ConvertFrom-Json

# The following defines the variable to store the date and retrieves the current date/time in the desired timezone (the default is UTC)
# It is important to specify the correct timezone so the virtual machines will start/stop at the expected time
# The following Microsoft article provides the available timezones:
# https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/default-time-zones?view=windows-11#time-zones
# Use the value in the "Timezone" column for the passed string
$date = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::Now, "Eastern Standard Time")

## Use this line to test with date variable defined ##
# $date = [DateTime] "09/30/2023 9:00 AM"

$autoOnOffquery = @"
resources
| where type == "microsoft.compute/virtualmachines" 
and (isnotnull(tags['WD-AutoStart'])
and isnotnull(tags['WD-AutoDeallocate']))
or (isnotnull(tags['WE-AutoStart'])
and isnotnull(tags['WE-AutoDeallocate']))
or isnotnull(tags['Weekend'])
| extend ['Weekday AutoStart'] = tags['WD-AutoStart'], ['Weekday AutoDeallocate'] = tags['WD-AutoDeallocate'],['Weekend AutoStart'] = tags['WE-AutoStart'], ['Weekend AutoDeallocate'] = tags['WE-AutoDeallocate'],['Weekend'] = tags['Weekend'],['Status'] = properties.extended.instanceView.powerState.displayStatus,['Resource Group'] = resourceGroup
| project name,['Weekday AutoStart'],['Weekday AutoDeallocate'],['Weekend AutoStart'],['Weekend AutoDeallocate'],['Weekend'],Status,['Resource Group']
"@

foreach ($subscriptionId in $subscriptionIds) {
    # Set the current subscription to this iteration of the subscription
    Set-AzContext -SubscriptionId $SubscriptionID | Out-Null

    $currentSubscription = (Get-AzContext).Subscription.Id
    If ($currentSubscription -ne $SubscriptionID) {
        # Throw an error if switching to subscription fails
        Throw "Could not switch to the SubscriptionID: $SubscriptionID. Please check the permissions to the subscription and/or make sure the ID is correct."
    }

    # Fix single digit hour not having 2 digits (e.g. 08:50 = 8:50)
    If ($date.hour.length -eq 1) {
        $fixedHour = ([string]$date.hour).PadLeft(2, '0')
    }
    else {
        $fixedhour = $date.hour
    }

    # Fix single digit minute not having 2 digits (e.g. 12:05 = 12:5)
    If ($date.minute.length -eq 1) {
        $fixedMinute = ([string]$date.minute).PadLeft(2, '0')
    }
    else {
        $fixedMinute = $date.minute
    }

    # Set the $timeNow variable to today's date's HH:MM
    $timeNow = [string] $fixedHour + ":" + $fixedMinute

    # Determine whether today is a weekday
    $todayIsAweekday = (Get-Date).DayOfWeek.value__ -le 6

    ## Use this to test as if today was a weekend ##
    # $todayIsAweekday = $false

    # Fetch VMs with auto on and off schedule
    $virtualMachines = Search-AzGraph -Query $autoOnOffquery
    
    # Print out collected VMs in a table for console display
    $virtualmachines | Format-Table

    # Check if there's a specific VM to start from environment variable
    $vmToStart = $env:VM_TO_START
    if (-not [string]::IsNullOrEmpty($vmToStart)) {
        Write-Host "VM_TO_START environment variable found: $vmToStart"
        
        # Try to find the VM by name across all resource groups
        try {
            $targetVM = Get-AzVM | Where-Object { $_.Name -eq $vmToStart }
            
            if ($targetVM) {
                Write-Host "Found VM '$vmToStart' in resource group '$($targetVM.ResourceGroupName)'"
                
                # Get the current status of the VM
                $vmStatus = Get-AzVM -ResourceGroupName $targetVM.ResourceGroupName -Name $targetVM.Name -Status
                $powerState = $vmStatus.Statuses | Where-Object { $_.Code -like "PowerState/*" } | Select-Object -ExpandProperty DisplayStatus
                
                Write-Host "Current status of VM '$vmToStart': $powerState"
                
                if ($powerState -eq "VM deallocated" -or $powerState -eq "VM stopped") {
                    Write-Host "Starting VM '$vmToStart' as requested by environment variable..."
                    Start-AzVM -ResourceGroupName $targetVM.ResourceGroupName -Name $targetVM.Name -Confirm:$false -NoWait
                    Write-Host "Start command sent for VM '$vmToStart'"
                }
                elseif ($powerState -eq "VM running") {
                    Write-Host "VM '$vmToStart' is already running"
                }
                else {
                    Write-Host "VM '$vmToStart' is in state '$powerState' - not starting"
                }
            }
            else {
                Write-Host "VM '$vmToStart' not found in subscription '$subscriptionId'"
            }
        }
        catch {
            Write-Error "Error processing VM '$vmToStart': $($_.Exception.Message)"
        }
    }
    else {
        Write-Host "No VM_TO_START environment variable set - skipping manual VM start"
    }
}