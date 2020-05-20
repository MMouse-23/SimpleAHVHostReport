Function REST-Get-PE-Host-Nics {
  Param (
    [string] $PEClusterIP,
    [string] $PxClusterPass,
    [string] $PxClusterUser,
    [string] $HostUUID
  )

  write-log -message "Building Credential object"
  $credPair = "$($PxClusterUser):$($PxClusterPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Executing Get Hosts Query"

  $URL = "https://$($PEClusterIP):9440/PrismGateway/services/rest/v1/hosts/$($HostUUID)/host_nics"

  $JSON = $Payload 
  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers -ea:4;
  } catch {$error.clear()
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers
  }

  Return $task
} 

function Get-FunctionName {
  param (
    [int]$StackNumber = 1
  ) 
    return [string]$(Get-PSCallStack)[$StackNumber].FunctionName
}

Function REST-LCMV2-Query-Versions {
  Param (
    [string] $PEClusterIP,
    [string] $PxClusterPass,
    [string] $PxClusterUser,
    [bool] $silent = $false
  )

  $credPair = "$($PxClusterUser):$($PxClusterPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  $URL = "https://$($PEClusterIP):9440/api/nutanix/v3/groups"

$Payload= @"
{
  "entity_type": "lcm_entity_v2",
  "group_member_count": 500,
  "group_member_attributes": [{
    "attribute": "id"
  }, {
    "attribute": "uuid"
  }, {
    "attribute": "entity_model"
  }, {
    "attribute": "version"
  }, {
    "attribute": "location_id"
  }, {
    "attribute": "entity_class"
  }, {
    "attribute": "description"
  }, {
    "attribute": "last_updated_time_usecs"
  }, {
    "attribute": "request_version"
  }, {
    "attribute": "_master_cluster_uuid_"
  }, {
    "attribute": "entity_type"
  }, {
    "attribute": "single_group_uuid"
  }],
  "query_name": "lcm:EntityGroupModel",
  "grouping_attribute": "location_id",
  "filter_criteria": ""
}
"@ 

  $JSON = $Payload 
  try{
    $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
  } catch {
    if ($silent -eq $false){
      sleep 10
      $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"
  
      $task = Invoke-RestMethod -Uri $URL -method "post" -body $JSON -ContentType 'application/json' -headers $headers;
    }  
  }
  if ($debug -ge 2){
    write-log -message "We found $($task.group_results.entity_results.count) items."
  }
  Return $task
} 


Function REST-Get-PE-Hosts {
  Param (
    [string] $PEClusterIP,
    [string] $PxClusterPass,
    [string] $PxClusterUser
  )

  write-log -message "Building Credential object"
  $credPair = "$($PxClusterUser):$($PxClusterPass)"
  $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
  $headers = @{ Authorization = "Basic $encodedCredentials" }

  write-log -message "Executing Get Hosts Query"

  $URL = "https://$($PEClusterIP):9440/PrismGateway/services/rest/v1/hosts"

  $JSON = $Payload 
  try{
    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers -ea:4;
  } catch {$error.clear()
    sleep 10
    $FName = Get-FunctionName;write-log -message "Error Caught on function $FName" -sev "WARN"

    $task = Invoke-RestMethod -Uri $URL -method "GET" -headers $headers
  }

  Return $task
} 

Function write-log {
  param (
  $message,
  $sev = "INFO",
  $D = 0,
  $calmvars
  ) 
  ## This write log module is designed for nutanix calm output
  if ($message -match "Task .* Completed"){
    $global:stoptime = get-date
  } 
  if ($sev -eq "INFO" ){
    write-host "'$(get-date -format "dd-MMM-yy HH:mm:ss")' | INFO  | $message "
  } elseif ($sev -eq "WARN"){
    write-host "'$(get-date -format "dd-MMM-yy HH:mm:ss")' |'WARN' | $message " -ForegroundColor  Yellow
  } elseif ($sev -eq "ERROR"){
    write-host "'$(get-date -format "dd-MMM-yy HH:mm:ss")' |'ERROR'| $message " -ForegroundColor  Red
  } elseif ($sev -eq "CHAPTER"){
    write-host ""
    write-host "####################################################################"
    write-host "#                                                                  #"
    write-host "#     $message"
    write-host "#                                                                  #"
    write-host "####################################################################"
    write-host ""
  }
} 