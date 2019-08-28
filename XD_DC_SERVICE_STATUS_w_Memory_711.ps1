## XenDesktop Controller Service Status, etc
## Visual output
## For XenDesktop 7.11
## 
## Matt Bodholdt
##################################################

if ((Get-PSSnapin -Name Citrix.* -ErrorAction SilentlyContinue) -eq $null)
        { Add-PsSnapin Citrix.* }

## Change to $true to check system free memory via WMI
$calculatefreememory = $false

## Get-WmiCustom - Daniele Muscetta
Function Get-WmiCustom([string]$computername,[string]$namespace,[string]$class,[int]$timeout)
{
$ConnectionOptions = new-object System.Management.ConnectionOptions
$EnumerationOptions = new-object System.Management.EnumerationOptions

$timeoutseconds = new-timespan -seconds $timeout
$EnumerationOptions.set_timeout($timeoutseconds)

$assembledpath = "\\" + $computername + "\" + $namespace

$Scope = new-object System.Management.ManagementScope $assembledpath, $ConnectionOptions
$Scope.Connect()

$querystring = "SELECT * FROM " + $class

$query = new-object System.Management.ObjectQuery $querystring
$searcher = new-object System.Management.ManagementObjectSearcher
$searcher.set_options($EnumerationOptions)
$searcher.Query = $querystring
$searcher.Scope = $Scope

trap { $_ } $result = $searcher.get()

$tempresult = return $result
$tempresult > $null
}

## Status Color Selectors
function WriteStatusResponse 
{
    If
    ($response.ServiceStatus -eq 'OK'){Write-Host ($response.ServiceStatus)($response.ExtraInfo) -ForegroundColor Black -BackgroundColor Green}
    
    Else 
    {Write-Host $response.ServiceStatus $response.ExtraInfo -ForegroundColor Black -BackgroundColor Red}
}

#####################################

## Initial Desktop Controller Selection
$firstcontoller = Read-Host "Enter FQDN of an XD Desktop Controller"

## DC Status High Points/Enumeration
$controllerinfo = Get-BrokerController -AdminAddress $firstcontoller | select DNSName, ControllerVersion, State, LastStartTime, DesktopsRegistered, ActiveSiteServices, LicensingServerState, LicensingGraceState, LicensingGracePeriodReasons, LicensingGracePeriodTimesRemaining
write-host ""
$(get-date).DateTime
write-output $controllerinfo

$siteinfo = Get-ConfigSite -AdminAddress $firstcontoller | select LicenseServerName, LicenseServerPort, LicenseServerUri, LicensingModel, ProductCode, ProductEdition
write-host "Site licensing info" -ForegroundColor Black -BackgroundColor Gray
write-output $siteinfo

$licensedsessions = Get-BrokerSite -AdminAddress $firstcontoller | select LicensedSessionsActive, TrustRequestsSentToTheXmlServicePort, DnsResolutionEnabled, SecureIcaRequired
write-host $licensedsessions.LicensedSessionsActive "Licensed sessions active" -ForegroundColor Black -BackgroundColor Green
write-host ""
write-host "Other site details:" -ForegroundColor Black -BackgroundColor Gray
$licensedsessions | select TrustRequestsSentToTheXmlServicePort, DnsResolutionEnabled, SecureIcaRequired

## Individual Service Status'
ForEach ($controller in $controllerinfo.DNSName)
{
write-host ""
write-host $controller":" -ForegroundColor Black -BackgroundColor Cyan

write-host "Delegated Admin Service Status on $controller  " -NoNewline
    $response = (Get-AdminServiceStatus -AdminAddress $controller | select ServiceStatus, ExtraInfo)
    $response | WriteStatusResponse
    Clear-Variable -Name response

write-host "Broker Service Status on $controller   " -NoNewline
    $response = (Get-BrokerServiceStatus -AdminAddress $controller | select ServiceStatus, ExtraInfo)
    $response | WriteStatusResponse
    Clear-Variable -Name response

write-host "Monitor Service Status on $controller   " -NoNewline
    $response = (Get-MonitorServiceStatus -AdminAddress $controller | select ServiceStatus, ExtraInfo)
    $response | WriteStatusResponse
    Clear-Variable -Name response

write-host "Analytics Service Status on $controller   " -NoNewline
    $response = (Get-AnalyticsServiceStatus -AdminAddress $controller | select ServiceStatus, ExtraInfo)
    $response | WriteStatusResponse
    Clear-Variable -Name response

write-host "Host Service Status on $controller   " -NoNewline
    $response = (Get-HypServiceStatus -AdminAddress $controller | select ServiceStatus, ExtraInfo)
    $response | WriteStatusResponse
    Clear-Variable -Name response

write-host "AD Identity Service Status on $controller   "  -NoNewline
    $response = (Get-AcctServiceStatus -AdminAddress $controller | select ServiceStatus, ExtraInfo)
    $response | WriteStatusResponse
    Clear-Variable -Name response

write-host "Configuration Service Status on $controller   " -NoNewline
    $response = (Get-ConfigServiceStatus -AdminAddress $controller | select ServiceStatus, ExtraInfo)
    $response | WriteStatusResponse
    Clear-Variable -Name response

write-host "Config Logging Service Status on $controller   " -NoNewline
    $response = (Get-LogServiceStatus -AdminAddress $controller | select ServiceStatus, ExtraInfo)
    $response | WriteStatusResponse
    Clear-Variable -Name response

write-host "Environment Test Service Status on $controller   " -NoNewline
    $response = (Get-EnvTestServiceStatus -AdminAddress $controller | select ServiceStatus, ExtraInfo)
    $response | WriteStatusResponse
    Clear-Variable -Name response

write-host "MCS (Provisioning) Service Status on $controller   " -NoNewline
    $response = (Get-ProvServiceStatus -AdminAddress $controller | select ServiceStatus, ExtraInfo)
    $response | WriteStatusResponse
    Clear-Variable -Name response

write-host "StoreFront Service Status on $controller   " -NoNewline
    $response = (Get-SfServiceStatus -AdminAddress $controller | select ServiceStatus, ExtraInfo)
    $response | WriteStatusResponse
    Clear-Variable -Name response

write-host "App Library Service Status on $controller   " -NoNewline
    $response = (Get-AppLibServiceStatus -AdminAddress $controller | select ServiceStatus, ExtraInfo)
    $response | WriteStatusResponse
    Clear-Variable -Name response

write-host "Orchestration Service Status on $controller   " -NoNewline
    $response = (Get-OrchServiceStatus -AdminAddress $controller | select ServiceStatus, ExtraInfo)
    $response | WriteStatusResponse
    Clear-Variable -Name response

write-host "Trust Service Status on $controller   " -NoNewline
    $response = (Get-TrustServiceStatus -AdminAddress $controller | select ServiceStatus, ExtraInfo)
    $response | WriteStatusResponse
    Clear-Variable -Name response

write-host ""
write-host "Broker DB Connection:" -ForegroundColor Black -BackgroundColor Gray
    $response = Get-BrokerDBConnection -AdminAddress $controller
    $response 
    Clear-Variable response

write-host "Monitor DB Connection:" -ForegroundColor Black -BackgroundColor Gray
    $response = Get-MonitorDBConnection -AdminAddress $controller -DataStore Monitor
    $response
    Clear-Variable response

write-host "Config Logging DB Connection:" -ForegroundColor Black -BackgroundColor Gray
    $response = Get-LogDBConnection -AdminAddress $controller -DataStore Logging
    $response
    Clear-Variable response

if ($calculatefreememory -eq $true) {
write-host ""
Write-host "Getting memory stats for"($controller)": Patience! (20 second timeout)"
$memorystats = Get-WmiCustom -Class Win32_PerfFormattedData_PerfOS_Memory -namespace "root\cimv2" -timeout 20 -ComputerName $controller | select AvailableMBytes
write-host ""
write-host "Available Memory:" $memorystats.AvailableMBytes "MB" -ForegroundColor Black -BackgroundColor Yellow }
    }

$hypervisorstatus = Get-BrokerHypervisorConnection -AdminAddress $firstcontoller | select Name, Uid, IsReady, State, MachineCount, PreferredController
write-host ""
write-host "Hypervisor connection status:" -ForegroundColor Black -BackgroundColor Gray
write-output $hypervisorstatus | ft
Clear-Variable -Name controller, controllerinfo