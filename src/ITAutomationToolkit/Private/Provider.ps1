function Get-ToolkitPaths {
    [CmdletBinding()]
    param()
    $repoRoot = Split-Path -Parent (Split-Path -Parent $script:ModuleRoot)
    $dataPath = if ($env:ITAT_DATA_PATH) { $env:ITAT_DATA_PATH } else { Join-Path $repoRoot 'data' }
    $reportsPath = if ($env:ITAT_REPORTS_PATH) { $env:ITAT_REPORTS_PATH } else { Join-Path $repoRoot 'reports' }
    $auditPath = if ($env:ITAT_AUDIT_LOG_PATH) { $env:ITAT_AUDIT_LOG_PATH } else { Join-Path $reportsPath 'audit.jsonl' }
    [pscustomobject]@{ Data = $dataPath; Reports = $reportsPath; Audit = $auditPath }
}

function Import-ToolkitCsv {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateSet('employees','groups','devices')][string]$Name)
    $paths = Get-ToolkitPaths
    $file = Join-Path $paths.Data ($Name + '.csv')
    if (-not (Test-Path -LiteralPath $file)) { throw "Directory provider file not found: $file" }
    try { @(Import-Csv -LiteralPath $file -ErrorAction Stop) }
    catch { throw "Unable to read simulated directory '$Name': $($_.Exception.Message)" }
}

function Export-ToolkitCsv {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification='Internal provider helper; public callers gate writes through ShouldProcess.') ]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('employees','groups','devices')][string]$Name,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Rows
    )
    $paths = Get-ToolkitPaths
    if (-not (Test-Path -LiteralPath $paths.Data)) { New-Item -ItemType Directory -Path $paths.Data -Force | Out-Null }
    $file = Join-Path $paths.Data ($Name + '.csv')
    try { $Rows | Export-Csv -LiteralPath $file -NoTypeInformation -Encoding UTF8 -ErrorAction Stop }
    catch { throw "Unable to save simulated directory '$Name': $($_.Exception.Message)" }
}

function Get-ToolkitPasswordPolicy {
    [CmdletBinding()]
    param()
    $paths = Get-ToolkitPaths
    $file = Join-Path $paths.Data 'password_policy.json'
    if (-not (Test-Path -LiteralPath $file)) { throw "Password policy file not found: $file" }
    try { Get-Content -LiteralPath $file -Raw | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "Unable to read password policy: $($_.Exception.Message)" }
}

function Get-ToolkitActor {
    if ($env:ITAT_ACTOR) { return $env:ITAT_ACTOR }
    return 'local-demo-operator'
}

function Get-ToolkitGroupNames {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Department, [Parameter(Mandatory)][object[]]$Groups)
    $matches = @($Groups | Where-Object { $_.Department -eq $Department })
    return @($matches | ForEach-Object { $_.GroupName } | Where-Object { $_ })
}

function Test-ToolkitStaleDate {
    param([string]$DateText, [int]$Days = 90)
    if ([string]::IsNullOrWhiteSpace($DateText)) { return $true }
    try { return ([datetime]::Parse($DateText) -lt (Get-Date).AddDays(-$Days)) }
    catch { return $true }
}
