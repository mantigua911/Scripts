## Loss prevention script 

## Created by Jefrey & Max from IT

<#

Sets execution policy to Unrestricted for this run only. 
After the script finishes, it brings it back to how it was before.

#>
	
Set-ExecutionPolicy Unrestricted -Scope Process -Confirm:$False 

# Ensure Microsoft Graph SDK is installed
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
    Install-Module Microsoft.Graph -Scope CurrentUser -Force
}

Import-Module Microsoft.Graph

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All", "Directory.ReadWrite.All", "BitlockerKey.Read.All"

#1. Identify the Device of the User
$deviceName = Read-Host "Enter the device name"

$device = Get-MgDeviceManagementManagedDevice -Filter "deviceName eq '$deviceName'" -Top 1

if (-not $device) {
    Write-Host "Device not found." 
    exit
}

$deviceId = $device.Id
Write-Host "Found device ID: $deviceId" 

Write-Host "-----------------------------------------------------------------" 


Write-Host "-----------------------------------------------------------------" 

# 2. ADD DEVICES TO "DEPARTING EMPLOYEE DEVICES" GROUP

    ##Get Group ID
    $groupName = "Departing Employees Devices"
    # Get the group
    $group = Get-MgGroup -Filter "displayName eq '$groupName'" -Top 1

    # Show the group ID
    $groupID = $group.Id
    New-MgGroupMemberByRef -GroupId $groupId -BodyParameter @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/devices/$deviceId"
    }
    Write-Host "Device added to group."

Write-Host "-----------------------------------------------------------------" 

# 3. SEND SYNC REQUEST TO DEVICES

    Sync-MgDeviceManagementManagedDevice -ManagedDeviceId $deviceId
    Write-Host "Device sync initiated."

Write-Host "-----------------------------------------------------------------" 

# 4. SEND RESTART REQUEST TO DEVICES

    Restart-MgDeviceManagementManagedDeviceNow -ManagedDeviceId $deviceId
    Write-Host "Device restart initiated."

# Ensure Microsoft Graph SDK is installed
# if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
#     Install-Module Microsoft.Graph -Scope CurrentUser -Force
# }

# Import-Module Microsoft.Graph

# # Connect to Microsoft Graph
# Connect-MgGraph -Scopes "DeviceManagementManagedDevices.PrivilegedOperations.All"

# # Get  devices with names starting with the stored Device name of user 
# Write-Host "Fetching devices starting with '$devices'..." -ForegroundColor Cyan
# $Devices = Get-MgDeviceManagementManagedDevice -Filter "startswith(deviceName,'JDTEST-DEV')" -All

#   # Query installed applications for the device using the beta endpoint
#    $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$deviceId/restartNow"
 
# if ($Devices.Count -eq 0) {
#     Write-Warning "No devices found with name starting with 'VSAG'."
#     return
# }

# # Restart each applicable device
# foreach ($Device in $Devices) {
#      try {
#          Restart-MgDeviceManagementManagedDeviceNow -ManagedDeviceId $device.Id
#          Write-Host "Restart command sent to $($Device.DeviceName)"
#      }
#      catch {
#          Write-Warning "Failed to restart $($Device.DeviceName): $_"
#      }}
    

Write-Host "-----------------------------------------------------------------" 

# 5. RECOVER BITLOCKER KEY

    $recoveryKeys = Get-MgInformationProtectionBitlockerRecoveryKey | Where-Object { $_.DeviceId -eq $deviceId }

Write-Host "-----------------------------------------------------------------" 
# 6. EMAIL INFORMATION COLLECTED (DEVICE NAME + ID, USER, DATE SCRIPT RAN, BITLOCKER RECOVERY KEY)

 #Email Body in HTML Format 
 #Sent to IT
 $MailTo = "mantigua@911memorial.org"

    $body2 = 
@"
    <html>
    <body>
    <br>
    <br>
    Hi IT,<br>
    <br>
    <p>
    This is an automated message from the National Setptember 11th Memorial & Museum IT Department.<br>
    The following list of Actions are regarding the following user $username.
    </p>
    <br>
    $Report 
    <br>
    </body>
    </html>
"@

#Sends Report email to IT with N COLLECTED information (DEVICE NAME + ID, USER, DATE SCRIPT RAN, BITLOCKER RECOVERY KEY)
Send-Mailmessage -smtpServer '10.0.62.75' -Port 25 -from 'Automated Reminder <noReply@911memorial.org>' -to $MailTo -subject  "User Devices"  -body $body2 -bodyasHTML -priority High -ErrorAction Stop -ErrorVariable err




Write-Host "-----------------------------------------------------------------" 

Write-Host "Script completed"

Out-file -FilePath "C:\TEMP\ConfirmationOfCompletion.txt" #enter information collected here

Disconnect-MgGraph