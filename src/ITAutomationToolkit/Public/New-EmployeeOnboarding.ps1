function New-EmployeeOnboarding {
    <#
    .SYNOPSIS
    Creates a fictional employee record and onboarding checklist.
    .DESCRIPTION
    Uses CSV-backed simulated directory data. The password value is a non-secret placeholder; no usable password is generated.
    .PARAMETER EmployeeId
    Unique fictional employee identifier.
    .PARAMETER DisplayName
    Fictional display name, such as Demo User 104.
    .PARAMETER Email
    Reserved example.invalid address only.
    .PARAMETER Department
    Department used to select default groups.
    .PARAMETER ManagerId
    Optional fictional manager identifier.
    .EXAMPLE
    New-EmployeeOnboarding -EmployeeId EMP-104 -DisplayName 'Demo User 104' -Email 'demo.user104@example.invalid' -Department Engineering -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    param(
        [Parameter(Mandatory)][ValidatePattern('^EMP-[0-9]{3,6}$')][string]$EmployeeId,
        [Parameter(Mandatory)][ValidateLength(3,80)][ValidatePattern('^Demo [A-Za-z0-9 -]+$')][string]$DisplayName,
        [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9._%+-]+@example\.invalid$')][string]$Email,
        [Parameter(Mandatory)][ValidateSet('Engineering','Support','Finance','HumanResources','Operations')][string]$Department,
        [ValidatePattern('^(|EMP-[0-9]{3,6})$')][string]$ManagerId = ''
    )
    $target = $EmployeeId
    try {
        $employees = @(Import-ToolkitCsv -Name employees)
        if ($employees.EmployeeId -contains $EmployeeId) { throw "Employee ID '$EmployeeId' already exists." }
        $groups = @(Import-ToolkitCsv -Name groups)
        $groupNames = @(Get-ToolkitGroupNames -Department $Department -Groups $groups)
        $placeholder = "DEMO-PLACEHOLDER-$EmployeeId-RESET-REQUIRED!"
        if ($PSCmdlet.ShouldProcess($target, "Create fictional employee and assign groups: $($groupNames -join ', ')")) {
            $new = [pscustomobject][ordered]@{
                EmployeeId=$EmployeeId; DisplayName=$DisplayName; Email=$Email; Department=$Department
                ManagerId=$ManagerId; Enabled='true'; CreatedDate=(Get-Date).ToString('yyyy-MM-dd')
                LastSignInDate=''; PasswordLastSetDate=''; PasswordNeverExpires='false'; PasswordResetRequired='true'; PasswordLengthMetadata='0'
                Groups=($groupNames -join ';')
            }
            Export-ToolkitCsv -Name employees -Rows (@($employees) + @($new))
            Add-ToolkitAuditEntry -Action 'employee-onboarding' -Target $target -Result Success -Details "Created fictional account; groups=$($groupNames -join ', '); password placeholder only."
            Write-Verbose "Created simulated employee $EmployeeId."
            [pscustomobject]@{ EmployeeId=$EmployeeId; DisplayName=$DisplayName; Department=$Department; Groups=$groupNames; TemporaryPasswordPlaceholder=$placeholder; Checklist=@('Verify manager and department','Provision account through approved identity provider','Set a real temporary credential out-of-band','Verify MFA enrollment','Issue assigned device','Confirm first sign-in') }
        } else {
            Add-ToolkitAuditEntry -Action 'employee-onboarding' -Target $target -Result DryRun -Details "Would create account and assign groups: $($groupNames -join ', ')"
            [pscustomobject]@{ EmployeeId=$EmployeeId; DisplayName=$DisplayName; Department=$Department; Groups=$groupNames; TemporaryPasswordPlaceholder=$placeholder; Checklist=@('DRY RUN: no directory changes made','Verify manager and department','Provision account through approved identity provider','Set a real temporary credential out-of-band') }
        }
    } catch {
        Add-ToolkitAuditEntry -Action 'employee-onboarding' -Target $target -Result Failed -Details $_.Exception.Message
        throw "Onboarding failed for '$target': $($_.Exception.Message)"
    }
}
