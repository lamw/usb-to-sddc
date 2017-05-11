$DeployLogFile = "/root/script.log"

$StartTime = Get-Date

. /root/config.ps1

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-File -Append -LiteralPath $DeployLogFile

Connect-VIServer -Server $VI_SERVER -User $VI_USERNAME -password $VI_PASSWORD | Out-File -Append -LiteralPath $DeployLogFile

"Adding ESXi Host $ESX_SERVER to vCenter ..." | Out-File -Append -LiteralPath $DeployLogFile
Add-VMHost -Location (Get-Cluster -Name $VI_CLUSTER) -User root -Password $ESX_PASSWORD -Name $ESX_SERVER -Force | Out-File -Append -LiteralPath $DeployLogFile

"Configuring Host syslog to VC ..." | Out-File -Append -LiteralPath $DeployLogFile
Get-VMHost | Set-VMHostSysLogServer -SysLogServer $VI_SERVER | Out-File -Append -LiteralPath $DeployLogFile

"Enabling VM Autostart for the VCSA VM ..." | Out-File -Append -LiteralPath $DeployLogFile
$VCVM = Get-VM -Name "Embedded-vCenter-Server-Appliance"
$vmstartpolicy = Get-VMStartPolicy -VM $VCVM
Set-VMHostStartPolicy (Get-VMHost $ESX_SERVER | Get-VMHostStartPolicy) -Enabled:$true | Out-File -Append -LiteralPath $DeployLogFile
Set-VMStartPolicy -StartPolicy $vmstartpolicy -StartAction PowerOn -StartDelay 0 | Out-File -Append -LiteralPath $DeployLogFile

"Acknowledging Alarms on the Cluster ..." | Out-File -Append -LiteralPath $DeployLogFile
$alarmMgr = Get-View AlarmManager
Get-Cluster | Where-Object {$_.ExtensionData.TriggeredAlarmState} | ForEach-Object{
    $cluster = $_
    $entity_moref = $cluster.ExtensionData.MoRef

    $cluster.ExtensionData.TriggeredAlarmState | ForEach-Object{
        $alarm_moref = $_.Alarm.value

        "Ack'ing $alarm_moref ..." | Out-File -Append -LiteralPath $DeployLogFile
        $alarmMgr.AcknowledgeAlarm($alarm_moref,$entity_moref) | Out-File -Append -LiteralPath $DeployLogFile
    }
}

Disconnect-VIServer * -confirm:$false | Out-File -Append -LiteralPath $DeployLogFile

$EndTime = Get-Date
$duration = [math]::Round((New-TimeSpan -Start $StartTime -End $EndTime).TotalMinutes,2)

"================================" | Out-File -Append -LiteralPath $DeployLogFile
"vSphere Lab Deployment Complete!" | Out-File -Append -LiteralPath $DeployLogFile
"StartTime: $StartTime" | Out-File -Append -LiteralPath $DeployLogFile
"  EndTime: $EndTime" | Out-File -Append -LiteralPath $DeployLogFile
" Duration: $duration minutes" | Out-File -Append -LiteralPath $DeployLogFile
"" | Out-File -Append -LiteralPath $DeployLogFile
"Access the vSphere Web Client at https://$VI_SERVER/vsphere-client/" | Out-File -Append -LiteralPath $DeployLogFile
"Access the HTML5 vSphere Web Client at https://$VI_SERVER/ui/" | Out-File -Append -LiteralPath $DeployLogFile
"Browse the vSphere REST APIs using the API Explorer here: https://$VI_SERVER/apiexplorer/" | Out-File -Append -LiteralPath $DeployLogFile
"================================" | Out-File -Append -LiteralPath $DeployLogFile
