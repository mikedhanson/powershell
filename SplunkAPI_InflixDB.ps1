param (
    [switch]$output = $false,
    [switch]$NumberOfLogs
)
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

$start_Time = (Get-Date)

<# Authentication #>
$user = "username"
$pass = "password"
$pair = "${user}:${pass}"
$encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
$basicAuthValues = "basic $encodedCreds"
$headers = @{ Authorization = $basicAuthValues}

$outputLogLocation = $env:TEMP
$date = $(get-date -f yyyy-MM-dd)
$INFLUX_IP="influxip"
$INFLUX_PORT="8086"
$DB_NAME="fortigate"
$InfluxUrl = "http://${INFLUX_IP}:${INFLUX_PORT}/write?db=$DB_NAME"

<# other params #>
$numberOfItems = 20
$output = $true

$Body = @{
    search="search index=main sourcetype=fgt_traffic | iplocation 'dstip' | head $numberOfItems"
    output_mode="json"
    earliest="-5m" 
}

$returned_data =  $(Invoke-RestMethod -Method Post -Uri https://splunkIP:8089/services/search/jobs/export -Body $Body -Headers $headers) -split "`n" | `
    ForEach-Object { 
        $_ | ConvertFrom-Json | Select-Object -ExpandProperty result 
    }
$newArray = @()
$restults = @()

foreach($item in $returned_data._raw){
    Write-Host -ForegroundColor Yellow "Processing " $returned_data._raw.IndexOf($item) " - Out of $numberOfItems"; Clear-Host
    $logData = $item -split " "
    foreach($line in $logData){
        $newArray += $line
    }
    foreach($item in $newArray){
        
        if($item -like "eventtime*"){     $event_time = $item.Split("=")[1]  }
        if($item -like "srcip*"){         $source_ip = $item.Split("=")[1]   } 
        if($item -like "srcport*"){       $source_port = $item.Split("=")[1] }
        if($item -like "dstip*"){         $dest_ip = $item.Split("=")[1]     }
        if($item -like "dstport*"){       $dest_port = $item.Split("=")[1]   }
        if($item -like "dstcountry*"){    $dst_country = $item.Split("=")[1].Trim('"') }
        if($item -like "service*"){       $service = $item.Split("=")[1].Trim('"')     }
        if($item -like "srcname*"){       $srcname = $item.Split("=")[1].Trim('"')     }
        if($item -like "osname*"){        $osname = $item.Split("=")[1].Trim('"')     }
        if($item -like "sentbyte*"){      $sentBytes = $item.Split("=")[1]     }
        if($item -like "rcvdbyte*"){      $recvdBytes = $item.Split("=")[1]     }
        if($item -like "level*"){         $level = $item.Split("=")[1].Trim('"')       }

        $obj = [PSCustomObject] @{
            Event_Time = $event_time
            Source_IP = $source_ip
            Source_Port = $source_port
            Destination_ip = $dest_ip
            Destination_port = $dest_port
            Destination_Country = $dst_country
            Service = $service
            Source_Name = $srcname
            Operating_Sysmem = $osname
            Sent_Bytes = $sentBytes
            Recevied_Bytes = $recvdBytes
            Log_Level = $level
        }

    }
    $restults += $obj

    $postContent = @{
        Source_Ip = $obj.Source_IP
        Source_port = $obj.Source_Port
    }

    Invoke-RestMethod -Method POST -Uri $InfluxUrl -Body "fw_data,EventTime=$($obj.Event_Time) value=$($obj.Event_Time)","DestIp=$($obj.Destination_ip) Dest_port=$($obj.Destination_port)"
    
    #Invoke-RestMethod -Method POST -Uri $InfluxUrl -Body "fw_data,DestCountry=$($obj.Destination_Country) eventTime=$($obj.Event_Time)"
    #Invoke-RestMethod -Method POST -Uri $InfluxUrl -Body "fw_data,Source_Ip=$($obj.Source_IP) Source_port=$($obj.Source_Port)"
    #Invoke-RestMethod -Method POST -Uri $InfluxUrl -Body "fw_data,DestIp=$($obj.Destination_ip) Dest_port=$($obj.Destination_port)"
}

$final_output = Write-Output $restults | Format-Table -Property *
Write-Output $restults | Format-Table -Property *

if($output){
    $returned_data | Out-File $outputLogLocation\"Splunk-Fortigate-Logs-"$date -Force
    $final_output  | Out-File $outputLogLocation\"Splunk-Fortigate-Logs-"$date -Append -Force
    Write-Host -ForegroundColor Yellow "Log - "$outputLogLocation\"Splunk-Fortigate-Logs-"$date
}

Write-Host -ForegroundColor Yellow "Elapsed Time: $(($(Get-Date)-$start_time).totalseconds) seconds to process $numberOfItems records"
<# Clear variable #>
Remove-Variable * -ErrorAction SilentlyContinue
