function Invoke-EmployeeTransfer {
    <#
    .SYNOPSIS
    Moves a fictional employee to another department.
    .DESCRIPTION
    Updates the CSV-backed simulated directory, reconciles department groups, and flags owned devices for review.
    .PARAMETER EmployeeId
    Fictional employee identifier.
    .PARAMETER NewDepartment
    Valid destination department.
    .PARAMETER NewManagerId
    Optional fictional manager identifier.
    .EXAMPLE
    Invoke-EmployeeTransfer -EmployeeId EMP-101 -NewDepartment Finance -NewManagerId EMP-104 -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    param(
        [Parameter(Mandatory)][ValidatePattern('^EMP-[0-9]{3,6}$')][string]$EmployeeId,
        [Parameter(Mandatory)][ValidateLength(2,40)][string]$NewDepartment,
        [ValidatePattern('^(|EMP-[0-9]{3,6})$')][string]$NewManagerId = ''
    )
    try {
        $employees = @(Import-ToolkitCsv -Name employees)
        $employee = $employees | Where-Object EmployeeId -eq $EmployeeId
        if ($null -eq $employee) { throw "Employee '$EmployeeId' was not found." }
        if (-not (Test-ToolkitDepartment -Department $NewDepartment)) { throw "Department '$NewDepartment' is not valid." }
        if ($NewManagerId -and ($employees.EmployeeId -notcontains $NewManagerId)) { throw "Manager '$NewManagerId' was not found." }

        $oldDepartment = [string]$employee.Department
        $oldGroups = @(Get-ToolkitDepartmentGroups -Department $oldDepartment)
        $newGroups = @(Get-ToolkitDepartmentGroups -Department $NewDepartment)
        $commonGroups = @($oldGroups | Where-Object { $newGroups -contains $_ })
        $removeGroups = @($oldGroups | Where-Object { $newGroups -notcontains $_ })
        $addGroups = @($newGroups | Where-Object { $oldGroups -notcontains $_ })
        $existingGroups = @([string]$employee.Groups -split ';' | Where-Object { $_ })
        $resultGroups = @($existingGroups | Where-Object { $removeGroups -notcontains $_ }) + $addGroups | Select-Object -Unique
        $devices = @(Import-ToolkitCsv -Name devices)
        $ownedDevices = @($devices | Where-Object OwnerId -eq $EmployeeId)

        $details = "oldDepartment=$oldDepartment; newDepartment=$NewDepartment; removed=$($removeGroups -join ','); added=$($addGroups -join ','); common=$($commonGroups -join ',')"
        if ($PSCmdlet.ShouldProcess($EmployeeId, "Transfer employee from $oldDepartment to $NewDepartment")) {
            foreach ($row in $employees) {
                if ($row.EmployeeId -eq $EmployeeId) {
                    $row.Department = $NewDepartment
                    $row.Groups = $resultGroups -join ';'
                    if ($PSBoundParameters.ContainsKey('NewManagerId')) {
                        $row.ManagerId = $NewManagerId
                        $row.OwnerId = $NewManagerId
                    }
                }
            }
            Export-ToolkitCsv -Name employees -Rows $employees
            foreach ($device in $devices) {
                if ($device.OwnerId -eq $EmployeeId) { $device.ReturnRequired = 'true' }
            }
            if ($ownedDevices.Count -gt 0) { Export-ToolkitCsv -Name devices -Rows $devices }
            Add-ToolkitAuditEntry -Action 'employee-transfer' -Target $EmployeeId -Result Success -Details $details
            [pscustomobject]@{
                EmployeeId=$EmployeeId; OldDepartment=$oldDepartment; NewDepartment=$NewDepartment
                ManagerId=$(if ($PSBoundParameters.ContainsKey('NewManagerId')) { $NewManagerId } else { $employee.ManagerId }); RemovedGroups=$removeGroups; AddedGroups=$addGroups
                CommonGroups=$commonGroups; Groups=$resultGroups; ReviewRequired=($ownedDevices.Count -gt 0)
            }
        } else {
            Add-ToolkitAuditEntry -Action 'employee-transfer' -Target $EmployeeId -Result DryRun -Details "Would transfer employee; $details"
            [pscustomobject]@{
                EmployeeId=$EmployeeId; OldDepartment=$oldDepartment; NewDepartment=$NewDepartment
                RemovedGroups=$removeGroups; AddedGroups=$addGroups; CommonGroups=$commonGroups
                Groups=$resultGroups; ReviewRequired=($ownedDevices.Count -gt 0); DryRun=$true
            }
        }
    } catch {
        Add-ToolkitAuditEntry -Action 'employee-transfer' -Target $EmployeeId -Result Failed -Details $_.Exception.Message
        throw "Employee transfer failed for '$EmployeeId': $($_.Exception.Message)"
    }
}
