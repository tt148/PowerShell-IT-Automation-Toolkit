# Security Policy

## Reporting issues

Report suspected security issues privately by opening a GitHub Security Advisory for this repository when available, or contact the repository maintainer through the contact method listed in the repository profile. Include reproduction steps and avoid posting real credentials or tenant details in public issues.

## Scope and data

This project is a PowerShell portfolio simulation. It contains fictional employee names, reserved `example.invalid` email addresses, CSV and JSON fixture data, and no real identity-provider integration. It must never make Active Directory, Entra, Microsoft Graph, Exchange, or other live-service calls.

## Safe-by-default use

- Review changes with `-WhatIf` before applying them.
- Use `-Confirm:$false` only for deliberate unattended runs against copied fictional data.
- Commands write JSON-lines audit records for success, failure, dry-run, and informational actions.
- Reports and evidence snapshots are generated only under the configured reports path.

Do not place real credentials, secrets, tokens, personal data, or production identifiers in repository data or screenshots. A real provider can replace the private provider boundary only after independent authentication, authorization, audit, approval, and secret-management controls are implemented.
