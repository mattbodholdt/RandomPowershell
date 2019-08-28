## Set database connections for site, log, and monitor services on all controllers in a site
## Use at your own risk, you can mess up all of your sites controllers if this is used improperly
##
## Matt Bodholdt
##
## IMPORTANT: Remember to replace SQLFQDN in the below variables to your SQL server's FQDN and match your database names

$site = "Server=SQLFQDN;Initial Catalog=XD7_SITE;Integrated Security=True"
$monitor = "Server=SQLFQDN;Initial Catalog=XD7_MONITOR;Integrated Security=True"
$log = "Server=SQLFQDN;Initial Catalog=XD7_CFGLOG;Integrated Security=True"

$xdcontroller = Read-Host Read-Host "Enter FQDN of an XD Desktop Controller"

Read-Host 'ARE YOU SURE YOU WANT TO DO THIS?!?!?!?  Think carefully and press Enter to continue...' | Out-Null

Set-LogSite -State Disabled -AdminAddress $xdcontroller

Get-BrokerController -AdminAddress $xdcontroller | select DNSName | ForEach-Object {

Set-BrokerDBConnection $null -AdminAddress $_.DNSName
Set-BrokerDBConnection -AdminAddress $_.DNSName -DBConnection $site
Get-BrokerServiceStatus -AdminAddress $_.DNSName | fl

Set-LogDBConnection $null -AdminAddress $_.DNSName
Set-LogDBConnection -AdminAddress $_.DNSName -DataStore Logging -DBConnection $null
Set-LogDBConnection -AdminAddress $_.DNSName -DataStore Logging -DBConnection $log
Get-LogServiceStatus -AdminAddress $_.DNSName | fl

Set-MonitorDBConnection $null -AdminAddress $_.DNSName
Set-MonitorDBConnection -AdminAddress $_.DNSName -DataStore Monitor -DBConnection $null
Set-MonitorDBConnection -AdminAddress $_.DNSName -DataStore Monitor -DBConnection $monitor
Get-MonitorServiceStatus -AdminAddress $_.DNSName | fl
}

Set-LogSite -State Enabled -AdminAddress $xdcontroller