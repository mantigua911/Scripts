# ------------------------------------------
#
#
# Purpose To Decommission Users
# Created by Jefrey Diaz 
# Date Last Modified: 02/20/2024
# Latest version Please test
# 
#
# ------------------------------------------

# ==========================================
# %%%%%% Gather Need User Information %%%%%%
$username = Read-Host -Prompt "Enter The Username Of The Compromised Account:"
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
$user_fullname = Get-ADUser -Identity  $username -Properties DisplayName | select -expand DisplayName
$user_title = Get-ADUser -Identity  $username -Properties Title | select -expand Title

$response = (Read-Host "Please Verify That The Compromised User Is Correct: '$user_fullname | $user_title'? (Y) / (N)").ToLower()
# ------setting any input to lower case so we dont have to check if a user entered a lowercase or uppercase response ------

if (($response -ne 'y'))
{
    Write-Host "Cancelling"
    return
}

Write-Host ("Beginning Disabling Process")

$initials = (Read-Host "Please enter the 1st initials of your first name and last name to begin the decommission proccess:").ToUpper()
$date = Get-Date -Format "yyMMdd"
$decommission_description = "Decommission $date $initials"

# ==================================================================
# %%%%%% Use the built-in Microsoft random password generator %%%%%%
                           # %%%% AD %%%%


add-type -AssemblyName System.Web
$Password = [System.Web.Security.Membership]::GeneratePassword(20,4) #create a random password of 20 characters in length and with 2 non-alpha numeric characters
set-ADAccountPassword -Identity $username -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $Password -Force)

Write-Host ("Password Reset In AD")
Write-Host ("-----")

# --- Edit user General tab ---
Set-ADUser -Identity $username -Description "$decommission_description"
#we must use the LDAP display name for the attributes when using the -clear function. We must use -clear because we cant set attributes to blank using strings
Set-ADUser -Identity $username -clear physicalDeliveryOfficeName, telephoneNumber, wWWHomePage
Write-Host ("User General tab cleared In AD")
Write-Host ("-----")

# --- Edit first name ---
$user_firstname = (Get-ADUser -Identity  $username -Properties GivenName | select -expand GivenName)
$user_firstname = "Former Employee: $user_firstname"
Set-ADUser -Identity $username -GivenName $user_firstname
Write-Host ("First Name set To '$user_firstname'")
Write-Host ("-----")

# --- Edit display name ---
$user_displayname = Get-ADuser -Identity $username -Properties DisplayName | Select-Object -ExpandProperty DisplayName
$user_displayname = "Former Employee: $user_displayname"
Set-ADUser -Identity $username -DisplayName $user_displayname
Write-Host ("Display Name set To '$user_displayname'")
Write-Host ("-----")


# --- Remove every group ---
Get-ADUser -Identity $username -Properties MemberOf | ForEach-Object {
  $_.MemberOf | Remove-ADGroupMember -Members $username -Confirm:$false
  Write-Host ("User Removed From '$_.MemberOf'In AD")
 }

# ------ Clear Organization tab -------

Set-ADUser -Identity $username -clear title, department, company, manager


# ------ Uncheck "Protect from accidental deletion" -------

Get-ADUser $username | Set-ADObject -ProtectedFromAccidentalDeletion:$false -PassThru

Write-Host ("Edited First Name and Display Name. Cleared Office, Telephone number, Web page, Changed Description, Uncheck 'Protect from accidental deletion'.")
Write-Host ("-----")


#===========================================
# %%%%%%%%%%%%%%%% Azure AD %%%%%%%%%%%%%%%%


Connect-AzureAD

Write-Host ("--- Beginning Disabling Process On Azure AD ---")

# ------ Revoke Token For All Active Sessions ------
Revoke-AzureADUserAllRefreshToken -ObjectId "$username@911memorial.org"

# ------ Block sign in ------
Set-AzureADUser -ObjectId "$username@911memorial.org" -AccountEnabled $False

# ------ Set Password ------
Set-AzureADUserPassword -ObjectId "$username@911memorial.org" -Password (ConvertTo-SecureString -AsPlainText $Password -Force)

$user = Get-AzureADuser -ObjectId "$username@911memorial.org"

# ------ Remove from all Groups Azure AD ------
foreach ($group in get-azureadusermembership -objectid $user.ObjectId -all $true){
    
   try {
        $group_name = $group.DisplayName
        Remove-AzureADGroupMember -ObjectId $group.objectid -MemberId $user.ObjectId -Erroraction Stop
        Write-Host -f Green ("Removed user from: $group_name")
        #Remove-DistributionGroup -Identity " File Server Managers "  
   }
    catch {
    Write-Output -f Red ("Could not remove user from $group_name - $($_.Exception.Message)")
    #$DistributionGroups += "$($group_name)"
    }
}

Write-Host ("Token For All Active Sessions Revoked, Blocked sign in. Reset password On Azure & Removed from AzureAD groups.")
Write-Host ("-----")

Write-Host ("Running AD Sync. Asking for credentials.")

# ------ AD Sync From M365 Server ------
$cred = Get-Credential -Credential OFFICE365
$session = New-PSSession -computerName NSM264M365DS01 -credential $cred
# ------ Initiate AD Sync From Server ------
Invoke-Command -Session $session -Scriptblock {Start-ADSyncSyncCycle -PolicyType Initial}
Start-Sleep -Seconds 5
Remove-PSSession $session
Write-Host ("AD Sync ran. Waiting for 1 minute for changes to process.")
Start-Sleep -Seconds 60
Write-Host ("Sync Complete") 
Write-Host ("-----")  

# Optional: Verify removal by listing the groups again
$userGroupsAfterRemoval = Get-AzureADUserMembership -ObjectId $user.ObjectId
if ($userGroupsAfterRemoval.Count -eq 0) {
    Write-Host -f Green ("User $username is no longer a member of any groups.")
} else {
    Write-Host -f Red ("User $userUPN is still a member of the following groups: $($userGroupsAfterRemoval.DisplayName)")
}

Write-Host ("Disabled Outlook on the Web, ActiveSync, Exchange Web Services, IMAP, POP3, and MAPI.")
Write-Host ("-----")

#=================================================
# %%%%%%%%%%%%%%%%%%% Exchange %%%%%%%%%%%%%%%%%%%


Connect-ExchangeOnline

Write-Host ("--- Beginning Disabling Process On Exchange Online ---")

foreach ($MailGroup in Get-DistributionGroup | Where-Object { (Get-DistributionGroupMember $_.Identity).PrimarySmtpAddress -eq "$username@911memorial.org" } ){
    
   try {
        Remove-DistributionGroupMember -Identity $MailGroup.Identity -Member "$username@911memorial.org" -Confirm:$false  -Erroraction Stop
        Write-Host -f Green ("Removed user $username from mail-enabled group: $($MailGroup.DisplayName)")
   }
    catch {
    Write-Output -f Red ("Could not remove user from $MailGroup - $($_.Exception.Message)")
    }
}

# ------ AD Sync From M365 Server ------
$cred = Get-Credential -Credential OFFICE365
$session = New-PSSession -computerName NSM264M365DS01 -credential $cred
# ------ Initiate AD Sync From Server ------
Invoke-Command -Session $session -Scriptblock {Start-ADSyncSyncCycle -PolicyType Initial}
Start-Sleep -Seconds 5
Remove-PSSession $session
Write-Host ("AD Sync ran. Waiting for 1 minute for changes to process.")
Start-Sleep -Seconds 60
Write-Host ("Sync Complete") 
Write-Host ("-----")  


# Optional: Verify the user has been removed from groups
$userGroupsAfterRemoval = Get-AzureADUserMembership -ObjectId $user.ObjectId
$mailEnabledGroupsAfterRemoval = Get-DistributionGroupMember -Identity "$username@911memorial.org"

if ($userGroupsAfterRemoval.Count -eq 0 -and $mailEnabledGroupsAfterRemoval.Count -eq 0) {
    Write-Host -f Green ("User $username is no longer a member of any Azure AD or mail-enabled groups.")
} else {
    Write-Host -f Red ("User $username is still a member of the following groups:
    $($userGroupsAfterRemoval.DisplayName)
    $($mailEnabledGroupsAfterRemoval.DisplayName)")
}

# ------ Disable Outlook on the web, Exchange ActiveSync, IMAP, POP3, MAPI ------
Set-CASMailbox "$username@911memorial.org" -OWAEnabled $False -ActiveSyncEnabled $False -EWSEnabled $False -ImapEnabled $False -PopEnabled $False -MAPIEnabled $False

Write-Host ("Disabled Outlook on the Web, ActiveSync, Exchange Web Services, IMAP, POP3, and MAPI.")
Write-Host ("-----")

#========================
# %%%%% M365 Server %%%%%


Write-Host ("Running AD Sync. Asking for credentials.")

# ------ AD Sync From M365 Server ------
$cred = Get-Credential -Credential OFFICE365
$session = New-PSSession -computerName NSM264M365DS01 -credential $cred
# ------ Initiate AD Sync From Server ------
Invoke-Command -Session $session -Scriptblock {Start-ADSyncSyncCycle -PolicyType Initial}
Start-Sleep -Seconds 5
Remove-PSSession $session 
Write-Host ("AD Sync ran. Waiting for 2 minutes for changes to process.")
Start-Sleep -Seconds 120
Write-Host ("Sync Complete") 
Write-Host ("-----")  


# ==============
# %%%%% AD %%%%%
# %%%% Last %%%%


Write-Host ("Disabling AD User Account, Moving User to Disabled Users OU & Moving Computer To Computers OU")

# ------ Disable Account ------
Disable-ADAccount -Identity $username
# ------ Move User ------
Get-ADUser -Identity $username | Move-ADObject -TargetPath "OU=Disabled Users,DC=sept11mm,DC=org"
# ------ Move PC ------
#Get-ADComputer -Identity $PCname | Move-ADObject -TargetPath "OU=Computers,DC=Sept11mm, DC=org"

Write-host ("Disabled account and moved account to Disabled Users OU. User decommission complete!")
Write-Host ("-----")  
Write-Host ("Feel free to post this on the decommission ticket: Decommissioned. Password reset in both AD and O365, sign-in blocked, removed from AD groups and Office 365 groups, AD profile updated, sync broken, mailbox 
features disabled, Litigation hold checked and enabled if necessary, AD profile disabled and moved to Disabled Users, MS licenses removed. Currently in M365 Deleted Users.")
Read-Host -Prompt "Done"