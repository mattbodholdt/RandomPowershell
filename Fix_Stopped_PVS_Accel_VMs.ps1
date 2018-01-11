## Fix machines that dont successfully initialize PVS accelerator.  Basically flips the bit off then back on in PVS so the proxy gets re-created
## Matt Bodholdt

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if ((Get-PSSnapin -Name Citrix.PVS.SnapIn -ErrorAction SilentlyContinue) -eq $null) { if ((Add-PsSnapin Citrix.PVS.SnapIn -ErrorAction SilentlyContinue) -eq $null) { throw "PVS Snapin Not Available" } }

if ((Get-Module -Name XenServerPSModule -ErrorAction SilentlyContinue) -eq $null) { Import-Module XenServerPSModule
    if ((Get-Module -Name XenServerPSModule -ErrorAction SilentlyContinue) -eq $null) { throw "You need to install the XenServer Powershell module.  Run \\master\vdi\VDI_CONTENT\PRODUCTION\PROD SCRIPTS\XenServer\InstallXS65PowershellMod.cmd as administrator to install.  Exiting" }
}

$poolmaster = "poolmaster.domain.com"
$pvsserver = "pvs.domain.com"
$xdcontroller = "xdcontroller.domain.com"

Connect-xenserver -SetDefaultSession -server $poolmaster -NoWarnNewCertificates -NoWarnCertificates

Set-PvsConnection -Server $pvsserver

$hosts = Get-XenHost
$proxy = Get-XenPVSProxy | where {$_.status -like "stopped"}

$i=0
$proxy | foreach { 
    $i++
       Write-Progress -Activity "PVS Accelerator" -Status ("Checking Proxy : {0}" -f $_.uuid) -PercentComplete ($i/$proxy.count*100) -Id 0 

$vif = Get-XenVIF -Ref $_.VIF
$vm = Get-XenVM -Ref $vif.VM
#$metrics = Get-XenVMGuestMetrics -Ref $vm.guest_metrics


if (($vm.power_state -like "Running") -and ($_.status -like "stopped")) { 
Write-Output "$($vm.name_label) : $(($hosts | where {$_.opaque_ref -like $vm.resident_on.opaque_ref}).name_label)"
   if ((Get-BrokerDesktop -AdminAddress $xdcontroller -MachineName "*\$($vm.name_label)").SessionState -notlike "Active") { 
    try { Invoke-XenVM -VM $vm -XenAction Shutdown | Wait-XenTask }
    catch { $err = $_ }
    finally { if ($err -ne $null) { Invoke-XenVM -VM $vm -XenAction HardShutdown | Wait-XenTask ; Invoke-PvsMarkDown -DeviceName $vm.name_label }}
    $pvsdevice = Get-PvsDevice -DeviceName $vm.name_label
    Set-PvsDevice -DeviceId $pvsdevice.DeviceId -EnableXsProxy 0
    Set-PvsDevice -DeviceId $pvsdevice.DeviceId -EnableXsProxy 1
    Clear-Variable pvsdevice
    }
    else { Write-Warning "$($vm.name_label) has an active session, skipped" }
Clear-Variable vif, vm
}


   }
Clear-Variable proxy
Disconnect-XenServer