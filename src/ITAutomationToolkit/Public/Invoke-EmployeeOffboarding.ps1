function Invoke-EmployeeOffboarding {
    <#
    .SYNOPSIS
    Disables a fictional employee, removes group memberships and flags assigned devices for return.
    .DESCRIPTION
    All changes affect only the local CSV-backed simulated directory.
    .PARAMETER EmployeeId
    Existing fictional employee identifier.
    .EXAMPLE
    Invoke-EmployeeOffboarding -EmployeeId EMP-103 -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    param([Parameter(Mandatory)][ValidatePattern('^EMP-[0-9]{3,6}$')][string]$EmployeeId)
    $target=$EmployeeId
    try {
        $employees=@(Import-ToolkitCsv -Name employees)
        $employee=@($employees | Where-Object EmployeeId -eq $EmployeeId | Select-Object -First 1)
        if (-not $employee) { throw "Employee '$EmployeeId' was not found." }
        $devices=@(Import-ToolkitCsv -Name devices)
        $assigned=@($devices | Where-Object OwnerId -eq $EmployeeId)
        if ($PSCmdlet.ShouldProcess($target, 'Disable account, remove groups and flag assigned devices for return')) {
            foreach ($row in $employees) { if ($row.EmployeeId -eq $EmployeeId) { $row.Enabled='false'; $row.Groups=''; $row.PasswordResetRequired='true' } }
            foreach ($device in $devices) { if ($device.OwnerId -eq $EmployeeId) { $device.ReturnRequired='true' } }
            Export-ToolkitCsv -Name employees -Rows $employees
            Export-ToolkitCsv -Name devices -Rows $devices
            Add-ToolkitAuditEntry -Action 'employee-offboarding' -Target $target -Result Success -Details "Account disabled; groups removed; devices flagged=$($assigned.Count)."
            Write-Verbose "Offboarded simulated employee $EmployeeId."
            [pscustomobject]@{ EmployeeId=$EmployeeId; AccountDisabled=$true; GroupsRemoved=$true; DevicesFlaggedForReturn=$assigned.Count; DryRun=$false }
        } else {
            Add-ToolkitAuditEntry -Action 'employee-offboarding' -Target $target -Result DryRun -Details "Would disable account, remove groups and flag $($assigned.Count) device(s)."
            [pscustomobject]@{ EmployeeId=$EmployeeId; AccountDisabled=$false; GroupsRemoved=$false; DevicesFlaggedForReturn=$assigned.Count; DryRun=$true }
        }
    } catch { Add-ToolkitAuditEntry -Action 'employee-offboarding' -Target $target -Result Failed -Details $_.Exception.Message; throw "Offboarding failed for '$target': $($_.Exception.Message)" }
}
