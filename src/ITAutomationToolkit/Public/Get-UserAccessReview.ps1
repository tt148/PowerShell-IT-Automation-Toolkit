function Get-UserAccessReview {
    <#
    .SYNOPSIS
    Reviews fictional employee accounts, group memberships and access hygiene.
    .DESCRIPTION
    Flags stale sign-ins, broad access, and missing manager information.
    .PARAMETER StaleAfterDays
    Sign-in age after which an account is flagged stale.
    .EXAMPLE
    Get-UserAccessReview -StaleAfterDays 90
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Low')]
    param([ValidateRange(1,3650)][int]$StaleAfterDays=90)
    if (-not $PSCmdlet.ShouldProcess('simulated directory','Read users for access review')) { Add-ToolkitAuditEntry -Action 'access-review' -Target 'all-users' -Result DryRun -Details 'Read-only access review preview.' }
    $employees=@(Import-ToolkitCsv -Name employees)
    $privilegedGroups=@(Import-ToolkitCsv -Name groups | Where-Object { $_.Privileged -eq 'true' } | ForEach-Object { $_.GroupName })
    foreach ($user in $employees) {
        $memberships=@(); if ($user.Groups) { $memberships=@($user.Groups -split ';' | Where-Object { $_ }) }
        $stale=Test-ToolkitStaleDate -DateText $user.LastSignInDate -Days $StaleAfterDays
        $excess=(@($memberships | Where-Object { ($privilegedGroups -contains $_) -or ($_ -match 'Admin|Privileged|Global') }).Count -gt 0)
        $flags=@(); if ($stale) {$flags+='StaleAccount'}; if ($excess) {$flags+='ReviewPrivilegedGroup'}; if ([string]::IsNullOrWhiteSpace($user.ManagerId)) {$flags+='MissingManager'}
        if ([string]::IsNullOrWhiteSpace($user.OwnerId)) {$flags+='MissingOwner'}
        [pscustomobject]@{ EmployeeId=$user.EmployeeId; DisplayName=$user.DisplayName; Department=$user.Department; Enabled=($user.Enabled -eq 'true'); Groups=$memberships; LastSignInDate=$user.LastSignInDate; StaleAccount=$stale; ExcessPrivileges=$excess; MissingManager=([string]::IsNullOrWhiteSpace($user.ManagerId)); MissingOwner=([string]::IsNullOrWhiteSpace($user.OwnerId)); Flags=$flags }
    }
    Add-ToolkitAuditEntry -Action 'access-review' -Target 'all-users' -Result Info -Details "Reviewed $($employees.Count) fictional account(s); stale threshold=$StaleAfterDays days."
}
