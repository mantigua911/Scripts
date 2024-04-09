Connect-MSGraph
Write-Host "Pulling Audio Guide information. Please wait...`n" 

$DevicesToSync = Get-IntuneManagedDevice | Get-MSGraphAllPages | where-object {($_.managementAgent -eq 'mdm' ) -and ($_.DeviceName -Like "VSAG*")}

 

Write-Host "Would you like to do it in BATCHES or ALL devices?(B for Batches/A for All)"
$ans = Read-Host
Start-Sleep -Seconds 3

if ($ans.toUpper() -eq "B")
{
	Write-Host "The last number being currently used is $($DevicesToSync.DeviceName[-1])"
	Start-Sleep -Seconds 2

	$start = Read-Host "AG number to being at"
	$end = Read-Host "AG number to end at"

	Foreach ($Device in $DevicesToSync)
	{
  		$SplitDevice = $Device.DeviceName.Split("G")
		If (($SplitDevice[-1] -gte $start) -and ($SplitDevice[-1] -lte $end)) 
		{
			Invoke-IntuneManagedDeviceSyncDevice -managedDeviceID $Device.managedDeviceId
	Write-Host "Sending Sync request to Device with Name $($Device.deviceName)" -ForegroundColor Green
		}
  
	}
} else {
	Foreach ($Device in $DevicesToSync)
	{
	Invoke-IntuneManagedDeviceSyncDevice -managedDeviceId 	$Device.managedDeviceId
	Write-Host "Sending Sync request to Device with Name 	$($Device.deviceName)" -ForegroundColor Green
  	}
}