# Operational scenarios

All examples operate only on the fictional CSV/JSON data shipped with this repository. Use `-WhatIf` first for any state-changing operation. Applying a change edits `data/*.csv`; use a scratch copy via `ITAT_DATA_PATH` (see the README) or run `git restore data` afterwards.

## 1. New hire Monday

Preview the onboarding record for a fictional engineering hire:

```powershell
New-EmployeeOnboarding -EmployeeId EMP-110 -DisplayName 'Demo User 110' -Email 'demo.user110@example.invalid' -Department Engineering -ManagerId EMP-104 -WhatIf
```

After reviewing the preview, apply it to the local simulation:

```powershell
New-EmployeeOnboarding -EmployeeId EMP-110 -DisplayName 'Demo User 110' -Email 'demo.user110@example.invalid' -Department Engineering -ManagerId EMP-104 -Confirm:$false
```

The returned checklist reminds an operator to provision real access only through an approved identity system. The password field is a conspicuous non-secret placeholder, not a usable credential.

## 2. Leaver Friday

Preview disabling a fictional account, removing group membership and flagging assigned devices:

```powershell
Invoke-EmployeeOffboarding -EmployeeId EMP-103 -WhatIf
```

Apply the changes to the local simulation after review:

```powershell
Invoke-EmployeeOffboarding -EmployeeId EMP-103 -Confirm:$false
Get-DeviceInventory
```

## 3. Quarterly access audit

Review stale accounts, privileged group membership and missing manager references, then export the results:

```powershell
$review = Get-UserAccessReview -StaleAfterDays 90
$review | Format-Table EmployeeId, DisplayName, StaleAccount, ExcessPrivileges, MissingManager
$review | Export-ToolkitReport -Name quarterly-access-review -Format Both -Confirm:$false
```

Inspect the JSON-lines audit trail under `reports/audit.jsonl` and retain reports according to your organization's data-handling policy. This demo uses fictional data only.
