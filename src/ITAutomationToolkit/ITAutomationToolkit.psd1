@{
    RootModule        = 'ITAutomationToolkit.psm1'
    ModuleVersion     = '1.0.1'
    GUID              = '6d5fca62-0c45-4d90-9f50-6d8a2b8c17a1'
    Author            = 'HelpDesk Pro Portfolio Project'
    CompanyName       = 'Fictional Example Company'
    Copyright         = '(c) 2026. MIT License.'
    Description       = 'Safe, fictional-data IT operations automation examples for helpdesk and sysadmin portfolios.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('New-EmployeeOnboarding','Invoke-EmployeeTransfer','Import-EmployeeBatch','Copy-UserAccess','Invoke-EmployeeOffboarding','Get-UserAccessReview','Get-DeviceInventory','Get-DeviceHealthReport','Test-PasswordPolicyCompliance','Export-ToolkitReport','Write-AuditLog','Get-UserSupportSnapshot','Get-AuditLog')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{ PSData = @{ Tags = @('ITSupport','Automation','Helpdesk','SysAdmin','PowerShell'); LicenseUri = 'https://opensource.org/license/mit'; ProjectUri = 'https://github.com/YOUR_USERNAME/PowerShell-IT-Automation-Toolkit' } }
}
