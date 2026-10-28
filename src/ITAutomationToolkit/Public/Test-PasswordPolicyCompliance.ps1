function Test-PasswordPolicyCompliance {
    <#
    .SYNOPSIS
    Checks fictional account password metadata against password_policy.json.
    .DESCRIPTION
    Does not inspect, store or generate real passwords. It checks metadata such as password age and reset flags.
    .PARAMETER EmployeeId
    Optional fictional employee ID to evaluate.
    .EXAMPLE
    Test-PasswordPolicyCompliance
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Low')]
    param([ValidatePattern('^EMP-[0-9]{3,6}$')][string]$EmployeeId)
    if (-not $PSCmdlet.ShouldProcess('simulated directory','Evaluate password metadata')) { Add-ToolkitAuditEntry -Action 'password-policy-review' -Target 'accounts' -Result DryRun -Details 'Read-only policy preview.' }
    $policy=Get-ToolkitPasswordPolicy
    $employees=@(Import-ToolkitCsv -Name employees)
    if ($EmployeeId) { $employees=@($employees | Where-Object EmployeeId -eq $EmployeeId) }
    foreach ($user in $employees) {
        $flags=@(); $age=$null
        if ($user.PasswordNeverExpires -eq 'true' -and -not $policy.allowNeverExpires) {$flags+='PasswordNeverExpires'}
        $lengthMetadata=0; [void][int]::TryParse([string]$user.PasswordLengthMetadata,[ref]$lengthMetadata)
        $lengthCompliant=($lengthMetadata -ge [int]$policy.minimumLength)
        if (-not $lengthCompliant) {$flags+='PasswordTooShortOrLengthMetadataMissing'}
        if ($user.PasswordResetRequired -eq 'true') {$flags+='ResetRequired'}
        $setDate = ConvertTo-ToolkitDateTime -DateText $user.PasswordLastSetDate
        if ([string]::IsNullOrWhiteSpace($user.PasswordLastSetDate)) {$flags+='PasswordSetDateMissing'}
        elseif ($null -eq $setDate) {$flags+='PasswordSetDateInvalid'}
        else {
            $age=((Get-Date) - $setDate).Days
            if ($age -gt [int]$policy.maxPasswordAgeDays) {$flags+='PasswordExpired'}
        }
        [pscustomobject]@{ EmployeeId=$user.EmployeeId; DisplayName=$user.DisplayName; PasswordAgeDays=$age; MaxPasswordAgeDays=[int]$policy.maxPasswordAgeDays; MinimumLength=[int]$policy.minimumLength; PasswordLengthMetadata=$lengthMetadata; PasswordLengthCompliant=$lengthCompliant; PasswordNeverExpires=($user.PasswordNeverExpires -eq 'true'); Compliant=($flags.Count -eq 0); Flags=$flags }
    }
    Add-ToolkitAuditEntry -Action 'password-policy-review' -Target 'accounts' -Result Info -Details "Evaluated $($employees.Count) fictional account(s)."
}
