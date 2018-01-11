## Remove unused host connections from PVS
## Matt Bodholdt

$pvsserver = "pvs.domain.com"

Set-PvsConnection -Server $pvsserver
$connections = Get-PvsVirtualHostingPool

$pvsdevices = Get-PvsDevice
Write-Host "$($pvsdevices.count) devices in PVS"
Write-Host "$(($pvsdevices | where {$_.VirtualHostingPoolId -like "00000000-0000-0000-0000-000000000000"}).count) devices with no host connection"

$totalcount = 0
$connections | foreach {
$conn = $_
$vms = $pvsdevices | where { $_.VirtualHostingPoolId -like $conn.VirtualHostingPoolId }

if ($vms -eq $null) { Write-Host "$($_.Name) - $($_.VirtualHostingPoolId) - No VMs.  Removing" -ForegroundColor Black -BackgroundColor Green 

## Comment out remove-pvsvirtualhostingpool for a dry run
Remove-PvsVirtualHostingPool -VirtualHostingPoolId $conn.VirtualHostingPoolId
Write-Host "$($conn.Name) Removed"

}
else { Write-Host "$($_.Name) - $($_.VirtualHostingPoolId) - $($vms.count) VMs" -ForegroundColor Black -BackgroundColor Yellow
$totalcount += $vms.count }

Clear-Variable conn, vms
}
$totalcount

if (($totalcount + ($pvsdevices | where {$_.VirtualHostingPoolId -like "00000000-0000-0000-0000-000000000000"}).count) -ne $pvsdevices.count) { Write-Warning "The count's do not line up, look at it" }

