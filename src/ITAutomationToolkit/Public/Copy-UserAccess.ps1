function Copy-UserAccess {
    <#
    .SYNOPSIS
    Copies fictional group memberships between two employees.
    .PARAMETER SourceEmployeeId
    Employee whose groups will be used as the source.
    .PARAMETER TargetEmployeeId
    Employee who will receive missing groups.
    .PARAMETER IncludePrivileged
    Allows groups marked privileged in the simulated directory.
    .EXAMPLE
    Copy-UserAccess -SourceEmployeeId EMP-101 -TargetEmployeeId EMP-102 -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    param(
        [Parameter(Mandatory)][ValidatePattern('^EMP-[0-9]{3,6}$')][string]$SourceEmployeeId,
        [Parameter(Mandatory)][ValidatePattern('^EMP-[0-9]{3,6}$')][string]$TargetEmployeeId,
        [switch]$IncludePrivileged,
        [ValidatePattern('^$|^[A-Za-z]{1,10}-[0-9]{1,10}$')][string]$TicketId = ''
    )
    try {
        if ($SourceEmployeeId -eq $TargetEmployeeId) { throw 'Source and target employee IDs must be different.' }
        $employees = @(Import-ToolkitCsv -Name employees)
        $source = $employees | Where-Object EmployeeId -eq $SourceEmployeeId
        $target = $employees | Where-Object EmployeeId -eq $TargetEmployeeId
        if ($null -eq $source) { throw "Source employee '$SourceEmployeeId' was not found." }
        if ($null -eq $target) { throw "Target employee '$TargetEmployeeId' was not found." }

        $sourceGroups = @([string]$source.Groups -split ';' | Where-Object { $_ })
        $targetGroups = @([string]$target.Groups -split ';' | Where-Object { $_ })
        $toAdd = @($sourceGroups | Where-Object { $targetGroups -notcontains $_ })
        $skipped = @($sourceGroups | Where-Object { $targetGroups -contains $_ })
        $allGroups = @(Import-ToolkitCsv -Name groups)
        $privilegedNames = @($allGroups | Where-Object { $_.Privileged -eq 'true' } | ForEach-Object GroupName)
        $privileged = @($toAdd | Where-Object { $privilegedNames -contains $_ })
        if ($privileged.Count -gt 0 -and -not $IncludePrivileged) {
            throw "Privileged groups cannot be copied without -IncludePrivileged: $($privileged -join ', ')"
        }

        $details = "source=$SourceEmployeeId; target=$TargetEmployeeId; add=$($toAdd -join ','); skipped=$($skipped -join ','); privileged=$($privileged -join ',')"
        $shouldCopy = $PSCmdlet.ShouldProcess($TargetEmployeeId, "Copy access groups: $($toAdd -join ', ')")
        if ($shouldCopy) {
            foreach ($row in $employees) {
                if ($row.EmployeeId -eq $TargetEmployeeId) { $row.Groups = @($targetGroups + $toAdd | Select-Object -Unique) -join ';' }
            }
            Export-ToolkitCsv -Name employees -Rows $employees
            Add-ToolkitAuditEntry -Action 'copy-user-access' -Target "$SourceEmployeeId->$TargetEmployeeId" -Result Success -Details $details -TicketId $TicketId
        } else {
            Add-ToolkitAuditEntry -Action 'copy-user-access' -Target "$SourceEmployeeId->$TargetEmployeeId" -Result DryRun -Details "Would copy access; $details" -TicketId $TicketId
        }

        [pscustomobject]@{
            SourceEmployeeId=$SourceEmployeeId; TargetEmployeeId=$TargetEmployeeId; Added=$toAdd
            Skipped=$skipped; Privileged=$privileged; DryRun=(-not $shouldCopy)
        }
    } catch {
        Add-ToolkitAuditEntry -Action 'copy-user-access' -Target "$SourceEmployeeId->$TargetEmployeeId" -Result Failed -Details $_.Exception.Message -TicketId $TicketId
        throw "Copy user access failed: $($_.Exception.Message)"
    }
}
