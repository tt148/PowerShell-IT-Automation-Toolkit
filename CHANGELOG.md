# Changelog

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
