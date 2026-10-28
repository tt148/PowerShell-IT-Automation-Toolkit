function Get-UserSupportSnapshot {
    <#
    .SYNOPSIS
    Builds a fictional support snapshot for one employee.
    .DESCRIPTION
    Combines identity, access review, group, and device health data for helpdesk ticket triage.
    .PARAMETER EmployeeId
    Fictional employee identifier.
    .PARAMETER Format
    Returns an object or a ticket-friendly text summary.
    .PARAMETER TicketId
    Optional ticket identifier included in the audit record.
    .EXAMPLE
    Get-UserSupportSnapshot -EmployeeId EMP-101 -Format Text -TicketId HD-1234
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Low')]
    param(
        [Parameter(Mandatory)][ValidatePattern('^EMP-[0-9]{3,6}$')][string]$EmployeeId,
        [ValidateSet('Object','Text')][string]$Format = 'Object',
        [ValidatePattern('^$|^[A-Za-z]{1,10}-[0-9]{1,10}$')][string]$TicketId = ''
    )
    try {
        $employees = @(Import-ToolkitCsv -Name employees)
        $employee = $employees | Where-Object EmployeeId -eq $EmployeeId | Select-Object -First 1
        if ($null -eq $employee) { throw "Employee '$EmployeeId' was not found." }
        $groups = @([string]$employee.Groups -split ';' | Where-Object { $_ })
        $privilegedGroups = @(Import-ToolkitCsv -Name groups | Where-Object { $_.Privileged -eq 'true' } | ForEach-Object GroupName)
        $privileged = @($groups | Where-Object { ($privilegedGroups -contains $_) -or ($_ -match 'Admin|Privileged|Global') })
        $stale = Test-ToolkitStaleDate -DateText $employee.LastSignInDate -Days 90
        $missingManager = [string]::IsNullOrWhiteSpace([string]$employee.ManagerId)
        $accessFlags = @()
        if ($stale) { $accessFlags += 'StaleAccount' }
        if ($missingManager) { $accessFlags += 'MissingManager' }
        if ($privileged.Count -gt 0) { $accessFlags += 'ReviewPrivilegedGroup' }

        $devices = @(Get-DeviceHealthReport | Where-Object OwnerId -eq $EmployeeId)
        $manager = $employees | Where-Object EmployeeId -eq $employee.ManagerId | Select-Object -First 1
        $managerName = if ($manager) { [string]$manager.DisplayName } else { '' }
        $snapshot = [pscustomobject][ordered]@{
            EmployeeId=$employee.EmployeeId; DisplayName=$employee.DisplayName; Email=$employee.Email
            Department=$employee.Department; ManagerId=$employee.ManagerId; ManagerName=$managerName
            AccountStatus=if ($employee.Enabled -eq 'true') { 'Enabled' } else { 'Disabled' }
            Groups=$groups; Devices=$devices; LastSeen=$employee.LastSignInDate
            StaleAccount=$stale; MissingManager=$missingManager; PrivilegedGroups=$privileged; AccessReviewFlags=$accessFlags
        }

        if ($PSCmdlet.ShouldProcess($EmployeeId, "Build support snapshot for ticket $TicketId")) {
            Add-ToolkitAuditEntry -Action 'support-snapshot' -Target $EmployeeId -Result Success -Details "Generated support snapshot; flags=$($accessFlags -join ', ')" -TicketId $TicketId
            if ($Format -eq 'Text') {
                "User Support Snapshot`nEmployee: $($snapshot.DisplayName) [$EmployeeId]`nEmail: $($snapshot.Email)`nDepartment: $($snapshot.Department)`nManager: $(if ($managerName) { "$managerName [$($snapshot.ManagerId)]" } else { 'Not assigned' })`nAccount status: $($snapshot.AccountStatus)`nGroups: $(if ($groups.Count) { $groups -join ', ' } else { 'None' })`nDevices: $(if ($devices.Count) { (($devices | ForEach-Object { "$($_.DeviceName) [$($_.DeviceId)] flags=$($_.Flags -join ',')" }) -join '; ') } else { 'None' })`nLast sign-in: $(if ($snapshot.LastSeen) { $snapshot.LastSeen } else { 'Never/unknown' })`nAccess flags: $(if ($accessFlags.Count) { $accessFlags -join ', ' } else { 'None' })`nTicket: $(if ($TicketId) { $TicketId } else { 'Not specified' })"
            } else { $snapshot }
        } else {
            Add-ToolkitAuditEntry -Action 'support-snapshot' -Target $EmployeeId -Result DryRun -Details "Would build support snapshot; flags=$($accessFlags -join ', ')" -TicketId $TicketId
            if ($Format -eq 'Text') { "DRY RUN`n$($snapshot.DisplayName) [$EmployeeId]`nNo directory changes made.`nTicket: $(if ($TicketId) { $TicketId } else { 'Not specified' })" } else { $snapshot | Add-Member -NotePropertyName DryRun -NotePropertyValue $true -PassThru }
        }
    } catch {
        Add-ToolkitAuditEntry -Action 'support-snapshot' -Target $EmployeeId -Result Failed -Details $_.Exception.Message -TicketId $TicketId
        throw "Support snapshot failed for '$EmployeeId': $($_.Exception.Message)"
    }
}
