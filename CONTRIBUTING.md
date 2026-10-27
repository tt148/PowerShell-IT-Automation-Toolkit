# Contributing

Thanks for helping improve the PowerShell IT Automation Toolkit.

## Development setup

- Install PowerShell 7+ (Windows PowerShell 5.1 compatibility is a best-effort goal).
- Install Pester 5 and PSScriptAnalyzer from PowerShell Gallery.
- Use only fictional data with the reserved `example.invalid` domain.

## Before submitting a change

1. Add or update Pester tests for every behavior change.
2. Run `Invoke-ScriptAnalyzer -Path ./src/ITAutomationToolkit -Recurse -Settings ./PSScriptAnalyzerSettings.psd1`.
3. Run `Invoke-Pester ./tests`.
4. Confirm `-WhatIf` makes no state changes and records dry-run intent for state-changing commands.
5. Use a conventional commit such as `feat: add device warranty report` or `test: cover offboarding dry run`.

Never add real employee data, passwords, tokens, tenant IDs, production exports or personal information.
