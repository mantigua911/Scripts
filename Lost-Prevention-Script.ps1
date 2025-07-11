## Loss prevention script 

## Created by Jefrey & Max from IT

<#

Sets execution policy to Unrestricted for this run only. 
After the script finishes, it brings it back to how it was before.

#>
	
Set-ExecutionPolicy Unrestricted -Scope Process -Confirm:$False 

# Get user by email from AD
# %%%%%% Gather Need User Information %%%%%%
$username = Read-Host -Prompt "Enter the username"
$userexists = get-ADuser -filter { SamAccountName -eq $username } -ErrorAction SilentlyContinue


# ===================================
# %%%%%% Verify User Existance %%%%%%
if (!$userexists)
{
    Write-Host "Invalid User. Cancelling."
    return
}

# =======================================================
# %%%%%% Verify If The Compromised User Is Correct %%%%%%
$user_fullname = Get-ADUser -Identity  $username -Properties DisplayName | Select -expand DisplayName
$userEmail = Get-AdUser -Identity mantigua | Select -Expand UserPrincipalName


# Ensure Microsoft Graph SDK is installed
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
    Install-Module Microsoft.Graph -Scope CurrentUser -Force
}

Import-Module Microsoft.Graph

# Connect to Microsoft Graph
Connect-MgGraph 


Write-Host "-----------------------------------------------------------------" 

# 1. COLLECT DEVICES ASSIGNED TO USER

# Get user by email
try {
    $user = Get-MgUser -UserId $UserEmail
}
catch {
    Write-Error "User '$UserEmail' not found."
    return
}

# Get all devices assigned to the user
$devices = Get-MgDeviceManagementManagedDevice -Filter "userId eq '$($user.Id)'" -All

if ($devices.Count -eq 0) {
    Write-Host "No devices found for user: $UserEmail" -ForegroundColor Yellow
} else {
    Write-Host "Devices assigned to $UserEmail :`n" -ForegroundColor Cyan
    $devices | Select-Object DeviceName, OperatingSystem, ComplianceState, ManagementAgent, Id | Format-Table -AutoSize
}


Write-Host "-----------------------------------------------------------------" 

# 2. ADD DEVICES TO "DEPARTING EMPLOYEE DEVICES" GROUP

Write-Host "-----------------------------------------------------------------" 

# 3. SEND SYNC REQUEST TO DEVICES

Write-Host "-----------------------------------------------------------------" 

# 4. SEND RESTART REQUEST TO DEVICES

# Ensure Microsoft Graph SDK is installed
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
    Install-Module Microsoft.Graph -Scope CurrentUser -Force
}

Import-Module Microsoft.Graph

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.PrivilegedOperations.All"

# Get  devices with names starting with the stored Device name of user 
Write-Host "Fetching devices starting with '$devices'..." -ForegroundColor Cyan
$Devices = Get-MgDeviceManagementManagedDevice -Filter "startswith(deviceName,'JDTEST-DEV')" -All

  # Query installed applications for the device using the beta endpoint
   $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$deviceId/restartNow"
 
if ($Devices.Count -eq 0) {
    Write-Warning "No devices found with name starting with 'VSAG'."
    return
}

# Restart each applicable device
foreach ($Device in $Devices) {
     try {
         Restart-MgDeviceManagementManagedDeviceNow -ManagedDeviceId $device.Id
         Write-Host "Restart command sent to $($Device.DeviceName)"
     }
     catch {
         Write-Warning "Failed to restart $($Device.DeviceName): $_"
     }}
    

Write-Host "-----------------------------------------------------------------" 

# 5. RECOVER BITLOCKER KEY

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
    The following list of Actions are regarding the Ffollowing user $username.
    </p>
    <br>
    $Report
    <br>
    </body>
    </html>
"@

#Sends Report email to IT with N COLLECTED information (DEVICE NAME + ID, USER, DATE SCRIPT RAN, BITLOCKER RECOVERY KEY)
Send-Mailmessage -smtpServer '10.0.62.75' -Port 25 -from 'Automated Reminder <noReply@911memorial.org>' -to $MailTo -subject "Expired Password Accounts" -body $body2 -bodyasHTML -priority High -ErrorAction Stop -ErrorVariable err




Write-Host "-----------------------------------------------------------------" 

Write-Host "Script completed"

Out-file -FilePath "C:\TEMP\ConfirmationOfCompletion.txt" #enter information collected here

Disconnect-MgGraph