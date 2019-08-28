## Bind SSL Cert to Citrix XenDesktop 7.11 Broker XML Listener - No IIS Integration Configured
## Run this on the controller(s) to secure XML traffic only if IIS Integration is not configured
## 
## 1. Import the web cert into the computer's personal store
## 2. Change variables $tlsport and $clearport to the desired port numbers
## 3. Determine if any previous certificate bindings exist (if you are renewing an existing cert, you have to delete the old binding before the new one can exist)
##       A list of existing cert bindings will be presented when running the script, select the binding to remove.  This can be validated manually by running 'netsh http show sslcerts'
## 4. Run it, do note that changing the broker service config does cycle the broker service
## 5. Change NetScaler/Storefront STA config to use the TLS listener
##
## If it fails where the commands complete successfully but the listeners aren't running, make sure there aren't any port conflicts.
## Setting a log file with brokerservice.exe is useful for diagnosing the cause of listener failures
## See https://support.citrix.com/article/CTX200415 for more info
## The TLS listener will use the ciphers and protocols that are enabled on the system.  See Computer Config -> Admin Templates -> Netwok -> SSL Configuration Settings -> SSL Cipher Suite Order
##     as well as the registry entries for propcol versions at HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\...
##     Wireshark is your friend too if there are issues connecting from NetScaler/Storefront and the config looks right on the controller
## Do be cautious, if this goes wrong and you're not familiar with troubleshooting these configurations you might end up requiring support.  No implied guarantees for your specific environment regarding functionality in this script.
## 12/17/2016 - Changed cert selection section to prevent issues with wildcard certs and other certs which have special characters in the subject.
## Matt Bodholdt - 12/17/2016

## Ports to use for XML listeners
$tlsport = "4443"
$clearport = "8080"

function Select-TextItem 
{ 
PARAM  
( 
    [Parameter(Mandatory=$true)] 
    $options, 
    $displayProperty 
) 
    [int]$optionPrefix = 1 
    foreach ($option in $options) 
    { if ($displayProperty -eq $null) { Write-Host ("{0,3}: {1}" -f $optionPrefix,$option)} 
      else{ Write-Host ("{0,3}: {1}" -f $optionPrefix,$option.$displayProperty) } 
    $optionPrefix++ } 
    Write-Host ("{0,3}: {1}" -f 0,"To cancel")  
    [int]$response = Read-Host "Enter Selection" 
    $val = $null 
    if ($response -gt 0 -and $response -le $options.Count) 
    { $val = $options[$response-1] } 
    return $val 
}
 
## Start
Push-Location 
Set-Location 'C:\Program Files\Citrix\Broker\Service'
write-host "Existing Broker Config:" -ForegroundColor Black -BackgroundColor Gray
.\BrokerService.exe -show

## Check for existing listeners on the selected ports and present a way out
$listenerarray = @()
$listenercheck = Get-NetTCPConnection -State Listen -LocalPort $tlsport, $clearport
if ($listenercheck -ne $null) {
$listenercheck | foreach { 
$outputobject = New-Object psobject -Property @{
LocalAddress = $_.LocalAddress
LocalPort = $_.LocalPort
State = $_.State
OwningProcessID = $_.OwningProcess
OwningProcessName = (Get-Process -Id $_.OwningProcess).ProcessName
}
$listenerarray += $outputobject
Clear-Variable outputobject
}
write-host ""
write-host "Current processes listening on chosen ports:" -ForegroundColor Black -BackgroundColor Gray 
$listenerarray | select LocalPort, OwningProcessID, OwningProcessName, State | fl
$exit = Read-Host "Existing Listeners on the same ports (listed above, this is informational only and is likely expected), Y to continue, N to stop"
if ($exit -like "n") { throw "User exited"}
}

## Determine IPv4 Address to bind to
$ip = (Get-NetIPAddress | where {($_.AddressFamily -like "IPv4") -and ($_.InterfaceAlias -notlike "Loop*")}).IPAddress
if ($ip.count -ge 2) { write-host "Multiple IPv4 Addresses Available, Select the IP to bind to:" -ForegroundColor Black -BackgroundColor Gray
$ipselection = Select-TextItem $ip
if ($ipselection -eq $null) {throw "No IPv4 address selected"}
$ip = $ipselection 
}

## Get certificate to bind's info and selection
$cert = (Get-ChildItem Microsoft.PowerShell.Security\Certificate::LocalMachine\My)
if ($cert -eq $null) { throw "No Cert(s) Found" }
write-output ($cert | select Subject, Thumbprint)
write-host ""
write-host "Select which cert to bind to the TLS listener by choosing the correct thumbprint, installed certs are listed above:" -ForegroundColor Black -BackgroundColor Gray
$certselection = Select-TextItem $cert.thumbprint
if ($certselection -eq $null) { throw "No cert selected" }
$cert = $cert | where { $_.Thumbprint -like $certselection }

## Get broker service GUID
$brokerguid = (Get-ChildItem "Registry::HKEY_CLASSES_ROOT\Installer\Products" | foreach { Get-ItemProperty $_.pspath | where {$_.ProductName -like "Citrix Broker Service"}}).pschildname
$properguid = $brokerguid.Insert(8,'-').insert(13,'-').insert(18,'-').insert(23,'-')
if ($properguid -eq $null) { throw "No broker service GUID found" }

## List existing SSL Cert bindings and select for removal
$sslbindings = (Get-ChildItem "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\HTTP\Parameters\SslBindingInfo")
if ($sslbindings -ne $null) {
$bindinglist = ($sslbindings.name).trimstart('HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\HTTP\Parameters\SslBindingInfo\')
write-host "Select from the list below to remove the cert binding.  Select 0 to not remove any existing bindings" -ForegroundColor Black -BackgroundColor Gray
$removebindingselection = Select-TextItem $bindinglist
if ($removebindingselection -ne $null) {
$removestring = "http delete sslcert ipport=$($removebindingselection)"
Start-Process netsh.exe $removestring
Clear-Variable removebindingselection, bindinglist, sslbindings, removestring
## Wait 3 seconds to prevent overlap in remove/add commands
Start-Sleep -Seconds 3
}
else { write-host "No existing cert bindings, nothing to remove" }
}

## Bind new cert
$cmdstring = "http add sslcert ipport=$($ip):$($tlsport) certhash=$($cert.Thumbprint) appid={$($properguid)}"
start-process netsh.exe $cmdstring

## Update broker service config
.\BrokerService.exe -StoreFrontTlsPort $tlsport -StoreFrontPort $clearport
write-host ""

## Give the listeners a couple seconds to come up
sleep -Seconds 2

## Check for listeners/binding
write-host "Check for TLS XML Listener on $($tlsport)" -ForegroundColor Black -BackgroundColor Gray
if ((Get-NetTCPConnection -State Listen -LocalPort $tlsport -ErrorAction SilentlyContinue) -ne $null) { write-host "TLS Listener is UP" -ForegroundColor Black -BackgroundColor Green }
else { write-host "TLS Listener is NOT UP" -ForegroundColor Black -BackgroundColor Red }
$sslbindcheck = (Get-ChildItem "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\HTTP\Parameters\SslBindingInfo").name.trimstart('HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\HTTP\Parameters\SslBindingInfo\') | where {$_ -match "$($ip):$($tlsport)"}
if ($sslbindcheck -eq "$($ip):$($tlsport)") { write-host "There is a cert bound to the TLS Listener on $($ip):$($tlsport)" -ForegroundColor Black -BackgroundColor Green } 
else { write-host "There is likely an issue with the SSL Cert binding and the service is probably down even though the listener is probably up.  Run 'netsh http show sslcerts' at command line list the bindings" -ForegroundColor Black -BackgroundColor Red }

write-host ""
write-host "Check for Clear Text XML Listener on $($clearport)" -ForegroundColor Black -BackgroundColor Gray
if ((Get-NetTCPConnection -State Listen -LocalPort $clearport -ErrorAction SilentlyContinue) -ne $null) { write-host "Clear Port Listener is UP" -ForegroundColor Black -BackgroundColor Green }
else { write-host "Clear Port Listener is NOT UP" -ForegroundColor Black -BackgroundColor Red }

write-host ""
Write-Host "New Broker Config:" -ForegroundColor Black -BackgroundColor Gray
.\BrokerService.exe -show

Pop-Location
Clear-Variable tlsport, clearport, cmdstring, brokerguid, properguid, cert, ip, listenerarray, listenercheck