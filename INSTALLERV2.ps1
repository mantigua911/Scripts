<#
	TO-DO FOR VERSION 2.1:
		- UPLOAD TO GITHUB AND HAVE IT RUN BY IEX (DONE?)
		- HAVE IT AUTO-SELECT MSI'S  (EXCEPT CISCO)
		- DEVELOP APP VERIFICATION (Currently on Testing phase)
		- CREATE A DESKTOP SUPPORT (ONLY WORKS FOR LAPTOP AT THE MOMENT)
		- Added Encrypted information for DUO
		- and thats it so far :)
		
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
	cd $ScriptPath


## Variables #####
		#Encryption key must be in the same folder as the installers. 
		$encryptionKey = Get-Content "$ScripthPath\Encryption.key"
		$APIencrypted = Get-Content "$ScripthPath\APIencrypted.encrypted" |ConvertTo-SecureString -Key $encryptionKey
		$iKeyencrypted = Get-Content"$ScripthPath\iKeyencrypted.encrypted" |ConvertTo-SecureString -Key $encryptionKey
		$sKeyencrypted = Get-Content "$ScripthPath\sKeyencrypted.encrypted" |ConvertTo-SecureString -Key $encryptionKey
		
		$nameOfApps = "Dell SecureWorks Red Cloak","Mozilla Firefox (x64 en-US)", "Duo Authentication for Windows Logon x64",  "TeamViewer",  "Google Chrome",  "Teams Machine-Wide Installer",  "Cisco AnyConnect Network Access Manager",  "Cisco AnyConnect Secure Mobility Client", "Cisco AnyConnect Start Before Login Module", "Adobe Acrobat Reader"

	##Configuration File for Cisco (Needs to be run after and IF cisco is installed). It uses the provided location to move the configuration file in this folder to that location
		$source = "$ScriptPath\configuration.xml"
		$destination = "C:\ProgramData\Cisco\Cisco AnyConnect Secure Mobility Client\Network Access Manager\system\"

	## Location of the OLD configuration files (Needs to be run after and IF cisco is installed). It finds and rename the old configuration files
		$filePath = "C:\ProgramData\Cisco\Cisco AnyConnect Secure Mobility Client\Network Access Manager\system\configuration.xml"
		$newPath = "C:\ProgramData\Cisco\Cisco AnyConnect Secure Mobility Client\Network Access Manager\system\configuration_OLD.xml"

	## MSI names (THIS CAN BE MODIFIED AND ADD ANY MSI NAMES YOU WOULD LIKE)
		$nameOfMSI = "googlechromestandaloneenterprise64.msi", "redcloak.msi", "Firefox_Setup_115.0.2.msi", "TeamViewer_Host.msi", "Teams_windows_x64.msi"

	## Cisco MSI Installations
		$ciscoNameOfMsi = "anyconnect-win-4.10.07073-core-vpn-predeploy-k9.msi" ,"anyconnect-win-4.10.07073-nam-predeploy-k9.msi","anyconnect-win-4.10.07073-gina-predeploy-k9.msi"

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
function Install-Apps {
	 param()
	# 1. Install Apps (Cisco gets installed last because it drops network connection once installed) 

		Write-Host "Installing apps... Cisco will be installed"
		foreach($msi in $nameOfMSI) {
			Start-Process msiexec -ArgumentList  "/i $msi /qn " -Wait
			Start-Sleep -Seconds 3
			Write-Host "$msi installed"
		}
		
		Write-Host "Installing Adobe Reader"
		Start-Sleep -Seconds 2
		## INDIVIDUAL .EXE INSTALLERS (They require a different approach for installment, so I separated them)
		# Adobe # 
			Start-Process ".\Adobe.exe" -ArgumentList "/sAll /rs EULA_ACCEPT=YES" -Wait
			Start-Sleep -Seconds 1
		
		Write-Host "Installing DUO"
		Start-Sleep -Seconds 2
		
		."$ScriptPath\config.ps1"
		# DUO #
			. $ScriptPath\duo-win-login-4.2.2.exe  /S /V" /qn IKEY=$iKeyDecrypted SKEY=$sKeyDecrypted HOST=$APIDecrypted AUTOPUSH="#1" FAILOPEN="#0" SMARTCARD="#0" RDPONLY="#0""
			Start-Sleep -Seconds 10
			
	## End of Installing Apps ##
 }
 
function Get-RenameAndJoingDomain {
	 param()
	# 2. Rename + Join the computer to the domain(optional)
		
		#Asks if the user wants to rename the computer
		do{
			$renameComputer = Read-Host -Prompt "Would you like to rename the computer?(Y/N)"
			Start-Sleep -Seconds 1
			
			$renameComputer = $renameComputer.ToUpper()
			
		} while ("Y","N" -NotContains $renameComputer)
		
		# DO the renaming
		switch($renameComputer) {
			
			"Y" {	
				Start-Sleep -Seconds 1
				$renameComputer = Read-Host -Prompt "Enter the name of the computer:" 
				Rename-Computer -NewName $renameComputer -Force
				$computerinfo = hostname
				Start-Sleep -Seconds 1
				"The new computer name is $computerinfo"
				Break
				}
			
			default  {
				Start-Sleep -Seconds 1
				$computerinfo = hostname	
				"The current name of the computer is $computerinfo"
			}
		}
		#Asks to add to the domain
		do{
			Start-Sleep -Seconds 2
			$addDomainAns = Read-Host -Prompt "Would you like to add it to the domain?(Y/N)"
			$addDomainAns = $addDomainAns.ToUpper()
		} while ("Y", "N" -NotContains $addDomainAns)
		
		switch ($addDomainAns) {
			"Y" {
				Start-Sleep -Seconds 1
				ADD-COMPUTER -DOMAINNAME SEPT11MM.ORG -OUPATH "OU=Laptops, OU=Domain Computers,DC=Sept11mm, DC=org"
				$computerinfo = hostname	
				Write-Host "DONE! ... maybe. Please look in the Laptops Organizational Unit for this device $computerinfo"
				Start-Sleep -Seconds 2
				Break
				}
			default{
				"Add to domain skipped. Cisco Anyconnect will be installed next."
				Start-Sleep -Seconds 1
			}
		}
		
	## End of Rename + Join ##
}
 
function Get-WinUpdates {
	param()
	# 3. Install Windows Updates (Optional) 

		$ans1 = Read-Host -Prompt "Would you like to install Windows Updates? (This can take more than 30 minutes)[Y/N]"
		$ans1 = $ans1.toUpper()
		Start-Sleep -Seconds 2
		Write-Host "Please keep in mind there will be a prompt at the end of this requesting to restart"
		
		if ($ans1 -eq "Y") {
			Install-Package NuGet -confirm:$false -force
			Install-Module PSwindowsUpdate -Confirm:$false -force
			import-module PSwindowsUpdate
			install-WindowsUpdate -acceptall 
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
		
		Start-Sleep -Seconds 2
		
		Write-Host "Copying the Unrestricted configuration to the Proper location"
		
		Copy-item -Path $source -Destination $destination
		Start-Sleep -Seconds 2
}
# CISCO + CONFIGURATION FILE COMPLETED #

## BASIC APP VERIFICATION ##
function Verify-Integrity {
	param ()

	foreach($app in $nameOfApps) {
		$MyApp = Get-WmiObject -Class Win32_Product | sort-object Name | select Name | Where  {$_.Name -match $app}
		Start-Sleep -Seconds 2
		If ($MyApp -match $app) {
			Write-Output " $MyApp.name is installed"
		} else {
			Write-output "$MyApp.name is not installed! Please install this manually."
		}
		Start-Sleep -Seconds 2
	}
}
## END OF BASIC APP VERIFICATION ##

## END OF FUNCTIONS## #

## START OF PROGRAM ##

## Information ##

	$computername = hostname
	Write-Host "Current computer name $computername"
	Write-Host "Location of the file $PSScriptRoot"
	Write-host "Starting script...."
	Start-Sleep -Seconds 3
	
	Write-Host "Welcome to Installer V2!
						by 9/11 IT Team"
	
	Start-Sleep -Seconds 2
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
			
		2. Express Install.
			- Install apps and Cisco+Config file. 
			- No Windows Updates, No Rename+Add to domain.
			
		3. Individual Module Install.
			- Prompts to either: Install Apps (not counting Cisco), 
			- Install Cisco, Install Windows Updates(optional), 
				or Rename(optional) + Add to domain (optional)
		4. Exit.
	"
		Start-Sleep -Seconds 2
	} while (1, 2, 3, 4 -NotContains $mainAns)

	switch($mainAns){
		1 {
			Install-Apps;
			Get-RenameAndJoingDomain;
			Get-WinUpdates;
			Install-Cisco;
			Verify-Integrity;
			Break
			}
		2 {
			Install-Apps;
			Install-Cisco;
			Verify-Integrity;
			Break
		}
		3 {do {
			$innerAnsw = Read-Host -Prompt "Individual modules:
			1. Install-apps
			2. Install-Cisco
			3. Install-WindowsUpdates
			4. Rename + Add to Domain
			5. Return to Main
			"
			Start-Sleep -Seconds 2
		} while (1, 2, 3, 4, 5 -NotContains $innerAnsw)
			switch($innerAnsw){
					1 {Install-Apps; Break}
					2 {Install-Cisco; Break}
					3 {Get-WinUpdates; Break}
					4 {Get-RenameAndJoingDomain; Break}
					default {"----------------------------------------------------------------"}
				}
			}
		default {$returnCode = 1;}
	}
} while ($returnCode -eq 0)

## END OF PROGRAM ##
Read-host -prompt "Finished. Please verify everything has been properly installed, and RESTART the computer"