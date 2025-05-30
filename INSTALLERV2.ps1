<#
	Developed by Maximo Antigua
	02/13/2024 
	Feel free to add any modifications

#>											  
<#

Sets execution policy to Unrestricted for this run only. 
After the script finishes, it brings it back to how it was before.

#>
	
Set-ExecutionPolicy Unrestricted -Scope Process -Confirm:$False 

<#
This sets the location to the 
opened Admin powershell to the location of the Installer
#>

cd \
	if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript")
 		{ $ScriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition }
 	else
 		{ $ScriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0]) 
     if (!$ScriptPath){ $ScriptPath = "." } }
$pathToScript = $ScriptPath
cd $ScriptPath

## Variables #####
		#Encryption key must be in the same folder as the installers. 
		$encryptionKey = Get-Content $pathToScript\Encryption.key
		$APIencrypted = Get-Content $pathToScript\APIencrypted.encrypted |ConvertTo-SecureString -Key $encryptionKey
		$iKeyencrypted = Get-Content $pathToScript\iKeyencrypted.encrypted |ConvertTo-SecureString -Key $encryptionKey
		$sKeyencrypted = Get-Content $pathToScript\sKeyencrypted.encrypted |ConvertTo-SecureString -Key $encryptionKey
		
		$nameOfApps = "Dell SecureWorks Red Cloak", "Duo Authentication for Windows Logon x64",  "TeamViewer",  "Google Chrome",  "Teams Machine-Wide Installer", "Adobe Acrobat Reader", "Cisco Secure Client - AnyConnect VPN","Cisco Secure Client - Network Access Manager", "Cisco Secure Client - Start Before Login"

	## Location of the OLD configuration files (Needs to be run after and IF cisco is installed). It finds and rename the old configuration files
		$filePath = "C:\ProgramData\Cisco\Cisco Secure Client\Network Access Manager\system\configuration.xml"
		$newPath = "C:\ProgramData\Cisco\Cisco Secure Client\Network Access Manager\system\configuration_OLD.xml"

	## MSI names (THIS CAN BE MODIFIED AND ADD ANY MSI NAMES YOU WOULD LIKE)
		$nameOfMSI = "googlechromestandaloneenterprise64.msi", "Firefox_Setup_133.0.3.msi", "TeamViewer_Host.msi", "Teams_windows_x64.msi", "Webex.msi"
		$ArgumentsList = "/i $msi /qn "
	##Cisco MSI Installations (LAPTOPS AND DESKTOPS)
	## Configuration File for Cisco (Needs to be run after and IF cisco is installed). It uses the provided location to move the configuration file in this folder to that location
	function Test-IsLaptop {
		$HardwareType = (Get-WmiObject -Class Win32_ComputerSystem -Property PCSystemType).PCSystemType
		# https://docs.microsoft.com/en-us/windows/win32/cimwin32prov/win32-computersystem
		# Mobile = 2
		# Desktop = 1
		$HardwareType -eq 2
	}

	if(Test-IsLaptop){
		$ciscoNameOfMsi = "cisco-secure-client-win-5.1.7.80-core-vpn-predeploy-k9.msi" ,"cisco-secure-client-win-5.1.7.80-nam-predeploy-k9.msi",
		"cisco-secure-client-win-5.1.7.80-sbl-predeploy-k9.msi","cisco-secure-client-win-5.1.7.80-umbrella-predeploy-k9.msi"
		$source = "$pathToScript\Config_profile\configuration.xml"
		Write-Host "THIS IS A LAPTOP"

	} else {
		$ciscoNameOfMsi = "cisco-secure-client-win-5.1.7.80-core-vpn-predeploy-k9.msi" ,"cisco-secure-client-win-5.1.7.80-nam-predeploy-k9.msi"
		,"cisco-secure-client-win-5.1.7.80-umbrella-predeploy-k9.msi"
		$source = "$pathToScript\Config_profile\configuration.xml"
		Write-Host "THIS IS A DESKTOP" 
		$umbrellaPath = "C:\ProgramData\Cisco\Cisco Secure Client\Umbrella"
	}
	$destination = "C:\ProgramData\Cisco\Cisco Secure Client\Network Access Manager\system\"
## End of Variables ##

## Decrypt ##
# 1.
$secure= $APIencrypted

$tempCred=New-Object -TypeName PSCredential -ArgumentList 'temp',$secure

$APIDecrypted = $tempCred.GetNetworkCredential().Password
Remove-Variable tempCred

#2. 
$secure= $iKeyencrypted

$tempCred=New-Object -TypeName PSCredential -ArgumentList 'temp',$secure

$iKeydecrypted = $tempCred.GetNetworkCredential().Password
Remove-Variable tempCred

#3. 
$secure= $sKeyencrypted

$tempCred=New-Object -TypeName PSCredential -ArgumentList 'temp',$secure

$sKeyDecrypted=$tempCred.GetNetworkCredential().Password
Remove-Variable tempCred

## End of Decrypt ##

##Functions##

# Define global variables for script execution.
$LogFile = "$pathToScript\InstallLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Function to log messages to a file
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp [$Level] $Message" | Out-File -Append -FilePath $LogFile
    Write-Host "$Timestamp [$Level] $Message"
}

function Install-Apps {
	 param()
	# 1. Install Apps (Cisco gets installed last because it drops network connection once installed) 

		Write-Host "Installing apps..."
			foreach($msi in $nameOfMSI) {
				Write-Log "Starting installation of: $msi"
				Start-Process msiexec -ArgumentList  $ArgumentsList -Wait
				Start-Sleep -Seconds 5
				Write-Host "$msi installed"
	
				
				Write-Log "Installation completed for: $msi"
			}
			## INDIVIDUAL .EXE INSTALLERS (They require a different approach for installment, so I separated them) - MAX
			Write-Host "Attempting to install Adobe Reader"
			Start-Sleep -Seconds 2
			# Adobe # 
			Write-Log "Starting installation of: Adobe Reader"
			Start-Process ".\Adobe.exe" -ArgumentList "/sAll /rs EULA_ACCEPT=YES" -Wait
			Start-Sleep -Seconds 2
			
			Write-Host "Attempting to install DUO"
			Start-Sleep -Seconds 2
			# DUO #
			Write-Log "Starting installation of: DUO"
			.\duo-win-login-4.2.2.exe /S /V" /qn IKEY="$iKeyDecrypted" SKEY="$sKeyDecrypted" HOST="$APIDecrypted" AUTOPUSH="#1" FAILOPEN="#0" SMARTCARD="#0" RDPONLY="#0""
			Start-Sleep -Seconds 5
	## End of Installing Apps ##
 }
 
function Get-RenameAndJoingDomain {
	 param()
	# 2. Rename + Join the computer to the domain(optional)
		
		#Asks if the user wants to rename the computer
		do{
			$renameComputer = Read-Host -Prompt "Would you like to rename the computer?(Y/N)"
			Write-Host "The current name of the computer is "
			hostname
			Start-Sleep -Seconds 1
			
			$renameComputer = $renameComputer.ToUpper()
			
		} while ("Y","N" -NotContains $renameComputer)
		
		# DO the renaming
		switch($renameComputer) {
			
			"Y" {	
				Start-Sleep -Seconds 1
				$renameComputer = Read-Host -Prompt "Enter the name of the computer" 
				# Write-Host "Please enter the local admin login"
				Start-Sleep -Seconds 3
				Rename-Computer -NewName $renameComputer 
				Start-Sleep -Seconds 2
				Break
				}
			
			default  {}
		}
		#Asks to add to the domain
		do{
			Start-Sleep -Seconds 2
			$addDomainAns = Read-Host -Prompt "Would you like to add it to the domain?(Y/N)"
			$addDomainAns = $addDomainAns.ToUpper()
		} while ("Y", "N" -NotContains $addDomainAns)
		
		switch ($addDomainAns) {
			"Y" {
				Write-Host "Please enter your AD Admin credentials"
				Start-Sleep -Seconds 2

					ADD-COMPUTER -DOMAINNAME sept11mm.org 
				
				Write-Host "DONE! ... maybe. Please look in the Computer Organizational Unit."
				Start-Sleep -Seconds 2
				Break
				}
			default{}
		}
		
	## End of Rename + Join Domain ##
}
 
function Get-WinUpdates {
	param()
	# 3. Install Windows Updates (Optional) 

		$ans1 = Read-Host -Prompt "Would you like to install Windows Updates? (This can take more than 30 minutes)[Y/N]"
		$ans1 = $ans1.toUpper()
		Start-Sleep -Seconds 2
		
		if ($ans1 -eq "Y") {

			if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) 
			{
			  Install-PackageProvider -Name NuGet -Force
			  Install-Module -Name PSWindowsUpdate -Confirm:$false -Force   
			}
			
			# Import PSWindowsUpdate module
			Import-Module PSWindowsUpdate
			
			# Start updating windows without reboot
			Get-WindowsUpdate -AcceptAll -Install -IgnoreReboot

		} else {

			Write-host "Windows Updates skipped." 
			Start-Sleep -Seconds 3
		}
}

function Install-Cisco {
	param()
	# 4. Install Cisco Anyconnect + Move configuration file to folder

		foreach($msi in $ciscoNameOfMsi) {
			Start-Process msiexec -ArgumentList  "/i $msi /qn /norestart" -Wait
			Start-Sleep -Seconds 3
			Write-Host "$msi installed"
		}
		
		Write-host "Renaming current configuration file to configuration_OLD"
		Rename-Item -Path $filePath -NewName  $newPath
		
		Write-Host "Copying the Unrestricted configuration to the proper location"
		Start-Sleep -Seconds 2
		Copy-item -Path $source -Destination $destination

		# if (Test-IsLaptop){
		# 	# Rename-Item -Path "C:\ProgramData\Cisco\Cisco Secure Client\Network Access Manager\system\configuration.xml" -NewName  $filePath
		# } else {
		# 	# Rename-Item -Path "C:\ProgramData\Cisco\Cisco Secure Client\Network Access Manager\system\configuration.xml" -NewName  $filePath
		# }
		
		Write-Host "Done!"
}
# CISCO + CONFIGURATION FILE COMPLETED #

## BASIC APP VERIFICATION ##
function Verify-Integrity {
	param ()

	foreach($app in $nameOfApps) {

	try {
        # Write-Log "Checking if software is installed: $app"
        $InstalledSoftware = Get-CimInstance -ClassName Win32_Product | Where-Object { $_.Name -like "*$app*" }
        return $InstalledSoftware -ne $null
    } catch {
        Write-Log "Error while checking software: $app. $_" "ERROR"
        throw $_
    }
		Start-Sleep -Seconds 2
	}
	Write-Host "All apps installed succesfully!`n"
	Start-Sleep -Seconds 2

	Write-Host "
	Verifying CISCO configuration files.... `n"
	Start-Sleep -Seconds 1

	if( (Test-Path $newPath) -and (Test-Path $filepath)) {
		Write-Host "
		Old configuration was renamed... `n"
		Start-Sleep -Seconds 2
		Write-Host "New configuration file was installed properly `n"
	} else {
		Write-Host "
		The configuration files have not been installed for Cisco.

		Please do it manually before restarting. `n"
		}
	Write-Host "Verification completed!`n"
	Start-Sleep -Seconds 2
}
## END OF BASIC APP VERIFICATION ##

## CHK DSK + DISM + SFC ##
function Check-Disk {
	param ()
	Write-Host "Starting to verify E: Disk integrity.... `n "
	SFC /SCANNOW

	DISM /ONLINE /CLEANUP-IMAGE /CHECKHEALTH 

	DISM /ONLINE /CLEANUP-IMAGE /SCANHEALTH

	DISM /ONLINE /CLEANUP-IMAGE /RESTOREHEALTH /Source:repairSource\install.wim

	Write-Output Y| CHKDSK C: /F /R /X /scan /perf 
}

## END OF FUNCTIONS## #

## START OF PROGRAM ##

## Information ##
	Write-Host "-----------------------------------------------------------------" 
	Write-Host "****Location of the file $PSScriptRoot****"
	Write-host "****Starting script....****"
	Start-Sleep -Seconds 3
	
	Write-Host "****Welcome to General InstallerV2.5 by the 9/11 IT Team****"
	Start-Sleep -Seconds 2
	Write-Host "-----------------------------------------------------------------" 
do {	
	$returnCode = 0
	do {
	$mainAns = Read-host -Prompt "
		Please select your options (single digit integers only):
		
		1. Full Install.
			- Install all the apps(in the folder), 
			- Renames + Adds to the domain (optional), 
			- Install Windows Updates(optional), and 
			- Install Cisco + Configuration Profile.
			- Verify installations (In testing phase)
			- Runs SFC+DISM+CHKDSK Scan
			
		2. Express Install.
			- Install apps and Cisco+Config file. 
			- No Windows Updates, No Rename+Add to domain.
			- Verify Installations (In testing phase)
			
		3. Individual Module Install.
			- Prompts to either: Install Apps (not counting Cisco), 
			Install Cisco, Install Windows Updates(optional), 
			Rename(optional) + Add to domain (optional) or
			- Run SFC+DISM+CHKDSK Scan

		4. Exit.
						"
	Write-Host "-----------------------------------------------------------------" 
		Start-Sleep -Seconds 2
		$cleanMainAns = $mainAns -replace " ",""
	} while (1, 2, 3, 4 -NotContains $cleanMainAns)
	Write-Host "-----------------------------------------------------------------" 
	switch($cleanMainAns){
		1 {
			Install-Apps;
			Get-RenameAndJoingDomain;
			Get-WinUpdates;
			Install-Cisco;
			Verify-Integrity;
			Check-Disk;
			Break
			}
		2 {
			Install-Apps;
			Install-Cisco;
			Verify-Integrity;
			Break
		}
		3 {do {
			$innerAnsw = Read-Host -Prompt "	Individual modules:
			1. Install-apps
			2. Install-Cisco
			3. Install-WindowsUpdates
			4. Rename + Add to Domain
			5. Verify Installations
			6. SFC+DISM+CHKDSK Scan
			7. Return to Main
				"
			Start-Sleep -Seconds 2
		} while (1, 2, 3, 4, 5, 6, 7 -NotContains $innerAnsw)
			switch($innerAnsw){
					1 {Install-Apps; Break}
					2 {Install-Cisco; Break}
					3 {Get-WinUpdates; Break}
					4 {Get-RenameAndJoingDomain; Break}
					5 {Verify-Integrity; Break}
					6 {Check-Disk; Break}
					default {"*blerp*"}
				}
			}
		default {$returnCode = 1;}
	}
} while ($returnCode -eq 0)
Write-Host "-----------------------------------------------------------------" 
$ans = Read-Host -Prompt "Would you like to restart this device?(Y/N)"
if ($ans.ToUpper() -eq "Y"){
	Write-Host "Done. The computer will restart 5 seconds after this message."
	Start-Sleep -Seconds 5
	Restart-Computer -Force
} else {
	Read-Host "Boooring =("
}

## END OF PROGRAM ##