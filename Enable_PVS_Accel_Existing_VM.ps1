## Enable PVS Accelerator for existing VM's without recreating them.
## Assumption is that PVS Accelerator is already configured in the XenServer pool
## Matt Bodholdt

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

### Get VM's in XenServer Pools

if ((Get-PSSnapin -Name Citrix.Broker* -ErrorAction SilentlyContinue) -eq $null) { Add-PsSnapin Citrix* }
if ((Get-PSSnapin -Name Citrix.PVS.SnapIn -ErrorAction SilentlyContinue) -eq $null) { if ((Add-PsSnapin Citrix.PVS.SnapIn -ErrorAction SilentlyContinue) -eq $null) { throw "PVS Snapin Not Available" } }

if ((Get-Module -Name XenServerPSModule -ErrorAction SilentlyContinue) -eq $null) { Import-Module XenServerPSModule
    if ((Get-Module -Name XenServerPSModule -ErrorAction SilentlyContinue) -eq $null) { throw "You need to install the XenServer Powershell module" }
}

$username = "root"
$securepassword = read-host "Enter XenServer Password" -AsSecureString
$credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $securepassword



##  Set pool master of XenServer Pool, XD Controller, PVS Host Connection Name, PVS Server, and Desktop Group name
## Important Note, to create the host connection that has PVS Accelerator enabled I had to run the wizard from a PVS server and create a single VM.  For this script to work, name the host connection the same as the XenServer pool name.  At the time (and maybe still) there wasn't a way to create the host connection with powershell.

$poolmasters = "poolmaster.domain.com"
$xdcontroller = "xdcontroller.domain.com"
$pvsconnection = "XenServer Pool Name"
$pvsserver = "pvsserver.domain.com"
$dgname = "Desktop Group Name"


$xenserverarray = @()
$poolmasters | ForEach-Object {
$XenServer = $_

Try { Connect-XenServer -SetDefaultSession -Server $XenServer -Creds $credentials -NoWarnNewCertificates -NoWarnCertificates }
Catch {[XenAPI.Failure] ; Connect-XenServer -SetDefaultSession -Server $_.Exception.ErrorDescription[1] -Creds $credentials -NoWarnNewCertificates -NoWarnCertificates }
Finally { $poolname = Get-XenPool -ErrorAction SilentlyContinue ; if ($poolname -eq $null) { throw "No connection to XenServer pool - $($XenServer)" }
          $master = (Get-XenHost -Ref $poolname.master.opaque_ref).hostname 
        }

Get-XenVM -ErrorAction Stop | Where { $_.is_a_template -ne $true -and $_.is_a_snapshot -ne $true -and $_.name_description -notlike "The domain which manages physical devices and manages other domains" } | select name_label | sort | foreach {

$outputarray = New-Object PSObject -Property @{
Name = $_.name_label
Pool = $poolname.name_label
Master = $master
}
$xenserverarray += $outputarray
}

Disconnect-XenServer
Clear-Variable poolname, master, XenServer, outputarray
}



##### PVS Stuff

Set-PvsConnection -Server $pvsserver
$site = Get-PvsSite

$connections = Get-PvsVirtualHostingPool


## this will only work if the host connection is named the same as the pool in PVS
$connections |  where {$_.name -like "$($pvsconnection)"} | foreach {
$conn = $_

$xdtargets = Get-BrokerMachine -AdminAddress $xdcontroller -MaxRecordCount 10000 -HypervisorConnectionName $_.Name -DesktopGroupName $dgname -SessionState $null

$xdtargets | foreach { Set-BrokerMachine -AdminAddress $xdcontroller -MachineName $_.MachineName -InMaintenanceMode $true }

$targetarray = @()
$xdtargets | foreach {

 
try { $targetarray += Get-PvsDevice -DeviceName $_.HostedMachineName }
catch {  }
finally { }
}

    $targetarray | foreach {
    if ($_.xspvsproxyuuid.Guid -like "00000000-0000-0000-0000-000000000000") {
    $t = $_
    $temp = $xenserverarray | where {$_.Name -like $t.Name }
    $pvshypconn = $connections | where { $_.Name -like "$($temp.Pool)" }

    if ($pvshypconn -ne $null) {
        if ($_.Active -eq $true) { (New-BrokerHostingPowerAction -AdminAddress $xdcontroller -Action TurnOff -MachineName "MASTER\$($_.Name)") | Out-Null
                                   Start-Sleep -Seconds 5

                                   if ((Get-BrokerMachine -AdminAddress $xdcontroller -MachineName "MASTER\$($_.name)").PowerState -like "Off") { Invoke-PvsMarkDown -DeviceId $_.DeviceId ; $pwr = $false }
                                   else { Sleep -Seconds 7 
                                        if ((Get-BrokerMachine -AdminAddress $xdcontroller -MachineName "MASTER\$($_.name)").PowerState -like "Off") { Invoke-PvsMarkDown -DeviceId $_.DeviceId ; $pwr = $false }
                                        else { Write-Warning "Power state is not Off - $($_.name)" ; $pwr = $true }
                                   }}
    if($pwr -ne $true) {
    $currentassignment = (Get-PvsDiskLocator -DeviceId $_.DeviceId).DiskLocatorId
    Remove-PvsDevice -DeviceId $_.DeviceId
    New-PvsDevice -SiteName $_.SiteName -DeviceName $_.DeviceName -CollectionId $_.CollectionId -DeviceMac $_.DeviceMac -VirtualHostingPoolId $pvshypconn.VirtualHostingPoolId | Out-Null
    $newdevice = Get-PvsDevice -DeviceName $_.DeviceName
    Add-PvsDiskLocatorToDevice -DeviceId $newdevice.DeviceId -DiskLocatorId $currentassignment
    Set-PvsDevice -DeviceId $newdevice.DeviceId -EnableXsProxy 1
    Reset-PvsDeviceForDomain -DeviceId $newdevice.DeviceId
    Write-Host "$($_.Name) Set"
    }
    else { Write-Warning "Skipped $($_.name), powered on" }
    }
    Clear-Variable t, temp, pvshypconn, currentassignment, newdevice, pwr -ErrorAction SilentlyContinue
    }
    else { Write-Warning "$($_.Name) set to $($_.XsPvsProxyUuid.GUID) already" }
    }

Clear-Variable conn
}

$xdtargets | foreach { Set-BrokerMachine -AdminAddress $xdcontroller -MachineName $_.MachineName -InMaintenanceMode $true }

Clear-Variable xdtargets