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

Write-Host "-----------------------------------------------------------------" 

# 5. RECOVER BITLOCKER KEY

Write-Host "-----------------------------------------------------------------" 
# 6. EMAIL INFORMATION COLLECTED (DEVICE NAME + ID, USER, DATE SCRIPT RAN, BITLOCKER RECOVERY KEY)

Write-Host "-----------------------------------------------------------------" 

Write-Host "Script completed"

Out-file -FilePath "C:\TEMP\ConfirmationOfCompletion.txt" #enter information collected here

Disconnect-MgGraph