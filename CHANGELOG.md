# Changelog

## 1.3.0 - 2026-10-28

- Extended offboarding with pre-change evidence snapshots, configurable scheduled expiry, simulated manager mailbox forwarding, and ticket-linked follow-up checklists.
- Added detailed offboarding evidence, retention, forwarding, and WhatIf coverage to Pester.
- Added security guidance, operations runbook, troubleshooting guide, architecture SVG, and editor configuration.

## 1.2.0 - 2026-10-28

- Added `Get-UserSupportSnapshot` with object and ticket-friendly text formats.
- Added optional `-TicketId` support to state-changing and audit commands, plus `Get-AuditLog` ticket filtering.
- Added `New-ToolkitHtmlReport` with escaped, self-contained HTML, summary cards, tables, filtering, sorting, responsive styling and system dark/light mode.

## 1.1.0 - 2026-10-28

- Added `Invoke-EmployeeTransfer` with department group reconciliation, optional manager changes, device review flags and audit records.
- Added department role templates under `data/role-templates`; onboarding and transfers use templates with CSV fallback.
- Added `Import-EmployeeBatch` for per-row fictional CSV onboarding validation, summaries and audit records.
- Added `Copy-UserAccess` with what-if previews, skipped existing groups, audit records and privileged-group opt-in.
- Added Pester coverage for the new workflows and WhatIf audit behavior.

## 1.0.1 - 2026-10-27

- Renamed private helpers to singular nouns so PSScriptAnalyzer (`PSUseSingularNouns`) passes in CI.
- CSV report export now joins list properties (`Flags`, `Groups`) instead of writing `System.Object[]`.
- Offboarding keeps the device `OwnerId` so returns can be tracked; devices are only flagged `ReturnRequired`.
- Onboarding rejects duplicate emails and unknown managers.
- Access review uses the `Privileged` column in `groups.csv` (name matching kept as fallback).
- Date parsing is culture-invariant; `Export-ToolkitReport` accepts empty input.
- CI: read-only token permissions and `-SkipPublisherCheck` for Pester install. More tests added.

## 1.0.0 - 2026-10-27

- Initial fictional CSV/JSON directory provider and IT operations toolkit module.
- Added onboarding, offboarding, access review, device inventory and health, password metadata checks, report export and audit logging.
- Added Pester v5 tests, PSScriptAnalyzer configuration and Windows/Linux GitHub Actions CI.
- Added usage, safety and scenario documentation.
