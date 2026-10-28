function New-ToolkitHtmlReport {
    <#
    .SYNOPSIS
    Creates a self-contained HTML operations report.
    .DESCRIPTION
    Uses fictional directory, device, access-review, and audit data. The generated page includes inline filtering and sorting.
    .PARAMETER Name
    Safe report name used for the output file.
    .PARAMETER TicketId
    Optional ticket identifier included in the audit record.
    .EXAMPLE
    New-ToolkitHtmlReport -Name support-operations -TicketId HD-1234
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Low')]
    param(
        [ValidatePattern('^[a-zA-Z0-9_-]{2,60}$')][string]$Name = 'it-support-operations',
        [ValidatePattern('^$|^[A-Za-z]{1,10}-[0-9]{1,10}$')][string]$TicketId = ''
    )
    $paths = Get-ToolkitPath
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
    $file = Join-Path $paths.Reports "$Name-$stamp.html"
    if (-not $PSCmdlet.ShouldProcess($file, 'Create self-contained HTML operations report')) {
        Add-ToolkitAuditEntry -Action 'html-report' -Target $Name -Result DryRun -Details 'Would create HTML operations report.' -TicketId $TicketId
        return [pscustomobject]@{ Name=$Name; File=$file; DryRun=$true }
    }

    try {
        $users = @(Import-ToolkitCsv -Name employees)
        $devices = @(Get-DeviceHealthReport)
        $reviews = @(Get-UserAccessReview)
        $unhealthy = @($devices | Where-Object { -not $_.IsHealthy }).Count
        $stale = @($reviews | Where-Object { $_.StaleAccount }).Count
        $privileged = @($reviews | Where-Object { $_.ExcessPrivileges }).Count

        $deviceRows = foreach ($device in $devices) {
            '<tr><td>' + (ConvertTo-ToolkitHtmlText $device.DeviceId) + '</td><td>' + (ConvertTo-ToolkitHtmlText $device.DeviceName) + '</td><td>' + (ConvertTo-ToolkitHtmlText $device.OwnerId) + '</td><td>' + (ConvertTo-ToolkitHtmlText $device.LastSeen) + '</td><td>' + (ConvertTo-ToolkitHtmlText $device.PatchStatus) + '</td><td>' + (ConvertTo-ToolkitHtmlText $device.DiskFreePercent) + '%</td><td>' + (ConvertTo-ToolkitHtmlText (@($device.Flags) -join ', ')) + '</td><td>' + $(if ($device.IsHealthy) { 'Healthy' } else { 'Unhealthy' }) + '</td></tr>'
        }
        $reviewRows = foreach ($review in $reviews) {
            '<tr><td>' + (ConvertTo-ToolkitHtmlText $review.EmployeeId) + '</td><td>' + (ConvertTo-ToolkitHtmlText $review.DisplayName) + '</td><td>' + (ConvertTo-ToolkitHtmlText $review.Department) + '</td><td>' + (ConvertTo-ToolkitHtmlText (@($review.Groups) -join ', ')) + '</td><td>' + $(if ($review.StaleAccount) { 'Yes' } else { 'No' }) + '</td><td>' + $(if ($review.MissingManager) { 'Yes' } else { 'No' }) + '</td><td>' + (ConvertTo-ToolkitHtmlText (@($review.Flags) -join ', ')) + '</td></tr>'
        }

        $auditRows = @()
        if (Test-Path -LiteralPath $paths.Audit) {
            foreach ($line in @(Get-Content -LiteralPath $paths.Audit -ErrorAction Stop | Select-Object -Last 25)) {
                try {
                    $entry = $line | ConvertFrom-Json -ErrorAction Stop
                    $ticket = if ([string]::IsNullOrWhiteSpace([string]$entry.ticketId)) { '-' } else { [string]$entry.ticketId }
                    $auditRows += '<tr><td>' + (ConvertTo-ToolkitHtmlText $entry.timestamp) + '</td><td>' + (ConvertTo-ToolkitHtmlText $entry.action) + '</td><td>' + (ConvertTo-ToolkitHtmlText $entry.target) + '</td><td>' + (ConvertTo-ToolkitHtmlText $ticket) + '</td><td>' + (ConvertTo-ToolkitHtmlText $entry.result) + '</td></tr>'
                } catch { continue }
            }
        }

        $html = @'
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>IT Support Operations Report</title>
<style>
:root{color-scheme:light dark;--bg:#f4f6f8;--panel:#fff;--text:#18202a;--muted:#667085;--line:#d0d5dd;--accent:#1677b8}*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:14px/1.45 Arial,sans-serif}main{max-width:1200px;margin:auto;padding:24px}header{display:flex;justify-content:space-between;align-items:center;gap:16px}.cards{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:12px;margin:20px 0}.card{background:var(--panel);border:1px solid var(--line);border-radius:6px;padding:14px}.card strong{font-size:24px;display:block}.section{background:var(--panel);border:1px solid var(--line);border-radius:6px;margin-top:16px;padding:14px;overflow:hidden}input{width:min(320px,100%);padding:9px;border:1px solid var(--line);border-radius:4px;background:var(--panel);color:var(--text)}table{width:100%;border-collapse:collapse;margin-top:10px}th,td{padding:9px;border-bottom:1px solid var(--line);text-align:left}th{cursor:pointer;color:var(--muted);white-space:nowrap}.wrap{overflow-x:auto}@media(max-width:800px){main{padding:12px}.cards{grid-template-columns:repeat(2,minmax(0,1fr))}header{align-items:flex-start;flex-direction:column}}@media (prefers-color-scheme: dark){:root{--bg:#111827;--panel:#1f2937;--text:#f9fafb;--muted:#cbd5e1;--line:#374151;--accent:#38bdf8}}
</style></head><body><main>
<header><div><h1>IT Support Operations Report</h1><div>Generated: __STAMP__</div></div><input id="filter" type="search" placeholder="Filter tables" aria-label="Filter report tables"></header>
<div class="cards"><article class="card"><span>Users</span><strong>__USERS__</strong></article><article class="card"><span>Devices</span><strong>__DEVICES__</strong></article><article class="card"><span>Unhealthy devices</span><strong>__UNHEALTHY__</strong></article><article class="card"><span>Stale accounts</span><strong>__STALE__</strong></article><article class="card"><span>Privileged accounts</span><strong>__PRIVILEGED__</strong></article></div>
<section class="section"><h2>Device Health</h2><div class="wrap"><table><thead><tr><th data-sort>Device ID</th><th data-sort>Device</th><th data-sort>Owner</th><th data-sort>Last Seen</th><th data-sort>Patch</th><th data-sort>Disk</th><th data-sort>Flags</th><th data-sort>Status</th></tr></thead><tbody>__DEVICE_ROWS__</tbody></table></div></section>
<section class="section"><h2>Access Review</h2><div class="wrap"><table><thead><tr><th data-sort>Employee ID</th><th data-sort>Name</th><th data-sort>Department</th><th data-sort>Groups</th><th data-sort>Stale</th><th data-sort>Missing Manager</th><th data-sort>Flags</th></tr></thead><tbody>__REVIEW_ROWS__</tbody></table></div></section>
<section class="section"><h2>Recent Audit Activity</h2><div class="wrap"><table><thead><tr><th data-sort>Timestamp</th><th data-sort>Action</th><th data-sort>Target</th><th data-sort>Ticket ID</th><th data-sort>Result</th></tr></thead><tbody>__AUDIT_ROWS__</tbody></table></div></section>
</main><script>
const filter=document.getElementById('filter');filter.addEventListener('input',()=>{const term=filter.value.toLowerCase();document.querySelectorAll('tbody tr').forEach(row=>row.hidden=!row.textContent.toLowerCase().includes(term))});document.querySelectorAll('th[data-sort]').forEach((header,index)=>header.addEventListener('click',()=>{const table=header.closest('table'),body=table.tBodies[0],rows=[...body.rows],reverse=header.dataset.order==='asc';rows.sort((a,b)=>a.cells[index].textContent.localeCompare(b.cells[index].textContent,undefined,{numeric:true,sensitivity:'base'})*(reverse?-1:1));header.dataset.order=reverse?'desc':'asc';rows.forEach(row=>body.appendChild(row))}));
</script></body></html>
'@
        $html = $html.Replace('__STAMP__',(ConvertTo-ToolkitHtmlText (Get-Date).ToUniversalTime().ToString('u'))).Replace('__USERS__',$users.Count).Replace('__DEVICES__',$devices.Count).Replace('__UNHEALTHY__',$unhealthy).Replace('__STALE__',$stale).Replace('__PRIVILEGED__',$privileged).Replace('__DEVICE_ROWS__',($deviceRows -join "`n")).Replace('__REVIEW_ROWS__',($reviewRows -join "`n")).Replace('__AUDIT_ROWS__',($auditRows -join "`n"))
        if (-not (Test-Path -LiteralPath $paths.Reports)) { New-Item -ItemType Directory -Path $paths.Reports -Force | Out-Null }
        Set-Content -LiteralPath $file -Value $html -Encoding UTF8 -ErrorAction Stop
        Add-ToolkitAuditEntry -Action 'html-report' -Target $Name -Result Success -Details "Created HTML operations report; file=$file" -TicketId $TicketId
        [pscustomobject]@{ Name=$Name; File=$file; Users=$users.Count; Devices=$devices.Count; UnhealthyDevices=$unhealthy; StaleAccounts=$stale; PrivilegedAccounts=$privileged; DryRun=$false }
    } catch {
        Add-ToolkitAuditEntry -Action 'html-report' -Target $Name -Result Failed -Details $_.Exception.Message -TicketId $TicketId
        throw "HTML report creation failed for '$Name': $($_.Exception.Message)"
    }
}
