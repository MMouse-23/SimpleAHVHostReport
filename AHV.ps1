#### Version ####
$Ver = "02.00"

### Prompt, replace with static input

$PECreds            = get-credential -message "Enter Prism Element Credentials"
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic') | Out-Null
$PEClusterIP = [Microsoft.VisualBasic.Interaction]::InputBox("Enter Prism Element IP", "Prism Element IP address", "10.10.0.30")

### Ímporting Functions

import-module .\modules.psm1 -DisableNameChecking

write-log -message "Checking Powershell Version"

if ($PSVersionTable.PSVersion.Major -lt 5){

  write-log -message "You need to run this on Powershell 5 or greater...." -sev "ERROR"

}

write-log -message "Disabling SSL Certificate Check for PowerShell 5"

add-type @"
 using System.Net;

  using System.Security.Cryptography.X509Certificates;
  public class TrustAllCertsPolicy : ICertificatePolicy {
     public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate,
                                       WebRequest request, int certificateProblem) {
         return true;
     }
  }
"@
  
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Ssl3, [Net.SecurityProtocolType]::Tls, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12

write-log -message "Getting AHV Hosts"

$AHVHosts = REST-Get-PE-Hosts `
  -PEClusterIP $PEClusterIP `
  -PxClusterUser $PECreds.getnetworkcredential().username `
  -PxClusterPass $PECreds.getnetworkcredential().password

write-log -message "You have $($AHVHost.entities.count) hosts in this cluster.."  

$ExistingSoftwareGroup = REST-LCMV2-Query-Versions `
  -PEClusterIP $PEClusterIP `
  -PxClusterUser $PECreds.getnetworkcredential().username `
  -PxClusterPass $PECreds.getnetworkcredential().password
 
$UUIDS = ($ExistingSoftwareGroup.group_results.entity_results.data | where {$_.name -eq "uuid"}).values.values

write-log -message "Getting Installed Software"

foreach ($app in $UUIDS){
  $nodeUUID = (((($ExistingSoftwareGroup.group_results.entity_results | where {$_.data.values.values -eq $app}).data | where {$_.name -eq "location_id"}).values.values | select -last 1) -split ":")[1]
  $PHhost = $AHVhosts.entities | where {$_.uuid -match $nodeuuid}
  $Entity = [PSCustomObject]@{
    Version     = (($ExistingSoftwareGroup.group_results.entity_results | where {$_.data.values.values -eq $app}).data | where {$_.name -eq "version"}).values.values | select -last 1
    Class       = (($ExistingSoftwareGroup.group_results.entity_results | where {$_.data.values.values -eq $app}).data | where {$_.name -eq "entity_class"}).values.values | select -last 1
    Name        = (($ExistingSoftwareGroup.group_results.entity_results | where {$_.data.values.values -eq $app}).data | where {$_.name -eq "entity_model"}).values.values | select -last 1
    SoftwareUUID= $app
    HostUUID    = $nodeuuid
  }
  [array]$InstalledSoftwareList += $entity     
}  

if ($AHVHosts.entities.count -lt 1){

  write-log -message "You did not specify the correct Prism Element IP or Credentials" -sev "ERROR"

} else {

  write-log -message "Getting All Nics for each host." -sev "Chapter"
  
  Foreach ($AHVHost in $AHVHosts.entities){

    write-log -message "Getting Nic Details for host $($AHVHost.uuid)"

    $nics = REST-Get-PE-Host-Nics `
      -PEClusterIP $PEClusterIP `
      -PxClusterUser $PECreds.getnetworkcredential().username `
      -PxClusterPass $PECreds.getnetworkcredential().password `
      -HostUUID $AHVHost.uuid

    write-log -message "This host has $($nics.count) Network Interfaces"
  
    write-log -message "Lets builds a custom PS object for our HTML Conversion" -sev "Chapter"
  
    $secondsup = $AHVHost.bootTimeInUsecs / 100000000
    $timespan = new-timespan -seconds $secondsup
    $Nicsup = $nics | where {$_.linkSpeedInKbps -match "[0-9][0-9]"}
  
    $HostsObject = @{
      Name      = $AHVHost.Name
      AHV_Ver   = $AHVHost.hypervisorFullName
      Model     = $AHVHost.blockModelName
      Bios      = $AHVHost.bmcVersion
      Status    = $AHVHost.state
      Power     = $AHVHost.acropolisConnectionState
      Days_UP   = $timespan.Days
      Cores     = $AHVHost.numCpuCores
      CPU_Usage = [math]::truncate($AHVHost.stats.hypervisor_cpu_usage_ppm / 10000)
      RAM       = [math]::truncate($AHVHost.memoryCapacityInBytes /1000 /1024 /1024)
      RAM_Usage = [math]::truncate($AHVHost.stats.hypervisor_memory_usage_ppm / 10000)
      Nics      = $nics.count
      Nics_UP   = $Nicsup.count
    }
    [array]$HostsObjects += $HostsObject 
  }
  [array] $cleanarray = $HostsObjects |ConvertTo-Json | convertfrom-json

  $cleanarray | ConvertTo-Html -Property Name,AHV_Ver,Model,Bios,Status,Power,Days_UP,Cores,CPU_Usage,RAM,RAM_Usage,Nics,Nics_UP | out-file .\Output.html
}
