#If azcopy is in the Path, replace .\AzCopy.exe with azcopy in line 75.
#If not, run scpript from AzCopy executable folder. 
#Run script with Admin priviliges 

param(
 [Parameter(Mandatory=$True)]
 [string]
 $AzureUser,

 [Parameter(Mandatory=$True)]
 [string]
 $AzureUserPass,

 [Parameter(Mandatory=$True)]
 [string]
 $Domain
 )
 
$SecString = $AzureUser | ConvertTo-SecureString -AsPlainText -Force
$AzurePass = New-Object System.Management.Automation.PSCredential ($AzureUser,$SecString) 

$ErrorActionPreference = 'continue'

Connect-AzureAD 

$PasswordProfile = New-Object Microsoft.Open.AzureAD.Model.PasswordProfile
$PasswordProfile.Password = "Password1234"
$SecPasswordProfile = $PasswordProfile.Password | ConvertTo-SecureString -AsPlainText -Force
$SecGroupName = "Varonis Assignment2 Group"
$SecGroupNick = "VaronisAssignment2Group"
$Users = New-Object System.Collections.ArrayList

for ($i=1; $i -le 20; $i++){
    $User = "Test User" + $i
    $UserEmail = "Testuser" + $i + "@" + "$domain"
    $UserNick = "Testuser" + $i
    New-AzADUser -DisplayName $User -MailNickname $UserNick -Password $SecPasswordProfile -UserPrincipalName $UserEmail
    
    $Users += $UserEmail 
}

if ([system.diagnostics.eventlog]::SourceExists(“VaronisEtest”) -eq $false) {
New-AzADGroup -DisplayName $SecGroupName -MailNickname $SecGroupNick 
New-EventLog -LogName Varonistest -Source VaronisEtest
Limit-EventLog -OverflowAction OverWriteAsNeeded -MaximumSize 64KB -LogName Varonistest
}

$result = $null
$ErrorActionPreference = 'stop'
foreach ($UserEmail in $Users) { 
   try{
      Add-AzADGroupMember -MemberUserPrincipalName $UserEmail -TargetGroupDisplayName $SecGroupName
      $result = "Success"
   }
   catch {
      $result = "Fail"
   }
    
 Write-EventLog -LogName Varonistest -Source VaronisEtest -Message "$UserEmail // $result" -EventId 1 -EntryType information
 $result = $null
 }

$file = Get-EventLog -LogName Varonistest
$file | Out-File C:\varonisaddedusers.txt -Append
Clear-EventLog -LogName Varonistest


Connect-AzAccount -Credential $AzurePass
New-AzResourceGroup -Name RG01 -Location 'West Europe' 
New-AzStorageAccount -Name eitanvaronis -ResourceGroupName RG01 -Location 'West Europe' -SkuName Standard_LRS
$StorageAccountContext = (Get-AzStorageAccount -Name eitanvaronis -ResourceGroupName RG01).Context
$StorageContainerName = New-AzStorageContainer -Name varonislogs -Context $StorageAccountContext -Permission Blob
$Blobname = "varonisaddedusers.txt"
$SAS = New-AzStorageBlobSASToken -Container $StorageContainerName.Name -Blob $Blobname -Context $StorageAccountContext -Permission rwd -FullUri

.\AzCopy.exe copy "C:\varonisaddedusers.txt" "$SAS" --recursive=true

Write-Host Done!. View file in next link - $SAS

#Remove-EventLog -LogName Varonistest
#[System.Diagnostics.EventLog]::DeleteEventSource("VaronisEtest")
#[system.diagnostics.eventlog]::SourceExists(“VaronisEtest”)
