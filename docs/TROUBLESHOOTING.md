# Troubleshooting

## Module does not import

- Run PowerShell from the repository root.
- Import the manifest explicitly: `Import-Module ./src/ITAutomationToolkit/ITAutomationToolkit.psd1 -Force`.
- Verify `ITAutomationToolkit.psd1`, `ITAutomationToolkit.psm1`, and the `Public` directory exist.
- Restart the session after installing PowerShell modules.

## Module can read the wrong data

- `ITAT_DATA_PATH` must point to a directory containing `employees.csv`, `groups.csv`, `devices.csv`, and optional `role-templates`.
- Set it in the current session:
  ```powershell
  $env:ITAT_DATA_PATH = (Resolve-Path ./data).Path
  ```
- Test paths with `Test-Path` and copy the repository data before mutation.

## Reports or audit files are missing

- `ITAT_REPORTS_PATH` controls generated reports; `ITAT_AUDIT_LOG_PATH` controls the audit file.
- Create and verify the directories:
  ```powershell
  $env:ITAT_REPORTS_PATH = '/tmp/itat-reports'
  $env:ITAT_AUDIT_LOG_PATH = '/tmp/itat-reports/audit.jsonl'
  ```
- A successful mutation creates reports. `-WhatIf` intentionally creates no evidence or report file, although it may write a dry-run audit entry.

## Execution policy blocks scripts or module import

- Use the least-restrictive policy permitted by the machine. For the current process, PowerShell 7 may use `Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned`.
- On managed systems, do not bypass organization policy. Ask an administrator to review the module and policy.

## Pester failures

- CI expects Pester 5. Install a compatible release:
  ```powershell
  Install-Module Pester -MinimumVersion 5.0.0 -MaximumVersion 5.99.99 -Scope CurrentUser -Force -SkipPublisherCheck
  ```
- Run from the repository root with `Invoke-Pester ./tests -Output Detailed`.
- Check that temporary `ITAT_*` variables are restored or set only inside an isolated session.

## PSScriptAnalyzer findings

- Install the latest analyzer with `Install-Module PSScriptAnalyzer -Scope CurrentUser -Force`.
- Run exactly:
  ```powershell
  Invoke-ScriptAnalyzer -Path ./src/ITAutomationToolkit -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
  ```
- CI fails on warning, information, and error results. Fix the code rather than excluding rules or loosening the settings.
