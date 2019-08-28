## Test XenDesktop 7.11 Controllers For Services and Service Status
## Matt Bodholdt - 10/2016
## Meant to be run on an interval as a scheduled task as there is no visual output.  I've scheduled it every 15 minutes personally, could be more, could be less...
## It can run from a controller, or better, a seperate task/monitoring server
## To successfully run this as a scheduled task, especially from a UNC path, you may need to sign it with a valid code signing cert (depends on your system's execution policy)
## You will need a valid SMTP server for the alerts to be sent (see Send-MailMessage cmdlet towards the end)
###########################

if ((Get-PSSnapin -Name Citrix.* -ErrorAction SilentlyContinue) -eq $null) {Add-PsSnapin Citrix.*}

$outputarray = @()
$errors = @()
$controllers = "CONTROLLER1.fqdn.yourdomain.com", "CONTROLLER2.fqdn.yourdomain.com", "CONTROLLER3.fqdn.yourdomain.com"

## Services with the name matching Citrix* that you do not want to test (if you want to test one of the following, you will need to add an action under the $citrixservices foreach
$servicesnottotest = "Citrix Config Synchronizer Service", "Citrix High Availability Service", "Citrix Storefront Privileged Administration Service", "Citrix Telemetry Service"

$controllers | ForEach-Object {
$controller = $_
$citrixservices = Get-Service -ComputerName $_ | where {$_.Name -like "Citrix*"}
$citrixservices | where { ($servicesnottotest -notcontains $_.DisplayName) } | ForEach-Object {


if ($_.DisplayName -like "Citrix Broker Service") { try { $status = (Get-BrokerServiceStatus -AdminAddress $controller -ErrorAction Stop )}
                                                              catch { $err = $_.exception }
                                                              finally { if ($err -ne $null) { $status = $err.InnerException; Clear-Variable err } } }

if ($_.DisplayName -like "Citrix Delegated Administration Service") { try { $status = (Get-AdminServiceStatus -AdminAddress $controller -ErrorAction Stop ) }
                                                              catch { $err = $_.exception }
                                                              finally { if ($err -ne $null) { $status = $err.InnerException; Clear-Variable err } } }

if ($_.DisplayName -like "Citrix AD Identity Service") { try { $status = (Get-AcctServiceStatus -AdminAddress $controller -ErrorAction Stop ) }
                                                              catch { $err = $_.exception }
                                                              finally { if ($err -ne $null) { $status = $err.InnerException; Clear-Variable err } } }

if ($_.DisplayName -like "Citrix Analytics") { try { $status = (Get-AnalyticsServiceStatus -AdminAddress $controller -ErrorAction Stop ) }
                                                              catch { $err = $_.exception }
                                                              finally { if ($err -ne $null) { $status = $err.InnerException; Clear-Variable err } } }

if ($_.DisplayName -like "Citrix App Library") { try { $status = (Get-AppLibServiceStatus -AdminAddress $controller -ErrorAction Stop ) }
                                                              catch { $err = $_.exception }
                                                              finally { if ($err -ne $null) { $status = $err.InnerException; Clear-Variable err } } }

if ($_.DisplayName -like "Citrix Configuration Service") { try { $status = (Get-ConfigServiceStatus -AdminAddress $controller -ErrorAction Stop ) }
                                                              catch { $err = $_.exception }
                                                              finally { if ($err -ne $null) { $status = $err.InnerException; Clear-Variable err } } }

if ($_.DisplayName -like "Citrix Configuration Logging Service") { try { $status = (Get-LogServiceStatus -AdminAddress $controller -ErrorAction Stop ) }
                                                              catch { $err = $_.exception }
                                                              finally { if ($err -ne $null) { $status = $err.InnerException; Clear-Variable err } } }

if ($_.DisplayName -like "Citrix Environment Test Service") { try { $status = (Get-EnvTestServiceStatus -AdminAddress $controller -ErrorAction Stop ) }
                                                              catch { $err = $_.exception }
                                                              finally { if ($err -ne $null) { $status = $err.InnerException; Clear-Variable err } } }

if ($_.DisplayName -like "Citrix Host Service") { try { $status = (Get-HypServiceStatus -AdminAddress $controller -ErrorAction Stop ) }
                                                              catch { $err = $_.exception }
                                                              finally { if ($err -ne $null) { $status = $err.InnerException; Clear-Variable err } } }

if ($_.DisplayName -like "Citrix Machine Creation Service") { try { $status = (Get-ProvServiceStatus -AdminAddress $controller -ErrorAction Stop ) }
                                                              catch { $err = $_.exception }
                                                              finally { if ($err -ne $null) { $status = $err.InnerException; Clear-Variable err } } }

if ($_.DisplayName -like "Citrix Monitor Service") { try { $status = (Get-MonitorServiceStatus -AdminAddress $controller -ErrorAction Stop ) }
                                                              catch { $err = $_.exception }
                                                              finally { if ($err -ne $null) { $status = $err.InnerException; Clear-Variable err } } }

if ($_.DisplayName -like "Citrix Storefront Service") { try { $status = (Get-SfServiceStatus -AdminAddress $controller -ErrorAction Stop ) }
                                                              catch { $err = $_.exception }
                                                              finally { if ($err -ne $null) { $status = $err.InnerException; Clear-Variable err } } }

if ($_.DisplayName -like "Citrix Trust Service") { try { $status = (Get-TrustServiceStatus -AdminAddress $controller -ErrorAction Stop ) }
                                                              catch { $err = $_.exception }
                                                              finally { if ($err -ne $null) { $status = $err.InnerException; Clear-Variable err } } }

if ($_.DisplayName -like "Citrix Orchestration Service") { try { $status = (Get-OrchServiceStatus -AdminAddress $controller -ErrorAction Stop ) }
                                                              catch { $err = $_.exception }
                                                              finally { if ($err -ne $null) { $status = $err.InnerException; Clear-Variable err } } }

if ($status.ServiceStatus -ne $null) {
$outputobject = New-Object PSCustomObject -Property @{
'ServiceName' = $_.DisplayName
'ServiceState' = $_.Status
'ServiceStatus' = $status.ServiceStatus
'ExtraInfo' = $status.ExtraInfo
'Controller' = ($controller -replace ".fqdn.yourdomain.com")
'Error' = "NA" }

## use $outputarray for troubleshooting the script, doesn't impact output
$outputarray += $outputobject
}
else {
$outputobject = New-Object PSCustomObject -Property @{
'ServiceName' = $_.DisplayName
'ServiceState' = $_.Status
'ServiceStatus' = $status.ServiceStatus
'ExtraInfo' = $status.ExtraInfo
'Controller' = ($controller -replace ".fqdn.yourdomain.com")
'Error' = $status }

## use $errors for troubleshooting the script, doesn't impact output
$errors += $outputobject}

if ($status.ServiceStatus -notlike "*OK*") { 
#compose and send a (crudely) html formatted email
$body = @"
<html>
<body>
$($outputobject.Controller)
<br><br>
$($outputobject.ServiceName): $($outputobject.ServiceState)
<br><br>
$($outputobject.Error.Message)
<br><br>
Possible other info:
<br>
$($outputobject.ServiceStatus): $($outputobject.ExtraInfo)
</body>
</html>
"@

## send mail (note that you might need to authenticate)
Send-MailMessage -SmtpServer "yoursmtprelay.yourdomain.com" -Port 25 -From "XenDesktop_Look.At.It@yourdomain.com" -To "email_address@adomain.com" -Subject "XD Service: $($outputobject.ServiceName) Failure on $($outputobject.Controller)" -BodyAsHtml $body -Priority High
Clear-Variable body
}
Clear-Variable status, outputobject
}}