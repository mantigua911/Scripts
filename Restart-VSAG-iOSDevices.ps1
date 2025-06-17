<#
.SYNOPSIS
    Restarts all supervised iOS devices in Intune whose names start with "VSAG".

.REQUIREMENTS
    - Microsoft Graph PowerShell SDK
    - Permission: DeviceManagementManagedDevices.PrivilegedOperations.All
    - Device must be supervised and running iOS 10.3 or higher
#>

# Ensure Microsoft Graph SDK is installed
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
    Install-Module Microsoft.Graph -Scope CurrentUser -Force
}

Import-Module Microsoft.Graph

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.PrivilegedOperations.All"

# Get iOS devices with names starting with "VSAG"
Write-Host "Fetching devices starting with 'VSAG'..." -ForegroundColor Cyan
$devices = Get-MgDeviceManagementManagedDevice -Filter "startswith(deviceName,'VSAG')" -All

if ($devices.Count -eq 0) {
    Write-Warning "No devices found with name starting with 'VSAG'."
    return
}

# Restart each applicable device
foreach ($device in $devices) {
    $deviceName = $device.DeviceName
    $deviceId = $device.Id
    $platform = $device.OperatingSystem

    if ($platform -like "iOS*") {
        try {
            Invoke-MgDeviceManagementManagedDeviceRestartNow -ManagedDeviceId $deviceId
            Write-Host "Restart command sent to $deviceName" -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to restart $deviceName: $_"
        }
    }
    else {
        Write-Host "Skipping $deviceName (Not iOS)" -ForegroundColor Yellow
    }
}

Disconnect-MgGraph