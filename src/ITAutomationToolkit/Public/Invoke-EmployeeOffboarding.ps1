function Invoke-EmployeeOffboarding {
    <#
    .SYNOPSIS
    Disables a fictional employee, removes group memberships and flags assigned devices for return.
    .DESCRIPTION
    All changes affect only the local CSV-backed simulated directory.
    .PARAMETER EmployeeId
    Existing fictional employee identifier.
    .PARAMETER RetentionDays
    Number of days until the simulated account expiry.
    .PARAMETER TicketId
    Optional helpdesk ticket identifier.
    .EXAMPLE
    Invoke-EmployeeOffboarding -EmployeeId EMP-103 -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    param(
        [Parameter(Mandatory)][ValidatePattern('^EMP-[0-9]{3,6}$')][string]$EmployeeId,
        [ValidateRange(1,3650)][int]$RetentionDays = 90,
        [ValidatePattern('^$|^[A-Za-z]{1,10}-[0-9]{1,10}$')][string]$TicketId = ''
    )
    $target=$EmployeeId
    try {
        $employees=@(Import-ToolkitCsv -Name employees)
        $employee=@($employees | Where-Object EmployeeId -eq $EmployeeId | Select-Object -First 1)
        if (-not $employee) { throw "Employee '$EmployeeId' was not found." }
        $devices=@(Import-ToolkitCsv -Name devices)
        $assigned=@($devices | Where-Object OwnerId -eq $EmployeeId)
        $manager=@($employees | Where-Object EmployeeId -eq $employee.ManagerId | Select-Object -First 1)
        $managerName=if ($manager) { [string]$manager.DisplayName } else { '' }
        $groups=@([string]$employee.Groups -split ';' | Where-Object { $_ })
        $expiry=(Get-Date).AddDays($RetentionDays).ToString('yyyy-MM-dd')
        if ($PSCmdlet.ShouldProcess($target, "Disable account, expire it after $RetentionDays days, remove groups and flag devices for return")) {
            $paths=Get-ToolkitPath
            $stamp=(Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZfff')
            $evidenceName="offboarding-$EmployeeId-$stamp.json"
            $evidenceFile=Join-Path $paths.Reports $evidenceName
            $evidence=[ordered]@{
                timestamp=(Get-Date).ToUniversalTime().ToString('o')
                ticketId=$TicketId
                account=[ordered]@{ EmployeeId=$employee.EmployeeId; DisplayName=$employee.DisplayName; Email=$employee.Email; Department=$employee.Department; ManagerId=$employee.ManagerId; ManagerName=$managerName; Enabled=$employee.Enabled; Groups=$groups }
                devices=@($assigned | ForEach-Object { [ordered]@{ DeviceId=$_.DeviceId; DeviceName=$_.DeviceName; OperatingSystem=$_.OperatingSystem; ReturnRequired=$_.ReturnRequired } })
            }
            if (-not (Test-Path -LiteralPath $paths.Reports)) { New-Item -ItemType Directory -Path $paths.Reports -Force | Out-Null }
            $evidence | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $evidenceFile -Encoding UTF8 -ErrorAction Stop

            foreach ($row in $employees) {
                if ($row.EmployeeId -eq $EmployeeId) {
                    foreach ($columnName in @('ScheduledExpiryDate','MailboxForwardManagerId','MailboxForwarding')) {
                        if ($null -eq $row.PSObject.Properties[$columnName]) { $row | Add-Member -NotePropertyName $columnName -NotePropertyValue '' }
                    }
                    $row.Enabled='false'; $row.Groups=''; $row.PasswordResetRequired='true'; $row.ScheduledExpiryDate=$expiry
                    if ($manager) { $row.MailboxForwardManagerId=[string]$manager.EmployeeId; $row.MailboxForwarding='true' } else { $row.MailboxForwardManagerId=''; $row.MailboxForwarding='false' }
                }
            }
            foreach ($device in $devices) { if ($device.OwnerId -eq $EmployeeId) { $device.ReturnRequired='true' } }
            Export-ToolkitCsv -Name employees -Rows $employees
            Export-ToolkitCsv -Name devices -Rows $devices
            Add-ToolkitAuditEntry -Action 'employee-offboarding' -Target $target -Result Success -Details "Account disabled; groups removed; devices flagged=$($assigned.Count); scheduled expiry=$expiry; evidence=$evidenceFile; mailbox forwarding=$($manager.Count -gt 0)." -TicketId $TicketId
            Write-Verbose "Offboarded simulated employee $EmployeeId."
            $checklist=[pscustomobject]@{ DevicesToReturn=@($assigned | ForEach-Object { $_.DeviceId }); AccessToReview=@($groups); LicencesToReclaim=@('Mailbox','Assigned software licences'); TicketToClose=$TicketId }
            [pscustomobject]@{ EmployeeId=$EmployeeId; AccountDisabled=$true; GroupsRemoved=$true; ScheduledExpiryDate=$expiry; MailboxForwarding=($manager.Count -gt 0); MailboxForwardManagerId=$(if ($manager) { [string]$manager.EmployeeId } else { '' }); DevicesFlaggedForReturn=$assigned.Count; EvidenceFile=$evidenceFile; FollowUp=$checklist; DryRun=$false }
        } else {
            Add-ToolkitAuditEntry -Action 'employee-offboarding' -Target $target -Result DryRun -Details "Would disable account, remove groups, expire after $RetentionDays days and flag $($assigned.Count) device(s); no evidence file written." -TicketId $TicketId
            $checklist=[pscustomobject]@{ DevicesToReturn=@($assigned | ForEach-Object { $_.DeviceId }); AccessToReview=@($groups); LicencesToReclaim=@('Mailbox','Assigned software licences'); TicketToClose=$TicketId }
            [pscustomobject]@{ EmployeeId=$EmployeeId; AccountDisabled=$false; GroupsRemoved=$false; ScheduledExpiryDate=$expiry; MailboxForwarding=($manager.Count -gt 0); DevicesFlaggedForReturn=$assigned.Count; EvidenceFile=''; FollowUp=$checklist; DryRun=$true }
        }
    } catch { Add-ToolkitAuditEntry -Action 'employee-offboarding' -Target $target -Result Failed -Details $_.Exception.Message -TicketId $TicketId; throw "Offboarding failed for '$target': $($_.Exception.Message)" }
}
