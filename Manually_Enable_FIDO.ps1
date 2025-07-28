<#
	Developed by Maximo Antigua
	06/23/2025 
	Feel free to add any modifications after copying the file.
#>											  
<#

Sets execution policy to Unrestricted for this run only. 
After the script finishes, it brings it back to how it was before.

#>

## Checks if the process is running as admin, if not it opens a new one with admin permissions
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))  
{  
  $arguments = "& '" +$myinvocation.mycommand.definition + "'"
  Start-Process powershell -Verb runAs -ArgumentList $arguments
  Break
}


Set-ExecutionPolicy Unrestricted -Scope Process -Confirm:$False 

## Modify an existing reg key

$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\FIDO"
$valueName = "EnableFIDODeviceLogon"
$valueData = 1

# Check if the registry path exists

if (Test-Path $regPath) {
    # Check if the value exists

    $value = Get-ItemProperty -Path $regPath -Name $valueName -ErrorAction SilentlyContinue
    
    if ($null -ne $value) {
        # Value exists, set it to 1

        Set-ItemProperty -Path $regPath -Name $valueName -Value $valueData
        Write-Output "Value '$valueName' updated to $valueData."

    } else {
        # Value does not exist, create it

        New-ItemProperty -Path $regPath -Name $valueName -Value $valueData -PropertyType DWord
        Write-Output "Value '$valueName' created with value $valueData."

    }
} else {

    # Registry path does not exist, create it and the value
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft" -Name "FIDO" -Force | Out-Null
    New-ItemProperty -Path $regPath -Name $valueName -Value $valueData -PropertyType DWord
    Write-Output "Registry path and value '$valueName' created with value $valueData."

}
## Uninstall DUO

Start-Process -FilePath msiexec.exe -ArgumentList @( '/x "{15393052-A362-41DF-969E-638A2A07F7AD}"')

Write-Host "Process Complete."

Read-Host -Prompt "Press Enter to close..."