function Get-DeviceHealthReport {
    <#
    .SYNOPSIS
    Identifies unhealthy fictional devices.
    .DESCRIPTION
    Flags stale devices, low free disk space and missing patches.
    .PARAMETER DiskFreeThreshold
    Devices below this free disk percentage are unhealthy.
    .PARAMETER StaleAfterDays
    Devices last seen before this many days ago are stale.
    .EXAMPLE
    Get-DeviceHealthReport -DiskFreeThreshold 15 -StaleAfterDays 14
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Low')]
    param([ValidateRange(1,99)][int]$DiskFreeThreshold=15,[ValidateRange(1,365)][int]$StaleAfterDays=14)
    if (-not $PSCmdlet.ShouldProcess('simulated device inventory','Evaluate device health')) { Add-ToolkitAuditEntry -Action 'device-health-report' -Target 'all-devices' -Result DryRun -Details 'Read-only health preview.' }
    $devices=@(Import-ToolkitCsv -Name devices)
    foreach ($device in $devices) {
        $flags=@()
        $disk=0.0; [void][double]::TryParse([string]$device.DiskFreePercent,[ref]$disk)
        if ($disk -lt $DiskFreeThreshold) {$flags+='LowDiskSpace'}
        if ($device.PatchStatus -ne 'Compliant') {$flags+='PatchRequired'}
        if (Test-ToolkitStaleDate -DateText $device.LastSeen -Days $StaleAfterDays) {$flags+='DeviceStale'}
        if ($device.ReturnRequired -eq 'true') {$flags+='ReturnRequired'}
        [pscustomobject]@{ DeviceId=$device.DeviceId; DeviceName=$device.DeviceName; OwnerId=$device.OwnerId; OperatingSystem=$device.OperatingSystem; OSVersion=$device.OSVersion; LastSeen=$device.LastSeen; DiskFreePercent=$disk; PatchStatus=$device.PatchStatus; IsHealthy=($flags.Count -eq 0); Flags=$flags }
    }
    Add-ToolkitAuditEntry -Action 'device-health-report' -Target 'all-devices' -Result Info -Details "Evaluated $($devices.Count) fictional device(s)."
}
