$desktopcontrollerFQDN = Read-Host "Enter FQDN of an XD Desktop Controller"

## Adjust daystolookback below to pull in however many days of data.  Ex, -7 will pull in the last 7 days of session data.  Note, if you have high volume this will consume a lot of memory
$daystolookback = "-7"

## Put in Subnet IP of NetScaler providing remote access.  Script will flag if session is VPN or not
$nssubnetIP = "10.10.20.25"

$totalexecutiontime = measure-command { 
$overallarray = @()
$filesavedate = (Get-Date).tostring("yyyyMMdd-hhmmss")

## User data from monitoring db
$userdata = Invoke-RestMethod –URI “http://$desktopcontrollerFQDN/Citrix/Monitor/OData/v1/Data/Users” -UseDefaultCredentials
$userdata = $userdata.content.properties

## This is the list of users to actually report on.  Looking for samaccountname string(s).  Customize as necessary
$uniqueusers = $userdata.username | sort -Unique  #This will report everyone who has logged in during the specified time
#$uniqueusers = Get-Content "h:\xduserlist.txt"
#$uniqueusers = "samaccountname"

## Session data from monitoring db.
$date = (Get-Date).AddDays($daystolookback).ToString("yyyy-MM-ddTHH:mm:ss.ms")
$uri = "http://$desktopcontrollerFQDN" + '/Citrix/Monitor/OData/v1/Data/Sessions()?$filter=StartDate gt ' + "DateTime'$date' "
$Sessiondata = Invoke-RestMethod –URI $uri -UseDefaultCredentials
$sessiondata = $Sessiondata.content.properties

## Machine data from monitoring db
$machinedata = Invoke-RestMethod -URI "http://$desktopcontrollerFQDN/Citrix/Monitor/OData/v1/Data/Machines" -UseDefaultCredentials
$machinedata = $machinedata.content.properties

###################################################
## Per User Stuff
$i=0

write-host $uniqueusers.count "Users to check" -ForegroundColor White -BackgroundColor Magenta
$uniqueusers | ForEach-Object {
    $i++
       Write-Progress   -Activity "Monitoring Database Report" -Status ("Checking : {0}" -f $_) -PercentComplete ($i/$uniqueusers.count*100) -Id 0 
$usernametemp = $_

$username = $userdata | where {$_.UserName -like $usernametemp }
$useridinnertext = ($username.Id.InnerText).ToString()
$userssessions = $sessiondata | where { $_.UserID.InnerText -like $useridinnertext }

## To demonstrate overall progress on screen
write-host $usernametemp ":" $userssessions.count

if ($userssessions -eq $null) {
$outputobject = New-Object PSObject -Property @{
UserID = $username.UserName
FullName = $username.FullName
MachineName = "NA"
SessionStart = "NA"
SessionEnd = "NA"
ClientName = "NA"
ClientVersion = "NA"
ConnectedViaIP = "NA"
VPN = "NA"
ConnectionEstDate = "NA" }

$overallarray += $outputobject
}

else {
## Per session stuff
$userssessions | ForEach-Object {
$machineguid = $_.MachineID.InnerText
$machinename = $machinedata | Where-Object { $_.ID.InnerText -like $machineguid } | select DnsName
$connectionid = $_.currentconnectionid.InnerText

$connectionuri = "http://$desktopcontrollerFQDN/Citrix/Monitor/OData/v1/Data/Connections($($connectionid)L)"
[xml]$xmlconnection = Invoke-WebRequest -URI $connectionuri -UseDefaultCredentials

if ($xmlconnection.entry.content.properties.ConnectedViaIPAddress -eq "$nssubnetIP") { $vpn = "Yes" }
else { $vpn = "No" }

## Filters out console and bad sessions
if (($xmlconnection.entry.content.properties.ConnectedViaIPAddress -ne "127.0.0.1") -and ($xmlconnection.entry.content.properties.ConnectedViaIPAddress.null -notlike "true" )) {
$outputobject = New-Object PSObject -Property @{
UserID = $username.UserName
FullName = $username.FullName
MachineName = $machinename.DnsName
SessionStart = $_.StartDate.InnerText
SessionEnd = $_.EndDate.InnerText
ClientName = $xmlconnection.entry.content.properties.ClientName
ClientVersion = $xmlconnection.entry.content.properties.ClientVersion
ConnectedViaIP = $xmlconnection.entry.content.properties.ConnectedViaIPAddress
VPN = $vpn
ConnectionEstDate = $xmlconnection.entry.content.properties.EstablishmentDate.InnerText }


$overallarray += $outputobject
Clear-Variable connectionuri, connectionid, xmlconnection, machinename, machineguid, vpn -ErrorAction SilentlyContinue
}
}
Clear-Variable userssessions
}
}

write-host ($overallarray.userid | sort -Unique).count "users out of" $uniqueusers.Count "total checked have logged in"

## File name/path to save
$filename = "$env:USERPROFILE\Documents\SessionsFromMonDB" + $filesavedate + '.csv'

## Output to file, or grid view
$overallarray | select UserID, MachineName, SessionStart, SessionEnd, ClientName, ClientVersion, ConnectedViaIP, VPN, ConnectionEstDate | Export-Csv -Path $filename -NoTypeInformation
$overallarray | select UserID, FullName, MachineName, SessionStart, SessionEnd, ClientName, ClientVersion, ConnectedViaIP, VPN, ConnectionEstDate | Out-GridView

write-host "Output saved to" $filename 
}
write-host "Completed in" $totalexecutiontime.TotalSeconds "Seconds, or" $totalexecutiontime.TotalMinutes "Minutes"
