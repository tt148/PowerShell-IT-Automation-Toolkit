function Export-ToolkitReport {
    <#
    .SYNOPSIS
    Exports a supplied report collection to timestamped CSV and JSON files.
    .DESCRIPTION
    Writes output beneath reports/ by default. Report files are generated output and are gitignored.
    .PARAMETER InputObject
    Objects to export.
    .PARAMETER Name
    Safe report name used in filenames.
    .PARAMETER Format
    Select CSV, JSON, or both.
    .EXAMPLE
    Get-DeviceHealthReport | Export-ToolkitReport -Name device-health -Format Both
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Low')]
    param(
        [Parameter(Mandatory,ValueFromPipeline)][object[]]$InputObject,
        [Parameter(Mandatory)][ValidatePattern('^[a-zA-Z0-9_-]{2,60}$')][string]$Name,
        [ValidateSet('CSV','JSON','Both')][string]$Format='Both'
    )
    begin { $items=[System.Collections.Generic.List[object]]::new() }
    process { foreach ($item in $InputObject) { $items.Add($item) } }
    end {
        $paths=Get-ToolkitPaths
        $stamp=(Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
        $written=[System.Collections.Generic.List[string]]::new()
        $extensions = @('csv','json')
        if ($Format -eq 'CSV') { $extensions = @('csv') }
        elseif ($Format -eq 'JSON') { $extensions = @('json') }
        foreach ($extension in $extensions) {
            $file=Join-Path $paths.Reports "$Name-$stamp.$extension"
            if ($PSCmdlet.ShouldProcess($file,"Export $($items.Count) report row(s) as $extension")) {
                try {
                    if (-not (Test-Path -LiteralPath $paths.Reports)) { New-Item -ItemType Directory -Path $paths.Reports -Force | Out-Null }
                    if ($extension -eq 'csv') { $items | Export-Csv -LiteralPath $file -NoTypeInformation -Encoding UTF8 -ErrorAction Stop }
                    else { ConvertTo-Json -InputObject @($items) -Depth 8 | Set-Content -LiteralPath $file -Encoding UTF8 -ErrorAction Stop }
                    $written.Add($file)
                    Add-ToolkitAuditEntry -Action 'report-export' -Target $Name -Result Success -Details "Format=$extension; rows=$($items.Count); file=$file"
                } catch { Add-ToolkitAuditEntry -Action 'report-export' -Target $Name -Result Failed -Details $_.Exception.Message; throw "Report export failed for '$file': $($_.Exception.Message)" }
            } else {
                Add-ToolkitAuditEntry -Action 'report-export' -Target $Name -Result DryRun -Details "Would export $($items.Count) row(s) to $file"
            }
        }
        [pscustomobject]@{ Name=$Name; Rows=$items.Count; Files=@($written); DryRun=($written.Count -eq 0) }
    }
}
