## Install PVS 7.7+ Powershell Module - Install PVS Console before running this.
## Needs to have powershell ran as admin


## For a PVS Server with console installed to D, hard code the D:\Program Files director
#pushd "D:\Program Files\Citrix\Provisioning Services Console"

## Otherwise, for a workstation
pushd "$env:PROGRAMFILES\Citrix\Provisioning Services Console"

#Installation
if ($env:PROCESSOR_ARCHITECTURE -eq "AMD64"){
$installutil = $env:systemroot + '\Microsoft.NET\Framework64\v4.0.30319\installutil.exe'
&$installutil Citrix.PVS.SnapIn.dll
}
if ($env:PROCESSOR_ARCHITECTURE -eq "x86"){
$installutil1 = $env:systemroot + '\Microsoft.NET\Framework\v4.0.30319\installutil.exe'
&$installutil1 Citrix.PVS.SnapIn.dll
}

Add-PSSnapin -Name Citrix.PVS.SnapIn
if ((Get-PSSnapin -Name Citrix.PVS.SnapIn -ErrorAction SilentlyContinue) -eq $null)
{
	Add-PsSnapin Citrix.PVS.SnapIn
    if ((Get-PSSnapin -Name Citrix.PVS.SnapIn -ErrorAction SilentlyContinue) -eq $null)
        {Write-host "PVS Powershell SnapIn (Citrix.PVS.SnapIn) is not available.  Try again, make sure PVS Console is installed.  Exiting" -ForegroundColor Black -BackgroundColor Green
        exit}
}
else {(Write-host "PVS Powershell SnapIn (Citrix.PVS.SnapIn) installed successfully" -ForegroundColor Black -BackgroundColor Green)}