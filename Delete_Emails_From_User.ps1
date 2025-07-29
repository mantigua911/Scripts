# Connect to Exchange Online
Connect-ExchangeOnline -UserPrincipalName (Read-Host "Enter your admin UPN")

$userEmail = Read-Host "Enter the user's email address"
$searchName = "DeleteSpam_" + $userEmail.Replace("@", "_").Replace(".", "_")
$searchQuery = Read-Host "Enter the search query (e.g., Subject:'SPAM' OR From:'spammer@badsite.com')"

# Create the compliance search
New-ComplianceSearch -Name $searchName `
  -ExchangeLocation $userEmail `
  -ContentMatchQuery $searchQuery
  
# Start the Search
Start-ComplianceSearch -Identity $searchName

Write-Host "Waiting for the search to complete... (check status in Microsoft Purview if needed)"
Read-Host "Press Enter once the search is complete to proceed with deletion"


# Wait for the search to complete, then purge the results

New-ComplianceSearchAction -SearchName $searchName -Purge -PurgeType HardDelete
Write-Host "Purge initiated for $userEmail with query: $searchQuery"
