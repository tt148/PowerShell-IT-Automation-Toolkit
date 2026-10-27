# PowerShell IT Automation Toolkit

[![PowerShell CI](https://github.com/YOUR_USERNAME/PowerShell-IT-Automation-Toolkit/actions/workflows/ci.yml/badge.svg)](https://github.com/YOUR_USERNAME/PowerShell-IT-Automation-Toolkit/actions/workflows/ci.yml) ![PowerShell 7+](https://img.shields.io/badge/PowerShell-7%2B-5391FE?logo=powershell&logoColor=white) ![Pester 5](https://img.shields.io/badge/tests-Pester%205-2F855A) ![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)

A fictional-data PowerShell module that demonstrates safe IT operations automation: onboarding and offboarding, access reviews, device health, password-policy metadata checks, report exports and JSON-lines audit trails.

## Why this matters for helpdesk and sysadmin work

IT support teams repeat the same account, access and device tasks every day. Manual work can be inconsistent and difficult to audit. This project demonstrates how those workflows can be structured as reusable commands with validation, explicit previews, error handling, audit records and automated tests. It is a portfolio simulation, not a production identity-management system.

## Features

- **Onboarding:** create a fictional employee record, assign department groups and return a checklist.
- **Offboarding:** disable a simulated account, remove group membership and flag devices for return.
- **Access reviews:** identify stale accounts, privileged group membership and missing manager references.
- **Device inventory and health:** inspect OS metadata, last-seen dates, disk space, patch status and return flags.
- **Password policy metadata:** check password age, fictional password-length metadata, missing set dates, reset-required flags and never-expiring metadata. No passwords are read or stored; password length is represented by explicitly fictional metadata because directory systems generally do not reveal users’ actual passwords.
- **Reports:** export objects as timestamped CSV and JSON.
- **Audit trail:** JSON Lines records include UTC timestamp, actor, action, target, result and dry-run status.
- **Safe operation:** state-changing commands support `-WhatIf` and `-Confirm`.
- **Cross-platform CI:** GitHub Actions runs PSScriptAnalyzer and Pester on Windows and Ubuntu.

## Quick start

Requirements: PowerShell 7+ recommended; Pester 5 and PSScriptAnalyzer for tests/linting. Windows PowerShell 5.1 compatibility is intended where practical but CI targets modern `pwsh`.

```powershell
Import-Module ./src/ITAutomationToolkit/ITAutomationToolkit.psd1 -Force
Get-DeviceInventory
Get-DeviceHealthReport | Format-Table DeviceName, IsHealthy, Flags
Get-UserAccessReview -StaleAfterDays 90 | Format-Table EmployeeId, StaleAccount, ExcessPrivileges, MissingManager
```

### Dry-run onboarding

```powershell
New-EmployeeOnboarding `
  -EmployeeId EMP-110 `
  -DisplayName 'Demo User 110' `
  -Email 'demo.user110@example.invalid' `
  -Department Engineering `
  -ManagerId EMP-104 `
  -WhatIf
```

`-WhatIf` prints a preview and writes a `DryRun` entry to the audit trail without changing the CSV directory. After reviewing the plan, omit `-WhatIf` to apply changes to the local simulation. Use `-Confirm:$false` only when you're deliberately running unattended against the fictional data.

### Example output (illustrative)

```text
DeviceName         IsHealthy Flags
----------         --------- -----
DEMO-LAPTOP-201         True {}
DEMO-LAPTOP-202        False {LowDiskSpace, PatchRequired}
DEMO-LAPTOP-203        False {DeviceStale}
```

Output depends on the current date because stale-device and stale-account flags use date thresholds.

## Example commands

```powershell
# Preview then simulate a leaver workflow
Invoke-EmployeeOffboarding -EmployeeId EMP-103 -WhatIf
Invoke-EmployeeOffboarding -EmployeeId EMP-103 -Confirm:$false

# Review password metadata only; never inspect actual passwords
Test-PasswordPolicyCompliance | Format-Table EmployeeId, Compliant, Flags

# Export health report as CSV and JSON
Get-DeviceHealthReport | Export-ToolkitReport -Name device-health -Format Both -Confirm:$false

# Read the audit trail
Get-Content ./reports/audit.jsonl | ForEach-Object { $_ | ConvertFrom-Json }
```

## Screenshots and sample output

Add screenshots under `docs/screenshots/` before publishing. Recommended captures:

1. `device-health-report.png` — terminal showing healthy/unhealthy device flags.
2. `onboarding-whatif.png` — safe onboarding preview.
3. `offboarding-audit.png` — offboarding result and audit JSONL record.
4. `access-review.png` — stale/privileged/missing-manager flags.
5. `exported-reports.png` — sample CSV/JSON report files.
6. `github-actions.png` — successful Windows and Ubuntu CI jobs.

Do not include real personal data or secrets in screenshots. Sample output above is illustrative; generate actual captures from your local run.

## Folder structure

```text
.
├── .github/workflows/ci.yml
├── data/                         # Fictional CSV/JSON source data
├── docs/scenarios.md
├── reports/                      # Generated files; gitignored
├── src/ITAutomationToolkit/
│   ├── Private/                  # CSV/JSON provider and audit writer
│   ├── Public/                   # Exported advanced functions
│   ├── ITAutomationToolkit.psd1
│   └── ITAutomationToolkit.psm1
├── tests/                        # Pester v5 tests
├── PSScriptAnalyzerSettings.psd1
├── CONTRIBUTING.md
├── CHANGELOG.md
└── LICENSE
```

## Design decisions

- **Fictional data only:** names use `Demo User NNN`; addresses use the reserved `.invalid` domain. No real credentials, tenants or endpoints are required.
- **Provider boundary:** private CSV/JSON provider functions isolate data access. A future Active Directory or Microsoft Graph provider could implement the same operations without changing every public command.
- **No real password generation:** onboarding returns a clearly labelled non-secret reset placeholder and checklist. A production identity system should generate and deliver credentials through approved secure workflows.
- **Auditing:** JSONL is human-readable and easy to ingest into log tooling. This demo does not provide tamper-evident or centralized logging.
- **Safety:** mutating commands use `SupportsShouldProcess`. Preview intent is recorded as `DryRun`; reports and audit files are generated locally.
- **Cross-platform scope:** CI targets Windows and Ubuntu. OS-specific real administration actions are intentionally outside the current scope.

## Tests and linting

Install dependencies once:

```powershell
Install-Module Pester -MinimumVersion 5.0.0 -Scope CurrentUser
Install-Module PSScriptAnalyzer -Scope CurrentUser
```

Run Pester:

```powershell
Invoke-Pester ./tests
```

Run PSScriptAnalyzer:

```powershell
Invoke-ScriptAnalyzer -Path ./src/ITAutomationToolkit -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
```

CI runs both on `windows-latest` and `ubuntu-latest` and uploads Pester results and sample reports as artifacts. Run the commands locally before relying on the project; CI status is authoritative after the repository is pushed.

## Roadmap

- Add a real Active Directory provider behind the existing provider interface, with explicit opt-in and integration tests.
- Add a Microsoft Graph/Intune provider for device compliance and identity metadata.
- Add stronger schema validation and rollback behavior for multi-file simulated changes.
- Add signed module releases and versioned changelog automation.
- Add report retention controls and tamper-evident audit export.

## Why I built this

I built this portfolio project to practise translating routine IT support and systems administration tasks into repeatable, testable automation. The focus is on safety, clear operator feedback, auditability and documentation rather than connecting to a live company environment.

## License

MIT. See [LICENSE](LICENSE).
