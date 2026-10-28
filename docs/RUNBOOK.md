# Operations Runbook

Use a copied fictional data directory. Do not point `ITAT_DATA_PATH` at production data.

## Onboarding

1. Set a scratch data directory and import the module.
2. Preview:
   ```powershell
   New-EmployeeOnboarding -EmployeeId EMP-210 -DisplayName 'Demo User 210' -Email 'demo.user210@example.invalid' -Department Engineering -ManagerId EMP-104 -TicketId HD-3001 -WhatIf
   ```
3. Apply:
   ```powershell
   New-EmployeeOnboarding -EmployeeId EMP-210 -DisplayName 'Demo User 210' -Email 'demo.user210@example.invalid' -Department Engineering -ManagerId EMP-104 -TicketId HD-3001 -Confirm:$false
   ```
4. Check the employee appears in `data/employees.csv`, the role groups match the department template, and the audit log contains the ticket ID.

## Offboarding

1. Preview:
   ```powershell
   Invoke-EmployeeOffboarding -EmployeeId EMP-102 -RetentionDays 90 -TicketId HD-3002 -WhatIf
   ```
2. Apply:
   ```powershell
   Invoke-EmployeeOffboarding -EmployeeId EMP-102 -RetentionDays 90 -TicketId HD-3002 -Confirm:$false
   ```
3. Check the account is disabled, expiry and forwarding fields are set, groups are removed, devices are flagged, and one timestamped evidence JSON exists under reports. Close the ticket only after reviewing the returned checklist.

## Department transfer

1. Preview:
   ```powershell
   Invoke-EmployeeTransfer -EmployeeId EMP-101 -NewDepartment Finance -NewManagerId EMP-104 -TicketId HD-3003 -WhatIf
   ```
2. Apply:
   ```powershell
   Invoke-EmployeeTransfer -EmployeeId EMP-101 -NewDepartment Finance -NewManagerId EMP-104 -TicketId HD-3003 -Confirm:$false
   ```
3. Check old-only groups are removed, new groups are added, common groups remain, the department and manager changed, and any assigned devices are flagged for review.

## Copying access

1. Preview non-privileged access:
   ```powershell
   Copy-UserAccess -SourceEmployeeId EMP-101 -TargetEmployeeId EMP-102 -TicketId HD-3004 -WhatIf
   ```
2. Apply only the approved groups:
   ```powershell
   Copy-UserAccess -SourceEmployeeId EMP-101 -TargetEmployeeId EMP-102 -TicketId HD-3004 -Confirm:$false
   ```
3. For explicitly approved privileged access, add `-IncludePrivileged`. Verify the target groups and audit record afterward.

## Support snapshot and reports

1. Get a ticket-ready snapshot:
   ```powershell
   Get-UserSupportSnapshot -EmployeeId EMP-101 -Format Text -TicketId HD-3005
   ```
2. Filter audit activity:
   ```powershell
   Get-AuditLog -TicketId HD-3005
   ```
3. Create the HTML report:
   ```powershell
   New-ToolkitHtmlReport -Name support-operations -TicketId HD-3005
   ```
4. Open the generated HTML file and check user, device, unhealthy-device, stale-account, privileged-account, audit, ticket ID, sorting, and filter results.
