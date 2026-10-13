# Run the C# suite for one AI model and archive results + timings.
# Usage: powershell -ExecutionPolicy Bypass -File csharp\run_model.ps1 -Model "my-model"
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Model
)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Sanitize-ModelName([string]$n) {
    $clean = $n.Trim()
    foreach ($c in [IO.Path]::GetInvalidFileNameChars()) { $clean = $clean.Replace($c, '-') }
    foreach ($c in @(' ', '/', '\', ':', '*', '?', '"', '<', '>', '|')) { $clean = $clean.Replace($c, '-') }
    while ($clean.Contains('--')) { $clean = $clean.Replace('--', '-') }
    if ([string]::IsNullOrWhiteSpace($clean)) { $clean = 'unnamed' }
    return $clean
}

$safe = Sanitize-ModelName $Model
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$runDir = Join-Path $PSScriptRoot ("results\" + $safe + "\" + $stamp)
$suffix = 1
while (Test-Path $runDir) { $suffix++; $runDir = Join-Path $PSScriptRoot ("results\" + $safe + "\" + $stamp + "-" + $suffix) }
New-Item -ItemType Directory -Path $runDir | Out-Null

$levels = @('Level1.Easy', 'Level2.Medium', 'Level3.Hard', 'Level4.Harder', 'Level5.Hardest')

$runStart = Get-Date
$rows = @()
foreach ($lv in $levels) {
    $proj = Join-Path $PSScriptRoot "$lv\$lv.csproj"
    $logPath = Join-Path $runDir ($lv + '.log')
    # Redirect INSIDE cmd so native stderr never becomes a PS error record.
    $cmd = "dotnet run -c Release --project `"$proj`" > `"$logPath`" 2>&1"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    cmd.exe /c $cmd
    $code = $LASTEXITCODE
    $sw.Stop()
    $secs = [math]::Round($sw.Elapsed.TotalSeconds, 2)
    $text = Get-Content -Raw $logPath
    if ($null -eq $text) { $text = '' }
    $passed = ($code -eq 0) -and ($text -match 'ALL TESTS PASSED')
    if ($passed) { $status = 'PASS' } else { $status = 'FAIL' }
    $rows += [pscustomobject]@{ level = $lv; passed = $passed; seconds = $secs; exitCode = $code; log = ($lv + '.log') }
    Write-Host ("{0}: {1} ({2}s)" -f $lv, $status, $secs)
}
$runEnd = Get-Date
$total = [math]::Round(($runEnd - $runStart).TotalSeconds, 2)
$failed = @($rows | Where-Object { -not $_.passed }).Count
$overall = ($failed -eq 0)
if ($overall) { $overallText = 'PASS' } else { $overallText = 'FAIL' }

$summary = [pscustomobject]@{
    model = $Model
    suite = 'csharp'
    startedAt = $runStart.ToString('o')
    finishedAt = $runEnd.ToString('o')
    totalSeconds = $total
    overallPassed = $overall
    levels = $rows
}
$summary | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $runDir 'summary.json')

$md = @("# Run: $Model (csharp)", "", "- Started: $($runStart.ToString('o'))", "- Total: ${total}s", "- Result: $overallText", "", "| Level | Result | Seconds | Log |", "|---|---|---|---|")
foreach ($r in $rows) {
    if ($r.passed) { $s = 'PASS' } else { $s = 'FAIL' }
    $md += "| $($r.level) | $s | $($r.seconds) | $($r.log) |"
}
$md | Set-Content (Join-Path $runDir 'summary.md')

$idx = [pscustomobject]@{
    run = (Split-Path $runDir -Leaf)
    suite = 'csharp'
    startedAt = $runStart.ToString('o')
    totalSeconds = $total
    passed = ($rows.Count - $failed)
    failed = $failed
    overallPassed = $overall
}
Add-Content -Path (Join-Path $PSScriptRoot ("results\" + $safe + "\runs.jsonl")) -Value ($idx | ConvertTo-Json -Compress)
Write-Host "Results: $runDir"
if (-not $overall) { exit 1 }
