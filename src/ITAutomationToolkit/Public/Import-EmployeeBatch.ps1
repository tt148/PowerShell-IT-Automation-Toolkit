function Import-EmployeeBatch {
    <#
    .SYNOPSIS
    Onboards multiple fictional employees from a CSV file.
    .DESCRIPTION
    Validates each row independently and returns a summary. No real identity provider is called.
    .PARAMETER CsvPath
    Path to a CSV containing EmployeeId, DisplayName, Email, Department, and optional ManagerId columns.
    .EXAMPLE
    Import-EmployeeBatch -CsvPath ./data/sample-new-hires.csv -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    param(
        [Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][string]$CsvPath,
        [ValidatePattern('^$|^[A-Za-z]{1,10}-[0-9]{1,10}$')][string]$TicketId = ''
    )
    $succeeded = @()
    $failed = @()

    try { $rows = @(Import-Csv -LiteralPath $CsvPath -ErrorAction Stop) }
    catch { throw "Unable to read batch CSV '$CsvPath': $($_.Exception.Message)" }
    $required = @('EmployeeId','DisplayName','Email','Department')
    foreach ($name in $required) {
        if (@($rows | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name) -notcontains $name) {
            throw "Batch CSV is missing required column '$name'."
        }
    }

    $employees = @(Import-ToolkitCsv -Name employees)
    $pending = @($employees)

    foreach ($row in $rows) {
        $employeeId = [string]$row.EmployeeId
        try {
            if ($employeeId -notmatch '^EMP-[0-9]{3,6}$') { throw "EmployeeId '$employeeId' is invalid." }
            if ([string]$row.DisplayName -notmatch '^Demo [A-Za-z0-9 -]+$') { throw "DisplayName must be a fictional Demo name." }
            if ([string]$row.Email -notmatch '^[A-Za-z0-9._%+-]+@example\.invalid$') { throw "Email must use the example.invalid domain." }
            if (-not (Test-ToolkitDepartment -Department ([string]$row.Department))) { throw "Department '$($row.Department)' is not valid." }
            if ($pending.EmployeeId -contains $employeeId) { throw "Employee ID '$employeeId' already exists." }
            if ($pending.Email -contains ([string]$row.Email)) { throw "Email '$($row.Email)' is already assigned." }
            $managerId = if ($row.PSObject.Properties['ManagerId']) { [string]$row.ManagerId } else { '' }
            if ($managerId -and ($pending.EmployeeId -notcontains $managerId)) { throw "Manager '$managerId' was not found." }
            $groupNames = @(Get-ToolkitDepartmentGroup -Department ([string]$row.Department))

            if ($PSCmdlet.ShouldProcess($employeeId, "Create batch employee and assign groups: $($groupNames -join ', ')")) {
                $newEmployee = [pscustomobject][ordered]@{
                    EmployeeId=$employeeId; DisplayName=[string]$row.DisplayName; Email=[string]$row.Email
                    Department=[string]$row.Department; ManagerId=$managerId; OwnerId=$managerId; Enabled='true'
                    CreatedDate=(Get-Date).ToString('yyyy-MM-dd'); LastSignInDate=''; PasswordLastSetDate=''
                    PasswordNeverExpires='false'; PasswordResetRequired='true'; PasswordLengthMetadata='0'; Groups=($groupNames -join ';')
                }
                $pending += $newEmployee
                $succeeded += [pscustomobject]@{ EmployeeId=$employeeId; Department=[string]$row.Department; Groups=$groupNames }
                Add-ToolkitAuditEntry -Action 'employee-batch-onboarding' -Target $employeeId -Result Success -Details "Department=$($row.Department); groups=$($groupNames -join ', ')" -TicketId $TicketId
            } else {
                $succeeded += [pscustomobject]@{ EmployeeId=$employeeId; Department=[string]$row.Department; Groups=$groupNames; DryRun=$true }
                Add-ToolkitAuditEntry -Action 'employee-batch-onboarding' -Target $employeeId -Result DryRun -Details "Would onboard employee; Department=$($row.Department); groups=$($groupNames -join ', ')" -TicketId $TicketId
            }
        } catch {
            $failed += [pscustomobject]@{ EmployeeId=$employeeId; Reason=$_.Exception.Message }
            Add-ToolkitAuditEntry -Action 'employee-batch-onboarding' -Target $(if ($employeeId) { $employeeId } else { 'batch-row' }) -Result Failed -Details $_.Exception.Message -TicketId $TicketId
        }
    }

    if ($PSCmdlet.ShouldProcess($CsvPath, "Save $($succeeded.Count) successful batch employee rows")) {
        $dryRunRows = @($succeeded | Where-Object { $_.PSObject.Properties['DryRun'] -and $_.DryRun })
        if ($succeeded.Count -gt $dryRunRows.Count) {
            $pendingForExport = @($pending | Select-Object EmployeeId,DisplayName,Email,Department,ManagerId,OwnerId,Enabled,CreatedDate,LastSignInDate,PasswordLastSetDate,PasswordNeverExpires,PasswordResetRequired,PasswordLengthMetadata,Groups)
            Export-ToolkitCsv -Name employees -Rows $pendingForExport
        }
    }

    [pscustomobject]@{ Succeeded=$succeeded.Count; Failed=$failed.Count; Reasons=$failed }
}
