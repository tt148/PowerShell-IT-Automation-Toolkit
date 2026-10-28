function Add-ToolkitAuditEntry {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification='Audit entries must be persisted even when recording a dry-run request.') ]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Action,
        [Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)][ValidateSet('Success','DryRun','Failed','Info')][string]$Result,
        [string]$Details = ''
    )
    $paths = Get-ToolkitPath
    $parent = Split-Path -Parent $paths.Audit
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force -WhatIf:$false | Out-Null }
    $entry = [ordered]@{
        timestamp = (Get-Date).ToUniversalTime().ToString('o')
        actor = Get-ToolkitActor
        action = $Action
        target = $Target
        result = $Result
        dryRun = ($Result -eq 'DryRun')
        details = $Details
    }
    try { ($entry | ConvertTo-Json -Compress -Depth 5) | Add-Content -LiteralPath $paths.Audit -Encoding UTF8 -ErrorAction Stop -WhatIf:$false }
    catch { Write-Error "Could not write audit log '$($paths.Audit)': $($_.Exception.Message)" -ErrorAction Continue }
}
