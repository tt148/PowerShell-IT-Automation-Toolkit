function Write-AuditLog {
    <#
    .SYNOPSIS
    Writes a structured audit event to the JSON-lines audit trail.
    .DESCRIPTION
    Use for explicit operator notes. Internal toolkit actions also write audit entries.
    .PARAMETER Action
    Short action identifier.
    .PARAMETER Target
    Fictional record or resource affected.
    .PARAMETER Result
    Outcome recorded in the audit trail.
    .EXAMPLE
    Write-AuditLog -Action 'manual-review' -Target 'EMP-1001' -Result Info
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Low')]
    param(
        [Parameter(Mandatory)][ValidateLength(2,80)][string]$Action,
        [Parameter(Mandatory)][ValidateLength(1,160)][string]$Target,
        [Parameter(Mandatory)][ValidateSet('Success','DryRun','Failed','Info')][string]$Result,
        [ValidateLength(0,500)][string]$Details = '',
        [ValidatePattern('^$|^[A-Za-z]{1,10}-[0-9]{1,10}$')][string]$TicketId = ''
    )
    if ($PSCmdlet.ShouldProcess($Target, "Write audit event '$Action'")) {
        Add-ToolkitAuditEntry -Action $Action -Target $Target -Result $Result -Details $Details -TicketId $TicketId
        [pscustomobject]@{ Action=$Action; Target=$Target; Result=$Result; Logged=$true }
    } else {
        Add-ToolkitAuditEntry -Action $Action -Target $Target -Result 'DryRun' -Details 'Audit event write requested with WhatIf/declined confirmation.' -TicketId $TicketId
        [pscustomobject]@{ Action=$Action; Target=$Target; Result='DryRun'; Logged=$true }
    }
}
