function Get-DeviceInventory {
    <#
    .SYNOPSIS
    Lists devices from the fictional device inventory.
    .DESCRIPTION
    Returns operating system, last-seen, disk, patch and ownership information.
    .PARAMETER OwnerId
    Optionally filter by fictional employee ID.
    .EXAMPLE
    Get-DeviceInventory -OwnerId EMP-101
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Low')]
    param([ValidatePattern('^EMP-[0-9]{3,6}$')][string]$OwnerId)
    if (-not $PSCmdlet.ShouldProcess('simulated device inventory','Read inventory')) { Add-ToolkitAuditEntry -Action 'device-inventory' -Target 'all-devices' -Result DryRun -Details 'Read-only inventory preview.' }
    $devices=@(Import-ToolkitCsv -Name devices)
    if ($OwnerId) { $devices=@($devices | Where-Object OwnerId -eq $OwnerId) }
    Add-ToolkitAuditEntry -Action 'device-inventory' -Target 'all-devices' -Result Info -Details "Returned $($devices.Count) device record(s)."
    $devices | Select-Object DeviceId,DeviceName,OwnerId,OperatingSystem,OSVersion,LastSeen,DiskFreePercent,PatchStatus,ReturnRequired
}
