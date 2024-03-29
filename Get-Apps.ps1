
$computers = hostname
$tempLoc = "C:\TEMP\APPS.txt"
$array = @()

foreach($pc in $computers){

    $computername=$pc.computername

    #Define the variable to hold the location of Currently Installed Programs

    $UninstallKey=”SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall” 

    #Create an instance of the Registry Object and open the HKLM base key

    $reg=[microsoft.win32.registrykey]::OpenRemoteBaseKey(‘LocalMachine’,$computername) 

    #Drill down into the Uninstall key using the OpenSubKey Method

    $regkey=$reg.OpenSubKey($UninstallKey) 

    #Retrieve an array of string that contain all the subkey names

    $subkeys=$regkey.GetSubKeyNames() 

    #Open each Subkey and use GetValue Method to return the required values for each

    foreach($key in $subkeys){

        $thisKey=$UninstallKey+”\\”+$key 

        $thisSubKey=$reg.OpenSubKey($thisKey) 

        $obj = New-Object PSObject
        
        $obj | Add-Member -MemberType NoteProperty -Name “DisplayName” -Value $($thisSubKey.GetValue(“DisplayName”))
        $obj | Add-Member -MemberType NoteProperty -Name “InstallLocation” -Value $($thisSubKey.GetValue(“InstallLocation”))


        $array += $obj

    } 

}

$array = $array |Select DisplayName |ft -auto | Out-File -Filepath $tempLoc

gc $tempLoc | where-object {$_ -match $regex} | foreach { Write-host "No. $_" }