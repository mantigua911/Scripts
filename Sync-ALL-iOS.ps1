if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))  
{  
  $arguments = "& '" +$myinvocation.mycommand.definition + "'"
  Start-Process powershell -Verb runAs -ArgumentList $arguments
  Break
}


Connect-MSGraph -AdminConsent
Write-Host "Pulling Audio Guide information. Please wait...`n" 

$DevicesToSync = Get-IntuneManagedDevice | Get-MSGraphAllPages | where-object {($_.managementAgent -eq 'mdm' ) -and ($_.DeviceName -Like "VSAG*")}
do {
	Write-Host "Would you like to do it in BATCHES, ALL devices, or for a SINGLE device?(B for Batches/A for All/S for Single)"
	$ans = Read-Host
	Start-Sleep -Seconds 3

	switch ($ans.ToUpper()) {
		"B" 
		{ 
			Write-Host "The last number being currently used is $($DevicesToSync.DeviceName[-1])"
			Start-Sleep -Seconds 2
		
			$start = Read-Host "AG number to beginning at"
			$end = Read-Host "AG number to end at"
		
			Foreach ($Device in $DevicesToSync)
			{
					$SplitDevice = $Device.DeviceName.Split("G")
				If (($SplitDevice[-1] -ge $start) -and ($SplitDevice[-1] -le $end)) 
				{
					Invoke-IntuneManagedDeviceSyncDevice -managedDeviceID $Device.azureADDeviceId
					Write-Host "Sending Sync request to Device with Name $($Device.deviceName)" -ForegroundColor Green
				}
		
			}
		}
		"S" 
		{
			$valToCheck = Read-Host -Prompt "Which device would you like to SYNC?(ONLY the Numbers)"
			Foreach ($Device in $DevicesToSync)
			{
				$SplitDevice = $Device.DeviceName.Split("G")
				if ($($SplitDevice[-1] -eq $valToCheck)) {
					Invoke-IntuneManagedDeviceSyncDevice -managedDeviceId $Device.azureADDeviceId
					Write-Host "Sending Sync request to Device with Name $($Device.deviceName)" -ForegroundColor Green
				}
			}	
		}
		Default 
		{
			Foreach ($Device in $DevicesToSync)
			{
				Invoke-IntuneManagedDeviceSyncDevice -managedDeviceId $Device.azureADDeviceId
				Write-Host "Sending Sync request to Device with Name $($Device.deviceName)" -ForegroundColor Green
			}
		}
	}
	$repeat = Read-Host -Prompt "Would you like to do any other device?(Y/N) `n"
} while ($repeat.ToUpper() -eq "N")
Read-Host "Completed"