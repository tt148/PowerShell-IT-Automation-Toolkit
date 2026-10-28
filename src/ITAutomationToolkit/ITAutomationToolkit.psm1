Set-StrictMode -Version Latest
$script:ModuleRoot = Split-Path -Parent $PSCommandPath

. (Join-Path $script:ModuleRoot 'Private/Provider.ps1')
. (Join-Path $script:ModuleRoot 'Private/Audit.ps1')
. (Join-Path $script:ModuleRoot 'Public/Write-AuditLog.ps1')
. (Join-Path $script:ModuleRoot 'Public/New-EmployeeOnboarding.ps1')
. (Join-Path $script:ModuleRoot 'Public/Invoke-EmployeeTransfer.ps1')
. (Join-Path $script:ModuleRoot 'Public/Import-EmployeeBatch.ps1')
. (Join-Path $script:ModuleRoot 'Public/Copy-UserAccess.ps1')
. (Join-Path $script:ModuleRoot 'Public/Invoke-EmployeeOffboarding.ps1')
. (Join-Path $script:ModuleRoot 'Public/Get-UserAccessReview.ps1')
. (Join-Path $script:ModuleRoot 'Public/Get-DeviceInventory.ps1')
. (Join-Path $script:ModuleRoot 'Public/Get-DeviceHealthReport.ps1')
. (Join-Path $script:ModuleRoot 'Public/Test-PasswordPolicyCompliance.ps1')
. (Join-Path $script:ModuleRoot 'Public/Export-ToolkitReport.ps1')
. (Join-Path $script:ModuleRoot 'Public/Get-UserSupportSnapshot.ps1')
. (Join-Path $script:ModuleRoot 'Public/Get-AuditLog.ps1')


Export-ModuleMember -Function @(
    'New-EmployeeOnboarding', 'Invoke-EmployeeTransfer', 'Import-EmployeeBatch', 'Copy-UserAccess', 'Invoke-EmployeeOffboarding', 'Get-UserAccessReview',
    'Get-DeviceInventory', 'Get-DeviceHealthReport', 'Test-PasswordPolicyCompliance',
    'Export-ToolkitReport', 'Write-AuditLog', 'Get-UserSupportSnapshot', 'Get-AuditLog'
)
