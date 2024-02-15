if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))  
{  
  $arguments = "& '" +$myinvocation.mycommand.definition + "'"
  Start-Process powershell -Verb runAs -ArgumentList $arguments
  Break
}

cd \
	if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript")
 		{ $ScriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition }
 	else
 		{ $ScriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0]) 
     if (!$ScriptPath){ $ScriptPath = "." } }
$ScriptPath
cd $ScriptPath

Read-Host -prompt "Enter "