function Get-ToolkitPath {
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
    $paths = Get-ToolkitPath
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
    $paths = Get-ToolkitPath
    if (-not (Test-Path -LiteralPath $paths.Data)) { New-Item -ItemType Directory -Path $paths.Data -Force | Out-Null }
    $file = Join-Path $paths.Data ($Name + '.csv')
    try { $Rows | Export-Csv -LiteralPath $file -NoTypeInformation -Encoding UTF8 -ErrorAction Stop }
    catch { throw "Unable to save simulated directory '$Name': $($_.Exception.Message)" }
}

function Get-ToolkitPasswordPolicy {
    [CmdletBinding()]
    param()
    $paths = Get-ToolkitPath
    $file = Join-Path $paths.Data 'password_policy.json'
    if (-not (Test-Path -LiteralPath $file)) { throw "Password policy file not found: $file" }
    try { Get-Content -LiteralPath $file -Raw | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "Unable to read password policy: $($_.Exception.Message)" }
}

function Get-ToolkitActor {
    if ($env:ITAT_ACTOR) { return $env:ITAT_ACTOR }
    return 'local-demo-operator'
}

function Get-ToolkitGroupName {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Department, [Parameter(Mandatory)][object[]]$Groups)
    $matchingGroups = @($Groups | Where-Object { $_.Department -eq $Department })
    return @($matchingGroups | ForEach-Object { $_.GroupName } | Where-Object { $_ })
}

function Get-ToolkitRoleTemplate {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidatePattern('^[A-Za-z][A-Za-z0-9-]*$')][string]$Department)
    $paths = Get-ToolkitPath
    $templatePath = Join-Path $paths.Data (Join-Path 'role-templates' ($Department + '.json'))
    if (-not (Test-Path -LiteralPath $templatePath)) { return $null }
    try { Get-Content -LiteralPath $templatePath -Raw | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "Unable to read role template '$Department': $($_.Exception.Message)" }
}

function Get-ToolkitDepartmentGroups {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Department)
    $template = Get-ToolkitRoleTemplate -Department $Department
    if ($null -ne $template) {
        return @($template.groups | Where-Object { $_ })
    }
    $groups = @(Import-ToolkitCsv -Name groups)
    return @(Get-ToolkitGroupName -Department $Department -Groups $groups)
}

function Test-ToolkitDepartment {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Department)
    $groups = @(Import-ToolkitCsv -Name groups)
    $csvDepartments = @($groups.Department | Where-Object { $_ -and $_ -ne 'All' } | Sort-Object -Unique)
    $paths = Get-ToolkitPath
    $templateDirectory = Join-Path $paths.Data 'role-templates'
    $templateDepartments = @()
    if (Test-Path -LiteralPath $templateDirectory) {
        $templateDepartments = @(Get-ChildItem -LiteralPath $templateDirectory -Filter '*.json' | ForEach-Object { $_.BaseName })
    }
    return (($csvDepartments + $templateDepartments) -contains $Department)
}

function ConvertTo-ToolkitDateTime {
    [CmdletBinding()]
    param([string]$DateText)
    if ([string]::IsNullOrWhiteSpace($DateText)) { return $null }
    $parsed = [datetime]::MinValue
    if ([datetime]::TryParse($DateText, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsed)) { return $parsed }
    return $null
}

function Test-ToolkitStaleDate {
    [CmdletBinding()]
    param([string]$DateText, [int]$Days = 90)
    $date = ConvertTo-ToolkitDateTime -DateText $DateText
    if ($null -eq $date) { return $true }
    return ($date -lt (Get-Date).AddDays(-$Days))
}

function ConvertTo-ToolkitFlatRow {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$InputObject)
    $row = [ordered]@{}
    foreach ($property in $InputObject.PSObject.Properties) {
        $value = $property.Value
        if ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) { $value = (@($value) -join ';') }
        $row[$property.Name] = $value
    }
    [pscustomobject]$row
}
