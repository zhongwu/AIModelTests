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
    $dllPath = Join-Path $PSScriptRoot "$lv\bin\Release\net8.0\$lv.dll"
    # Build and run are separate so the run gets an external watchdog: model
    # code may hard-spin inside TryEnqueue/TryDequeue, which in-test guards
    # cannot catch. Redirect INSIDE cmd so stderr never becomes a PS error record.
    # NOTE: `dotnet build` takes the project positionally (`--project` is rejected).
    $buildCmd = "dotnet build -c Release `"$proj`" > `"$logPath`" 2>&1"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    cmd.exe /c $buildCmd
    $buildCode = $LASTEXITCODE
    $text = Get-Content -Raw $logPath
    if ($null -eq $text) { $text = '' }
    $code = $buildCode
    $passed = $false
    if (($buildCode -eq 0) -and (Test-Path $dllPath)) {
        # Run under a watchdog cmd wrapper that echoes the exit code to a FILE:
        # reading Process.ExitCode is unreliable in this host ($null on PS 5.1).
        $tmpCode = "$logPath.exitcode"
        $tmpOut = "$logPath.stdout"; $tmpErr = "$logPath.stderr"
        Remove-Item $tmpCode, $tmpOut, $tmpErr -Force -ErrorAction SilentlyContinue
        # (Leading `call` defeats cmd's /c quote-stripping when the command
        # starts with a quote character.)
        $inner = "call dotnet `"$dllPath`" & echo !ERRORLEVEL! > `"$tmpCode`""
        $proc = Start-Process -FilePath 'cmd.exe' -ArgumentList '/v:on', '/c', $inner `
            -NoNewWindow -PassThru `
            -RedirectStandardOutput $tmpOut -RedirectStandardError $tmpErr `
            -WorkingDirectory (Split-Path $dllPath)
        $exited = $proc.WaitForExit(240000)
        foreach ($f in @($tmpOut, $tmpErr)) {
            if (Test-Path $f) { Add-Content -Path $logPath -Value (Get-Content -Raw $f); Remove-Item $f -Force }
        }
        if ($exited) {
            if (Test-Path $tmpCode) {
                $code = [int]((Get-Content -Raw $tmpCode).Trim())
                Remove-Item $tmpCode -Force
            }
            else { $code = -1 }
        }
        else {
            Stop-Process -InputObject $proc -Force
            $code = 124
            Add-Content -Path $logPath -Value "`n[RUNNER] TIMEOUT: test killed after 240s"
        }
        $text = Get-Content -Raw $logPath
        if ($null -eq $text) { $text = '' }
        $passed = ($code -eq 0) -and ($text -match 'ALL TESTS PASSED')
    }
    $sw.Stop()
    $secs = [math]::Round($sw.Elapsed.TotalSeconds, 2)
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
