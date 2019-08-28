## PVS Server/vDisk Status Check (PVS 7.7+)
## Matt Bodholdt
##
## See last line in script, you need to put in server/address info so the output is emailed.  If you don't like that, work with statusoutputarray and diskstatusoutputarray
##
############

## Put a PVS Server FQDN here
$pvsserver = "a-single-pvs-server.fqdn.yourdomain.com"

if ((Get-PSSnapin -Name Citrix.PVS.SnapIn -ErrorAction SilentlyContinue) -eq $null)
{
	Add-PsSnapin Citrix.PVS.SnapIn
}

Set-PvsConnection -Server $pvsserver

$servers = Get-PvsServer
$statusoutputarray = @()
$servers | ForEach-Object {
$statusout = @()
$status = Get-PvsServerStatus -ServerName $_.ServerName

if ($status.Status -eq 0) {
$statusout = New-Object PSObject -Property @{
Name = $_.ServerName
Status = "Down"
Connections = $status.DeviceCount} }

if ($status.Status -eq 2) {
$statusout = New-Object PSObject -Property @{
Name = $_.ServerName
Status = "Unknown"
Connections = $status.DeviceCount} }

if ($status.Status -eq 1) {
$statusout = New-Object PSObject -Property @{
Name = $_.ServerName
Status = "OK"
Connections = $status.DeviceCount} }

$statusoutputarray += $statusout
}


$i=0
$disks = Get-PvsDiskLocator
$diskoutputarray = @()
$disks | ForEach-Object {
    $i++
       Write-Progress   -Activity "Checking vDisk status, connections, and replication" -Status ("Checking : {0}" -f $_.DiskLocatorName) -PercentComplete ($i/$disks.Count*100) -Id 0 
$diskinfo = Get-PvsDiskInfo -DiskLocatorId $_.DiskLocatorId.Guid
$replicationstatus = Get-PvsDiskInventory -DiskLocatorID $_.DiskLocatorID.Guid | select ServerName, State
$replicationissues = $replicationstatus | Where-Object { $_.State -eq '1'}

if ($_.ServerName -eq "") {
$lbenabled = "Yes"
$serverdisk = "NA" }
else { 
$lbenabled = "No"
$serverdisk = $_.ServerName }

if ($diskinfo.WriteCacheType -eq 0) {
$writecachemode = "Private"
$writecachesize = "NA" }

if ($diskinfo.WriteCacheType -eq 1) {
$writecachemode = "Cache on Server"
$writecachesize = "NA" }

if ($diskinfo.WriteCacheType -eq 3) {
$writecachemode = "Cache in Device RAM"
$writecachesize = $diskinfo.WriteCacheSize }

if ($diskinfo.WriteCacheType -eq 4) {
$writecachemode = "Cache in Device Disk"
$writecachesize = "NA" }

if ($diskinfo.WriteCacheType -eq 6) {
$writecachemode = "Device Ram Disk"
$writecachesize = $diskinfo.WriteCacheSize }

if ($diskinfo.WriteCacheType -eq 7) {
$writecachemode = "Persistent Cache on Server"
$writecachesize = "NA" }

if ($diskinfo.WriteCacheType -eq 9) {
$writecachemode = "RAMCache w Overflow"
$writecachesize = $diskinfo.WriteCacheSize }

if ($diskinfo.LicenseMode -eq 0) {
$licensemode = "None" }

if ($diskinfo.LicenseMode -eq 1) {
$licensemode = "MAK" }

if ($diskinfo.LicenseMode -eq 2) {
$licensemode = "KMS" }


if ($replicationissues -eq $null) {
$replicationissueflag = "No"
$diskout = New-Object PSObject -Property @{
Name = $_.DiskLocatorName
Connections = $diskinfo.DeviceCount
ReplicationIssue = $replicationissueflag
ReplicationIssueServers = "NA"
LoadBalanced = $lbenabled
ServerDiskIsOn = $serverdisk
WriteCacheMode = $writecachemode
WriteCacheSize = $writecachesize
VHDX = $diskinfo.VHDX
LicenseMode = $licensemode
}
}
else {
$replicationissueflag = "Yes"
$diskout = New-Object PSObject -Property @{
Name = $_.DiskLocatorName
Connections = $diskinfo.DeviceCount
ReplicationIssue = $replicationissueflag
ReplicationIssueServers = ($replicationissues.ServerName -join ",")
LoadBalanced = $lbenabled
ServerDiskIsOn = $serverdisk
WriteCacheMode = $writecachemode
WriteCacheSize = $writecachesize
VHDX = $diskinfo.VHDX
LicenseMode = $licensemode

}
}
$diskoutputarray += $diskout
Clear-Variable diskinfo, replcationstatus, replicationissues, serverdisk, lbenabled, diskout, replicationissueflag, writecachemode, writecachesize, licensemode -ErrorAction SilentlyContinue
}

$style = "<style>BODY{font-family: Arial; font-size: 10pt;}"
$style = $style + "TABLE{border: 1px solid black; border-collapse: collapse;}"
$style = $style + "TH{border: 1px solid black; background: #dddddd; padding: 5px; }"
$style = $style + "TD{border: 1px solid black; padding: 5px; }"
$style = $style + "</style>"

$formattedstatus = $statusoutputarray | sort -Property Name | select Name, Status, Connections | ConvertTo-Html -Head $style
$formatteddisk = $diskoutputarray | sort -Property Name | select Name, Connections, LoadBalanced, ServerDiskIsOn, WriteCacheMode, WriteCacheSize, LicenseMode, VHDX, ReplicationIssue, ReplicationIssueServers | ConvertTo-Html -Head $style
$emailoutputdata = ($formattedstatus + $formatteddisk) | Out-String

## note you may need to authenticate
Send-MailMessage -SmtpServer "YOURMAILSERVERHERE" -Port 25 -From "PVS_Look.At.It@domain.com" -To "youremail@domain.com" -Subject "PVS Server/vDisk Info" -BodyAsHtml -Body $emailoutputdata