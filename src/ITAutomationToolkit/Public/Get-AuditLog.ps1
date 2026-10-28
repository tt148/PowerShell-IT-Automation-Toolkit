function Get-AuditLog {
    <#
    .SYNOPSIS
    Reads the fictional JSON-lines audit trail.
    .PARAMETER TicketId
    Optional ticket identifier filter.
    .PARAMETER Action
    Optional action filter.
    .PARAMETER Last
    Maximum number of newest records to return.
    .EXAMPLE
    Get-AuditLog -TicketId HD-1234
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Low')]
    param(
        [ValidatePattern('^$|^[A-Za-z]{1,10}-[0-9]{1,10}$')][string]$TicketId = '',
        [ValidateLength(0,80)][string]$Action = '',
        [ValidateRange(1,10000)][int]$Last = 100
    )
    if (-not $PSCmdlet.ShouldProcess('simulated audit log', 'Read audit activity')) {
        Add-ToolkitAuditEntry -Action 'audit-log-read' -Target 'audit-log' -Result DryRun -Details 'Read-only audit preview.' -TicketId $TicketId
        return
    }
    $paths = Get-ToolkitPath
    if (-not (Test-Path -LiteralPath $paths.Audit)) { return @() }
    $records = @()
    foreach ($line in @(Get-Content -LiteralPath $paths.Audit -ErrorAction Stop)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try { $records += $line | ConvertFrom-Json -ErrorAction Stop } catch { continue }
    }
    if ($TicketId) { $records = @($records | Where-Object { $_.ticketId -eq $TicketId }) }
    if ($Action) { $records = @($records | Where-Object { $_.action -eq $Action }) }
    Add-ToolkitAuditEntry -Action 'audit-log-read' -Target 'audit-log' -Result Success -Details "Returned $($records.Count) audit record(s); TicketId=$TicketId" -TicketId $TicketId
    $records | Sort-Object timestamp -Descending | Select-Object -First $Last
}
