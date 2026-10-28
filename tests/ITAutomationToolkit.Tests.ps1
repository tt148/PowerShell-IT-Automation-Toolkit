Describe 'ITAutomationToolkit' {
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
    It 'rejects an unknown manager' { { New-EmployeeOnboarding -EmployeeId EMP-996 -DisplayName 'Demo User 996' -Email demo.user996@example.invalid -Department Support -ManagerId EMP-555 -Confirm:$false } | Should -Throw '*not found*' }
    It 'rejects a duplicate email address' { { New-EmployeeOnboarding -EmployeeId EMP-995 -DisplayName 'Demo User 995' -Email demo.user101@example.invalid -Department Support -Confirm:$false } | Should -Throw '*already assigned*' }
}

Describe 'Invoke-EmployeeOffboarding' {
    It 'disables account and flags owned devices' {
        $result = Invoke-EmployeeOffboarding -EmployeeId EMP-102 -Confirm:$false
        $employee = Import-Csv (Join-Path $script:TestData 'employees.csv') | Where-Object EmployeeId -eq EMP-102
        $employee.Enabled | Should -Be 'false'
        $device = Import-Csv (Join-Path $script:TestData 'devices.csv') | Where-Object DeviceId -eq DEV-202
        $device.ReturnRequired | Should -Be 'true'
        $result.AccountDisabled | Should -BeTrue
        $device.OwnerId | Should -Be 'EMP-102'
        (Get-Content $env:ITAT_AUDIT_LOG_PATH -Raw) | Should -Match 'employee-offboarding'
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
        ($result | Where-Object EmployeeId -eq EMP-103).MissingOwner | Should -BeTrue
        ($result | Where-Object EmployeeId -eq EMP-102).StaleAccount | Should -BeTrue
    }
    It 'treats groups marked Privileged in groups.csv as elevated' {
        $groupFile = Join-Path $script:TestData 'groups.csv'
        (Get-Content $groupFile -Raw) -replace 'Source-Control,Engineering,Source control access,false','Source-Control,Engineering,Source control access,true' | Set-Content $groupFile
        ($(Get-UserAccessReview) | Where-Object EmployeeId -eq EMP-101).ExcessPrivileges | Should -BeTrue
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
    It 'exports both CSV and JSON' { $result = @([pscustomobject]@{Name='sample';Count=2}) | Export-ToolkitReport -Name sample-report -Format Both; $result.Files.Count | Should -Be 2; $result.Files | ForEach-Object { Test-Path $_ | Should -BeTrue }; (Get-Content $env:ITAT_AUDIT_LOG_PATH -Raw) | Should -Match 'report-export' }
    It 'flattens array properties in CSV output' {
        $result = Get-UserAccessReview | Export-ToolkitReport -Name flatten-check -Format CSV
        $csv = Get-Content $result.Files[0] -Raw
        $csv | Should -Not -Match 'System.Object'
        $csv | Should -Match 'Engineering-Standard;Source-Control'
    }
    It 'rejects unsafe report names' { { @([pscustomobject]@{A=1}) | Export-ToolkitReport -Name '../unsafe' } | Should -Throw }
    It 'does not create report files with WhatIf and logs dry run' { $result = @([pscustomobject]@{A=1}) | Export-ToolkitReport -Name dry-run -WhatIf; $result.DryRun | Should -BeTrue; (Get-Content $env:ITAT_AUDIT_LOG_PATH -Raw) | Should -Match '"dryRun":true' }
}

Describe 'Write-AuditLog' {
    It 'writes a JSON-lines event' { Write-AuditLog -Action test-event -Target EMP-101 -Result Info | Out-Null; $line=Get-Content $env:ITAT_AUDIT_LOG_PATH | Select-Object -Last 1; ($line | ConvertFrom-Json).target | Should -Be 'EMP-101' }
    It 'validates result values' { { Write-AuditLog -Action test-event -Target EMP-101 -Result Invalid } | Should -Throw }
    It 'logs WhatIf requests' { Write-AuditLog -Action test-event -Target EMP-101 -Result Info -WhatIf | Out-Null; (Get-Content $env:ITAT_AUDIT_LOG_PATH -Raw) | Should -Match '"dryRun":true' }
}

Describe 'Invoke-EmployeeTransfer' {
    It 'moves departments, reconciles groups, and writes an audit record' {
        $result = Invoke-EmployeeTransfer -EmployeeId EMP-101 -NewDepartment Finance -NewManagerId EMP-104 -Confirm:$false
        $employee = Import-Csv (Join-Path $script:TestData 'employees.csv') | Where-Object EmployeeId -eq EMP-101
        $employee.Department | Should -Be 'Finance'
        $employee.Groups | Should -Match 'Finance-Standard'
        $result.RemovedGroups | Should -Contain 'Engineering-Standard'
        (Get-Content $env:ITAT_AUDIT_LOG_PATH -Raw) | Should -Match 'employee-transfer'
        (Get-Content $env:ITAT_AUDIT_LOG_PATH -Raw) | Should -Match 'oldDepartment=Engineering'
        (Get-Content $env:ITAT_AUDIT_LOG_PATH -Raw) | Should -Match 'newDepartment=Finance'
    }
    It 'rejects unknown employees and invalid departments' {
        { Invoke-EmployeeTransfer -EmployeeId EMP-999 -NewDepartment Finance -Confirm:$false } | Should -Throw '*not found*'
        { Invoke-EmployeeTransfer -EmployeeId EMP-101 -NewDepartment Unknown -Confirm:$false } | Should -Throw '*not valid*'
    }
    It 'does not change CSV data with WhatIf and logs dry run' {
        $before = Get-Content (Join-Path $script:TestData 'employees.csv') -Raw
        Invoke-EmployeeTransfer -EmployeeId EMP-101 -NewDepartment Finance -WhatIf | Out-Null
        (Get-Content (Join-Path $script:TestData 'employees.csv') -Raw) | Should -Be $before
        (Get-Content $env:ITAT_AUDIT_LOG_PATH -Raw) | Should -Match '"dryRun":true'
    }
}

Describe 'Import-EmployeeBatch' {
    It 'onboards valid rows and reports validation failures' {
        $result = Import-EmployeeBatch -CsvPath (Join-Path (Split-Path -Parent $PSScriptRoot) 'data/sample-new-hires.csv') -Confirm:$false
        $result.Succeeded | Should -Be 3
        $result.Failed | Should -Be 1
        $result.Reasons[0].Reason | Should -Match 'invalid|not valid'
        (Import-Csv (Join-Path $script:TestData 'employees.csv')).EmployeeId | Should -Contain 'EMP-201'
        (Get-Content $env:ITAT_AUDIT_LOG_PATH -Raw) | Should -Match 'employee-batch-onboarding'
    }
    It 'does not change data with WhatIf and logs dry-run rows' {
        $before = Get-Content (Join-Path $script:TestData 'employees.csv') -Raw
        $result = Import-EmployeeBatch -CsvPath (Join-Path (Split-Path -Parent $PSScriptRoot) 'data/sample-new-hires.csv') -WhatIf
        $result.Succeeded | Should -Be 3
        (Get-Content (Join-Path $script:TestData 'employees.csv') -Raw) | Should -Be $before
        (Get-Content $env:ITAT_AUDIT_LOG_PATH -Raw) | Should -Match '"dryRun":true'
    }
}

Describe 'Copy-UserAccess' {
    It 'copies missing groups, skips held groups, and audits' {
        $result = Copy-UserAccess -SourceEmployeeId EMP-101 -TargetEmployeeId EMP-102 -Confirm:$false
        $employee = Import-Csv (Join-Path $script:TestData 'employees.csv') | Where-Object EmployeeId -eq EMP-102
        $employee.Groups | Should -Match 'Engineering-Standard'
        $result.Added | Should -Contain 'Engineering-Standard'
        $result.Skipped | Should -BeNullOrEmpty
        (Get-Content $env:ITAT_AUDIT_LOG_PATH -Raw) | Should -Match 'copy-user-access'
    }
    It 'rejects privileged groups unless explicitly included' {
        { Copy-UserAccess -SourceEmployeeId EMP-104 -TargetEmployeeId EMP-102 -Confirm:$false } | Should -Throw '*-IncludePrivileged*'
        { Copy-UserAccess -SourceEmployeeId EMP-999 -TargetEmployeeId EMP-102 -Confirm:$false } | Should -Throw '*not found*'
    }
    It 'shows additions with WhatIf without changing the target' {
        $before = Get-Content (Join-Path $script:TestData 'employees.csv') -Raw
        $result = Copy-UserAccess -SourceEmployeeId EMP-101 -TargetEmployeeId EMP-102 -WhatIf
        $result.DryRun | Should -BeTrue
        $result.Added | Should -Contain 'Engineering-Standard'
        (Get-Content (Join-Path $script:TestData 'employees.csv') -Raw) | Should -Be $before
        (Get-Content $env:ITAT_AUDIT_LOG_PATH -Raw) | Should -Match '"dryRun":true'
    }
}

Describe 'Role templates' {
    It 'uses a role template during onboarding' {
        $result = New-EmployeeOnboarding -EmployeeId EMP-210 -DisplayName 'Demo User 210' -Email demo.user210@example.invalid -Department Support -Confirm:$false
        $result.Groups | Should -Contain 'Remote-Support'
    }
}

Describe 'Get-UserSupportSnapshot' {
    It 'returns an object with identity, groups, devices, and access flags' {
        $result = Get-UserSupportSnapshot -EmployeeId EMP-101 -Confirm:$false
        $result.EmployeeId | Should -Be 'EMP-101'
        $result.Department | Should -Be 'Engineering'
        $result.Groups | Should -Contain 'Engineering-Standard'
        $result.Devices.Count | Should -BeGreaterThan 0
        $result.PSObject.Properties.Name | Should -Contain 'AccessReviewFlags'
    }
    It 'rejects an unknown employee' {
        { Get-UserSupportSnapshot -EmployeeId EMP-999 -Confirm:$false } | Should -Throw '*not found*'
    }
    It 'returns a readable text summary' {
        $result = Get-UserSupportSnapshot -EmployeeId EMP-101 -Format Text -TicketId HD-1234 -Confirm:$false
        $result | Should -Match 'User Support Snapshot'
        $result | Should -Match 'Employee: Demo User 101 \[EMP-101\]'
        $result | Should -Match 'Ticket: HD-1234'
        (Get-Content $env:ITAT_AUDIT_LOG_PATH -Raw) | Should -Match 'support-snapshot'
    }
}

Describe 'Ticket IDs' {
    It 'accepts valid ticket IDs and records them in audits' {
        Write-AuditLog -Action ticket-check -Target EMP-101 -Result Info -TicketId HD-1234 -Confirm:$false
        (Get-Content $env:ITAT_AUDIT_LOG_PATH -Raw) | Should -Match '"ticketId":"HD-1234"'
        @(Get-AuditLog -TicketId HD-1234).Count | Should -BeGreaterThan 0
    }
    It 'rejects invalid ticket IDs' {
        { Write-AuditLog -Action ticket-check -Target EMP-101 -Result Info -TicketId invalid } | Should -Throw
        { New-EmployeeOnboarding -EmployeeId EMP-211 -DisplayName 'Demo User 211' -Email demo.user211@example.invalid -Department Engineering -TicketId 1234 -Confirm:$false } | Should -Throw
    }
    It 'keeps TicketId optional for existing usage' {
        Write-AuditLog -Action optional-ticket -Target EMP-101 -Result Info -Confirm:$false
        $line = Get-Content $env:ITAT_AUDIT_LOG_PATH | Select-Object -Last 1 | ConvertFrom-Json
        $line.ticketId | Should -Be ''
    }
}

Describe 'New-ToolkitHtmlReport' {
    It 'creates a self-contained HTML report with expected sections' {
        $result = New-ToolkitHtmlReport -Name support-report -TicketId HD-5678 -Confirm:$false
        Test-Path $result.File | Should -BeTrue
        $html = Get-Content $result.File -Raw
        $html | Should -Match 'IT Support Operations Report'
        $html | Should -Match 'Device Health'
        $html | Should -Match 'Access Review'
        $html | Should -Match 'Recent Audit Activity'
        $html | Should -Match '<script>'
        $html | Should -Match 'prefers-color-scheme: dark'
    }
    It 'escapes employee names so markup cannot be injected' {
        $employeeFile = Join-Path $script:TestData 'employees.csv'
        $employeeRows = @(Import-Csv $employeeFile)
        foreach ($employee in $employeeRows) { if ($employee.EmployeeId -eq 'EMP-101') { $employee.DisplayName = '<img src=x onerror=alert(1)>Demo' } }
        $employeeRows | Export-Csv $employeeFile -NoTypeInformation -Encoding UTF8
        $result = New-ToolkitHtmlReport -Name escaped-report -Confirm:$false
        $html = Get-Content $result.File -Raw
        $html | Should -Match '&lt;img src=x onerror=alert\(1\)&gt;Demo'
        $html | Should -Not -Match '<img src=x'
    }
}
}
