Param (
    [Parameter(Mandatory = $true)]
    [string]
    $AzureUserName,

    [string]
    $AzurePassword,

    [string]
    $AzureTenantID,

    [string]
    $AzureSubscriptionID,

    [string]
    $ODLID,
    
    [string]
    $DeploymentID,

    [string]
    $InstallCloudLabsShadow,
    
    [string]
    $vmAdminUsername,

    [string]
    $trainerUserName,

    [string]
    $trainerUserPassword
)

Start-Transcript -Path C:\WindowsAzure\Logs\CloudLabsCustomScriptExtension.txt -Append
[Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls" 

#Import Common Functions
$path = pwd
$path=$path.Path
$commonscriptpath = "$path" + "\cloudlabs-common\cloudlabs-windows-functions.ps1"
. $commonscriptpath

# Run Imported functions from cloudlabs-windows-functions.ps1
WindowsServerCommon
#InstallCloudLabsShadow $ODLID $InstallCloudLabsShadow
CreateCredFile $azureUsername $azurePassword $azureTenantID $azureSubscriptionID $deploymentId $ODLID
InstallAzPowerShellModule
InstallModernVmValidator
InstallPowerBIDesktop

Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SpektraSystems/CloudLabs-Azure/master/azure-synapse-analytics-workshop-400/artifacts/setup/azcopy.exe" -OutFile "C:\LabFiles\azcopy.exe"

Add-Content -Path "C:\LabFiles\AzureCreds.txt" -Value "ODLID= $ODLID" -PassThru

$LabFilesDirectory = "C:\LabFiles"

. C:\LabFiles\AzureCreds.ps1

$userName = $AzureUserName
$password = $AzurePassword
$SubscriptionId = $AzureSubscriptionID

$securePassword = $password | ConvertTo-SecureString -AsPlainText -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $userName, $SecurePassword

Connect-AzAccount -Credential $cred | Out-Null

$resourceGroupName = (Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -like "*ManyModels*" }).ResourceGroupName
$deploymentId =  (Get-AzResourceGroup -Name $resourceGroupName).Tags["DeploymentId"]

# Template deployment

New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName `
  -TemplateUri "https://raw.githubusercontent.com/Sanket-ST/Azure-Synapse-Solution-Accelerator-Financial-Analytics-Customer-Revenue-Growth-Factor/main/Resource_Deployment/azuredeploy.json" `
  -DeploymentId $deploymentId
  
$storageAccounts = Get-AzResource -ResourceGroupName $resourceGroupName -ResourceType "Microsoft.Storage/storageAccounts"
$asadatalakename = $storageAccounts | Where-Object { $_.Name -Notlike 'ml*' }
$storagedatalake =$asadatalakename.Name
$Context = $storagedatalake.Context

$storage = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $asadatalakename.Name
$storageContext = $storage.Context

$storContainer = Get-AzStorageContainer -Name "source" -Context $storageContext
$storageContainer = $storContainer.Name

$filesystemName = "source"
$dirname = "raw_data/"
New-AzDataLakeGen2Item -Context $storageContext -FileSystem $filesystemName -Path $dirname -Directory

$storage = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $asadatalakename.Name
$storageContext = $storage.Context


$destContext = $storage.Context
$startTime = Get-Date
$endTime = $startTime.AddDays(2)
$destSASToken = New-AzStorageAccountSASToken -Context $storageContext -Service Blob -ResourceType Object -Permission rwdlac -StartTime $startTime -ExpiryTime $endTime
$destUrl = $destContext.BlobEndPoint + "source/" + "raw_data" + $destSASToken
$srcUrl = "C:\Users\demouser\Downloads\Datasets\*"

$srcUrl 
$destUrl

C:\LabFiles\azcopy.exe copy $srcUrl $destUrl 


Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module -Name Az.Synapse -RequiredVersion 0.3.0 -Force

$workspaceName = $synapseWorkspace | Where-Object { $_.workspacename -like 'synapse-workspace*' }

$synapseWorkspace =$workspacename.Name

$synapseWorkspace = Get-AzSynapseWorkspace -ResourceGroupName $resourceGroupName
$workspaceName =$synapseWorkspace.Name

New-AzSynapseFirewallRule -WorkspaceName $workspaceName -Name NewClientIp -StartIpAddress "0.0.0.0" -EndIpAddress "255.255.255.255"
                                                                                                                                                                                                         


cd "C:\synapse-ws-L400\azure-synapse-analytics-workshop-400\artifacts\environment-setup\automation\"
$sparkpoolName = "spark1"
Update-AzSynapseSparkPool -WorkspaceName $WorkspaceName -Name $sparkpoolName -LibraryRequirementsFilePath "C:\synapse-ws-L400\azure-synapse-analytics-workshop-400\artifacts\environment-setup\automation\requirements.txt" #path

function CreateCredFile($azureUsername, $azurePassword, $azureTenantID, $azureSubscriptionID, $deploymentId)
{
  $WebClient = New-Object System.Net.WebClient
  $WebClient.DownloadFile("https://raw.githubusercontent.com/solliancenet/azure-synapse-analytics-workshop-400/master/artifacts/environment-setup/spektra/AzureCreds.txt","C:\LabFiles\AzureCreds.txt")
  $WebClient.DownloadFile("https://raw.githubusercontent.com/solliancenet/azure-synapse-analytics-workshop-400/master/artifacts/environment-setup/spektra/AzureCreds.ps1","C:\LabFiles\AzureCreds.ps1")

  (Get-Content -Path "C:\LabFiles\AzureCreds.txt") | ForEach-Object {$_ -Replace "ClientIdValue", ""} | Set-Content -Path "C:\LabFiles\AzureCreds.ps1"
  (Get-Content -Path "C:\LabFiles\AzureCreds.txt") | ForEach-Object {$_ -Replace "AzureUserNameValue", "$AzureUsername"} | Set-Content -Path "C:\LabFiles\AzureCreds.txt"
  (Get-Content -Path "C:\LabFiles\AzureCreds.txt") | ForEach-Object {$_ -Replace "AzurePasswordValue", "$AzurePassword"} | Set-Content -Path "C:\LabFiles\AzureCreds.txt"
  (Get-Content -Path "C:\LabFiles\AzureCreds.txt") | ForEach-Object {$_ -Replace "AzureSQLPasswordValue", "$AzurePassword"} | Set-Content -Path "C:\LabFiles\AzureCreds.ps1"
  (Get-Content -Path "C:\LabFiles\AzureCreds.txt") | ForEach-Object {$_ -Replace "AzureTenantIDValue", "$AzureTenantID"} | Set-Content -Path "C:\LabFiles\AzureCreds.txt"
  (Get-Content -Path "C:\LabFiles\AzureCreds.txt") | ForEach-Object {$_ -Replace "AzureSubscriptionIDValue", "$AzureSubscriptionID"} | Set-Content -Path "C:\LabFiles\AzureCreds.txt"
  (Get-Content -Path "C:\LabFiles\AzureCreds.txt") | ForEach-Object {$_ -Replace "DeploymentIDValue", "$DeploymentId"} | Set-Content -Path "C:\LabFiles\AzureCreds.txt"               
  (Get-Content -Path "C:\LabFiles\AzureCreds.ps1") | ForEach-Object {$_ -Replace "ClientIdValue", ""} | Set-Content -Path "C:\LabFiles\AzureCreds.ps1"
  (Get-Content -Path "C:\LabFiles\AzureCreds.ps1") | ForEach-Object {$_ -Replace "AzureUserNameValue", "$AzureUsername"} | Set-Content -Path "C:\LabFiles\AzureCreds.ps1"
  (Get-Content -Path "C:\LabFiles\AzureCreds.ps1") | ForEach-Object {$_ -Replace "AzurePasswordValue", "$AzurePassword"} | Set-Content -Path "C:\LabFiles\AzureCreds.ps1"
  (Get-Content -Path "C:\LabFiles\AzureCreds.ps1") | ForEach-Object {$_ -Replace "AzureSQLPasswordValue", "$AzurePassword"} | Set-Content -Path "C:\LabFiles\AzureCreds.ps1"
  (Get-Content -Path "C:\LabFiles\AzureCreds.ps1") | ForEach-Object {$_ -Replace "AzureTenantIDValue", "$AzureTenantID"} | Set-Content -Path "C:\LabFiles\AzureCreds.ps1"
  (Get-Content -Path "C:\LabFiles\AzureCreds.ps1") | ForEach-Object {$_ -Replace "AzureSubscriptionIDValue", "$AzureSubscriptionID"} | Set-Content -Path "C:\LabFiles\AzureCreds.ps1"
  (Get-Content -Path "C:\LabFiles\AzureCreds.ps1") | ForEach-Object {$_ -Replace "DeploymentIDValue", "$DeploymentId"} | Set-Content -Path "C:\LabFiles\AzureCreds.ps1"
  Copy-Item "C:\LabFiles\AzureCreds.txt" -Destination "C:\Users\Public\Desktop"
}
CreateCredFile

(Get-Content -Path "C:\synapse-ws-L400\azure-synapse-analytics-workshop-400\artifacts\day-03\lab-06-machine-learning\1 - Clean Data.ipynb") | ForEach-Object {$_ -Replace "data_lake_account_name = ''", "data_lake_account_name = '$storagedatalake'"} | Set-Content -Path "C:\synapse-ws-L400\azure-synapse-analytics-workshop-400\artifacts\day-03\lab-06-machine-learning\1 - Clean Data.ipynb"
(Get-Content -Path "C:\synapse-ws-L400\azure-synapse-analytics-workshop-400\artifacts\day-03\lab-06-machine-learning\1 - Clean Data.ipynb") | ForEach-Object {$_ -Replace "file_system_name = ''", "file_system_name = 'source'"} | Set-Content -Path "C:\synapse-ws-L400\azure-synapse-analytics-workshop-400\artifacts\day-03\lab-06-machine-learning\1 - Clean Data.ipynb"
(Get-Content -Path "C:\synapse-ws-L400\azure-synapse-analytics-workshop-400\artifacts\day-03\lab-06-machine-learning\2 - Data Engineering.ipynb") | ForEach-Object {$_ -Replace "file_system_name = ''", "file_system_name ='source'"} | Set-Content -Path "C:\synapse-ws-L400\azure-synapse-analytics-workshop-400\artifacts\day-03\lab-06-machine-learning\2 - Data Engineering.ipynb"
(Get-Content -Path "C:\synapse-ws-L400\azure-synapse-analytics-workshop-400\artifacts\day-03\lab-06-machine-learning\2 - Data Engineering.ipynb") | ForEach-Object {$_ -Replace "data_lake_account_name = ''", "data_lake_account_name = '$storagedatalake'"} | Set-Content -Path "C:\synapse-ws-L400\azure-synapse-analytics-workshop-400\artifacts\day-03\lab-06-machine-learning\2 - Data Engineering.ipynb"
(Get-Content -Path "C:\synapse-ws-L400\azure-synapse-analytics-workshop-400\artifacts\day-03\lab-06-machine-learning\2 - Data Engineering.ipynb") | ForEach-Object {$_ -Replace "full_dataset = ''", "full_dataset = 'source'"} | Set-Content -Path "C:\synapse-ws-L400\azure-synapse-analytics-workshop-400\artifacts\day-03\lab-06-machine-learning\2 - Data Engineering.ipynb"
(Get-Content -Path "C:\synapse-ws-L400\azure-synapse-analytics-workshop-400\artifacts\day-03\lab-06-machine-learning\3 - Feature Engineering.ipynb") | ForEach-Object {$_ -Replace "data_lake_account_name = ''", "data_lake_account_name = '$storagedatalake'"} | Set-Content -Path "C:\synapse-ws-L400\azure-synapse-analytics-workshop-400\artifacts\day-03\lab-06-machine-learning\3 - Feature Engineering.ipynb"
(Get-Content -Path "C:\synapse-ws-L400\azure-synapse-analytics-workshop-400\artifacts\day-03\lab-06-machine-learning\3 - Feature Engineering.ipynb") | ForEach-Object {$_ -Replace "file_system_name = ''", "file_system_name = 'source'"} | Set-Content -Path "C:\synapse-ws-L400\azure-synapse-analytics-workshop-400\artifacts\day-03\lab-06-machine-learning\3 - Feature Engineering.ipynb"
(Get-Content -Path "C:\synapse-ws-L400\azure-synapse-analytics-workshop-400\artifacts\day-03\lab-06-machine-learning\4 - ML Model Building.ipynb") | ForEach-Object {$_ -Replace "data_lake_account_name = ''", "data_lake_account_name = '$storagedatalake'"} | Set-Content -Path "C:\synapse-ws-L400\azure-synapse-analytics-workshop-400\artifacts\day-03\lab-06-machine-learning\4 - ML Model Building.ipynb"
(Get-Content -Path "C:\synapse-ws-L400\azure-synapse-analytics-workshop-400\artifacts\day-03\lab-06-machine-learning\4 - ML Model Building.ipynb") | ForEach-Object {$_ -Replace "file_system_name = ''", "file_system_name = 'source'"} | Set-Content -Path "C:\synapse-ws-L400\azure-synapse-analytics-workshop-400\artifacts\day-03\lab-06-machine-learning\4 - ML Model Building.ipynb"


#Download LogonTask
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://raw.githubusercontent.com/Sanket-ST/Azure-Synapse-Solution-Accelerator-Financial-Analytics-Customer-Revenue-Growth-Factor/main/Resource_Deployment/logon-psscript.ps1","C:\LabFiles\logon-psscript.ps1")

#Enable Auto-Logon
$AutoLogonRegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty -Path $AutoLogonRegPath -Name "AutoAdminLogon" -Value "1" -type String
Set-ItemProperty -Path $AutoLogonRegPath -Name "DefaultUsername" -Value "$($env:ComputerName)\demouser" -type String
Set-ItemProperty -Path $AutoLogonRegPath -Name "DefaultPassword" -Value "Password.1!!" -type String
Set-ItemProperty -Path $AutoLogonRegPath -Name "AutoLogonCount" -Value "1" -type DWord

# Scheduled Task
$Trigger= New-ScheduledTaskTrigger -AtLogOn
$User= "$($env:ComputerName)\demouser"
$Action= New-ScheduledTaskAction -Execute "C:\Windows\System32\WindowsPowerShell\v1.0\Powershell.exe" -Argument "-executionPolicy Unrestricted -File C:\LabFiles\logon-psscript.ps1"
Register-ScheduledTask -TaskName "Setup" -Trigger $Trigger -User $User -Action $Action -RunLevel Highest -Force
Set-ExecutionPolicy -ExecutionPolicy bypass -Force

Stop-Transcript
Restart-Computer -Force 
