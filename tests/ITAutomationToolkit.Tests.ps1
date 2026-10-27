BeforeAll {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $repoRoot 'src/ITAutomationToolkit/ITAutomationToolkit.psd1') -Force
    $script:OriginalData = $env:ITAT_DATA_PATH
    $script:OriginalReports = $env:ITAT_REPORTS_PATH
    $script:OriginalAudit = $env:ITAT_AUDIT_LOG_PATH
}

BeforeEach {
    $script:TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('itat-' + [guid]::NewGuid().ToString('N'))
    $script:TestData = Join-Path $script:TestRoot 'data'
    $script:TestReports = Join-Path $script:TestRoot 'reports'
    New-Item -ItemType Directory -Path $script:TestData -Force | Out-Null
    Copy-Item (Join-Path (Split-Path -Parent $PSScriptRoot) 'data/*') $script:TestData -Recurse -Force
    $env:ITAT_DATA_PATH = $script:TestData
    $env:ITAT_REPORTS_PATH = $script:TestReports
    $env:ITAT_AUDIT_LOG_PATH = Join-Path $script:TestReports 'audit.jsonl'
}

AfterEach { Remove-Item -LiteralPath $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue }
AfterAll {
    $env:ITAT_DATA_PATH = $script:OriginalData
    $env:ITAT_REPORTS_PATH = $script:OriginalReports
    $env:ITAT_AUDIT_LOG_PATH = $script:OriginalAudit
    Remove-Module ITAutomationToolkit -ErrorAction SilentlyContinue
}

Describe 'New-EmployeeOnboarding' {
    It 'creates an employee and checklist using fictional data' {
        $result = New-EmployeeOnboarding -EmployeeId EMP-999 -DisplayName 'Demo User 999' -Email demo.user999@example.invalid -Department Engineering
        $result.EmployeeId | Should -Be 'EMP-999'
        (Import-Csv (Join-Path $script:TestData 'employees.csv')).EmployeeId | Should -Contain 'EMP-999'
        $result.TemporaryPasswordPlaceholder | Should -Match 'DEMO-PLACEHOLDER'
        (Get-Content $env:ITAT_AUDIT_LOG_PATH -Raw) | Should -Match 'employee-onboarding'
    }
    It 'rejects a non-demo display name' { { New-EmployeeOnboarding -EmployeeId EMP-998 -DisplayName 'Sam Smith' -Email sam@example.invalid -Department Support } | Should -Throw }
    It 'does not change CSV data with WhatIf and logs dry run' {
        $before = (Get-Content (Join-Path $script:TestData 'employees.csv') -Raw)
        New-EmployeeOnboarding -EmployeeId EMP-997 -DisplayName 'Demo User 997' -Email demo.user997@example.invalid -Department Support -WhatIf | Out-Null
        (Get-Content (Join-Path $script:TestData 'employees.csv') -Raw) | Should -Be $before
        (Get-Content $env:ITAT_AUDIT_LOG_PATH -Raw) | Should -Match '"dryRun":true'
    }
}

Describe 'Invoke-EmployeeOffboarding' {
    It 'disables account and flags owned devices' {
        $result = Invoke-EmployeeOffboarding -EmployeeId EMP-102 -Confirm:$false
        $employee = Import-Csv (Join-Path $script:TestData 'employees.csv') | Where-Object EmployeeId -eq EMP-102
        $employee.Enabled | Should -Be 'false'
        $device = Import-Csv (Join-Path $script:TestData 'devices.csv') | Where-Object DeviceId -eq DEV-202
        $device.ReturnRequired | Should -Be 'true'
        $result.AccountDisabled | Should -BeTrue
    }
    It 'rejects an unknown employee' { { Invoke-EmployeeOffboarding -EmployeeId EMP-999 -Confirm:$false } | Should -Throw '*not found*' }
    It 'does not change CSV data with WhatIf and logs dry run' {
        $before = Get-Content (Join-Path $script:TestData 'employees.csv') -Raw
        Invoke-EmployeeOffboarding -EmployeeId EMP-102 -WhatIf | Out-Null
        (Get-Content (Join-Path $script:TestData 'employees.csv') -Raw) | Should -Be $before
        (Get-Content $env:ITAT_AUDIT_LOG_PATH -Raw) | Should -Match '"dryRun":true'
    }
}

Describe 'Get-UserAccessReview' {
    It 'flags stale, privileged and managerless accounts' {
        $result = @(Get-UserAccessReview -StaleAfterDays 90)
        ($result | Where-Object EmployeeId -eq EMP-103).ExcessPrivileges | Should -BeTrue
        ($result | Where-Object EmployeeId -eq EMP-103).MissingManager | Should -BeTrue
        ($result | Where-Object EmployeeId -eq EMP-102).StaleAccount | Should -BeTrue
    }
    It 'validates stale threshold' { { Get-UserAccessReview -StaleAfterDays 0 } | Should -Throw }
    It 'writes an audit entry' { Get-UserAccessReview | Out-Null; (Get-Content $env:ITAT_AUDIT_LOG_PATH -Raw) | Should -Match 'access-review' }
    It 'logs WhatIf without changing the simulated directory' { $before=Get-Content (Join-Path $script:TestData 'employees.csv') -Raw; Get-UserAccessReview -WhatIf | Out-Null; (Get-Content (Join-Path $script:TestData 'employees.csv') -Raw) | Should -Be $before; (Get-Content $env:ITAT_AUDIT_LOG_PATH -Raw) | Should -Match '"dryRun":true' }
}

Describe 'Get-DeviceInventory' {
    It 'returns inventory and filters by owner' { (Get-DeviceInventory -OwnerId EMP-101).DeviceId | Should -Be 'DEV-201' }
    It 'validates owner ID' { { Get-DeviceInventory -OwnerId BAD } | Should -Throw }
    It 'writes an audit entry' { Get-DeviceInventory | Out-Null; (Get-Content $env:ITAT_AUDIT_LOG_PATH -Raw) | Should -Match 'device-inventory' }
    It 'logs WhatIf without changing inventory' { $before=Get-Content (Join-Path $script:TestData 'devices.csv') -Raw; Get-DeviceInventory -WhatIf | Out-Null; (Get-Content (Join-Path $script:TestData 'devices.csv') -Raw) | Should -Be $before; (Get-Content $env:ITAT_AUDIT_LOG_PATH -Raw) | Should -Match '"dryRun":true' }
}

Describe 'Get-DeviceHealthReport' {
    It 'flags low disk and patch issues' { $row = @(Get-DeviceHealthReport | Where-Object DeviceId -eq DEV-202); $row.Flags | Should -Contain 'LowDiskSpace'; $row.Flags | Should -Contain 'PatchRequired' }
    It 'validates disk threshold' { { Get-DeviceHealthReport -DiskFreeThreshold 0 } | Should -Throw }
    It 'writes an audit entry' { Get-DeviceHealthReport | Out-Null; (Get-Content $env:ITAT_AUDIT_LOG_PATH -Raw) | Should -Match 'device-health-report' }
    It 'logs WhatIf without changing inventory' { $before=Get-Content (Join-Path $script:TestData 'devices.csv') -Raw; Get-DeviceHealthReport -WhatIf | Out-Null; (Get-Content (Join-Path $script:TestData 'devices.csv') -Raw) | Should -Be $before; (Get-Content $env:ITAT_AUDIT_LOG_PATH -Raw) | Should -Match '"dryRun":true' }
}

Describe 'Test-PasswordPolicyCompliance' {
    It 'flags accounts requiring reset and never-expiring passwords' { $row = @(Test-PasswordPolicyCompliance -EmployeeId EMP-103); $row.Flags | Should -Contain 'PasswordNeverExpires'; $row.Flags | Should -Contain 'ResetRequired'; $row.Flags | Should -Contain 'PasswordTooShortOrLengthMetadataMissing' }
    It 'validates employee ID' { { Test-PasswordPolicyCompliance -EmployeeId BAD } | Should -Throw }
    It 'writes an audit entry' { Test-PasswordPolicyCompliance | Out-Null; (Get-Content $env:ITAT_AUDIT_LOG_PATH -Raw) | Should -Match 'password-policy-review' }
    It 'logs WhatIf without changing account metadata' { $before=Get-Content (Join-Path $script:TestData 'employees.csv') -Raw; Test-PasswordPolicyCompliance -WhatIf | Out-Null; (Get-Content (Join-Path $script:TestData 'employees.csv') -Raw) | Should -Be $before; (Get-Content $env:ITAT_AUDIT_LOG_PATH -Raw) | Should -Match '"dryRun":true' }
}

Describe 'Export-ToolkitReport' {
    It 'exports both CSV and JSON' { $result = @([pscustomobject]@{Name='sample';Count=2}) | Export-ToolkitReport -Name sample-report -Format Both; $result.Files.Count | Should -Be 2; $result.Files | ForEach-Object { Test-Path $_ | Should -BeTrue } }
    It 'rejects unsafe report names' { { @([pscustomobject]@{A=1}) | Export-ToolkitReport -Name '../unsafe' } | Should -Throw }
    It 'does not create report files with WhatIf and logs dry run' { $result = @([pscustomobject]@{A=1}) | Export-ToolkitReport -Name dry-run -WhatIf; $result.DryRun | Should -BeTrue; (Get-Content $env:ITAT_AUDIT_LOG_PATH -Raw) | Should -Match '"dryRun":true' }
}

Describe 'Write-AuditLog' {
    It 'writes a JSON-lines event' { Write-AuditLog -Action test-event -Target EMP-101 -Result Info | Out-Null; $line=Get-Content $env:ITAT_AUDIT_LOG_PATH | Select-Object -Last 1; ($line | ConvertFrom-Json).target | Should -Be 'EMP-101' }
    It 'validates result values' { { Write-AuditLog -Action test-event -Target EMP-101 -Result Invalid } | Should -Throw }
    It 'logs WhatIf requests' { Write-AuditLog -Action test-event -Target EMP-101 -Result Info -WhatIf | Out-Null; (Get-Content $env:ITAT_AUDIT_LOG_PATH -Raw) | Should -Match '"dryRun":true' }
}
