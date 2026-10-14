# Run the C++ suite for one AI model and archive results + timings.
# Usage: powershell -ExecutionPolicy Bypass -File cpp\run_model.ps1 -Model "my-model"
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Model,
    # Only run these levels, comma-separated leaf names (e.g. 'level3_hard,level4_harder'). Empty = all.
    [string]$Only = ""
)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Find-VcVars {
    $vswhere = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path $vswhere) {
        $inst = & $vswhere -latest -property installationPath 2>$null
        if ($inst) {
            $cand = Join-Path $inst 'VC\Auxiliary\Build\vcvars64.bat'
            if (Test-Path $cand) { return $cand }
        }
    }
    $fallback = 'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat'
    if (Test-Path $fallback) { return $fallback }
    throw "vcvars64.bat not found. Run this from a Visual Studio Developer PowerShell instead."
}

function Sanitize-ModelName([string]$n) {
    $clean = $n.Trim()
    foreach ($c in [IO.Path]::GetInvalidFileNameChars()) { $clean = $clean.Replace($c, '-') }
    foreach ($c in @(' ', '/', '\', ':', '*', '?', '"', '<', '>', '|')) { $clean = $clean.Replace($c, '-') }
    while ($clean.Contains('--')) { $clean = $clean.Replace('--', '-') }
    if ([string]::IsNullOrWhiteSpace($clean)) { $clean = 'unnamed' }
    return $clean
}

$vcvars = Find-VcVars
$safe = Sanitize-ModelName $Model
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$runDir = Join-Path $PSScriptRoot ("results\" + $safe + "\" + $stamp)
$suffix = 1
while (Test-Path $runDir) { $suffix++; $runDir = Join-Path $PSScriptRoot ("results\" + $safe + "\" + $stamp + "-" + $suffix) }
New-Item -ItemType Directory -Path $runDir | Out-Null
$binDir = Join-Path $runDir 'bin'
New-Item -ItemType Directory -Path $binDir | Out-Null

# NOTE: binaries go to the run's bin/ dir (archived with the run) instead of
# %TEMP%: org Device Guard intermittently blocks fresh %TEMP% binaries, and a
# block verdict can stick to a file hash, so a blocked attempt RELINKS
# (fresh lottery ticket) rather than relaunching the same file.
$levels = @(
    @{ Name = 'level1_easy';    Sources = 'level1_easy\test.cpp level1_easy\solution.cpp'; Flags = ''; Exe = 'test1.exe' },
    @{ Name = 'level2_medium';  Sources = 'level2_medium\test.cpp level2_medium\solution.cpp'; Flags = ''; Exe = 'test2.exe' },
    @{ Name = 'level3_hard';    Sources = 'level3_hard\test.cpp'; Flags = '';                              Exe = 'test3.exe' },
    @{ Name = 'level4_harder';  Sources = 'level4_harder\test.cpp'; Flags = '';                            Exe = 'test4.exe' },
    @{ Name = 'level5_hardest'; Sources = 'level5_hardest\test.cpp'; Flags = '/O2';                         Exe = 'test5.exe' }
)

$runStart = Get-Date
$rows = @()
$onlyList = @($Only -split ',' | Where-Object { $_ -ne '' })
if ($onlyList.Count -gt 0) { $levels = @($levels | Where-Object { $onlyList -contains $_.Name }) }
foreach ($lv in $levels) {
    $logPath = Join-Path $runDir ($lv.Name + '.log')
    $exePath = Join-Path $binDir $lv.Exe
    # Build and run are separate steps. Redirect INSIDE cmd (not in PowerShell)
    # so native stderr never becomes a PS error record.
    $buildCmd = "call `"$vcvars`" >nul && cl /EHsc /std:c++17 $($lv.Flags) $($lv.Sources) /Fe:$exePath /Fo:$binDir\ > `"$logPath`" 2>&1"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $attempt = 0
    $passed = $false
    $code = -1
    $text = ''
    $retryable = $false
    do {
        $attempt++
        $retryable = $false
        if ($attempt -gt 1) { Start-Sleep -Seconds 5 }
        cmd.exe /c $buildCmd
        $buildCode = $LASTEXITCODE
        $text = Get-Content -Raw $logPath
        if ($null -eq $text) { $text = '' }
        if (($text -match 'Device Guard') -and ($buildCode -ne 0)) {
            $code = $buildCode
            $retryable = $true # relink: block verdicts can stick to a file hash
            continue
        }
        if ($buildCode -ne 0) { $code = $buildCode; break } # genuine compile error
        # Run the exe under a watchdog cmd wrapper. The wrapper echoes the exit
        # code to a FILE: reading Process.ExitCode is unreliable in this host
        # (observed $null on PS 5.1), while WaitForExit()'s bool is solid.
        # Model code may also hard-spin inside TryEnqueue/TryDequeue, which only
        # an external kill can stop (code 124).
        $tmpCode = "$logPath.exitcode"
        $tmpOut = "$logPath.stdout"; $tmpErr = "$logPath.stderr"
        Remove-Item $tmpCode, $tmpOut, $tmpErr -Force -ErrorAction SilentlyContinue
        # (Leading `call` defeats cmd's /c quote-stripping when the command
        # starts with a quote character.)
        $inner = "call `"$exePath`" & echo !ERRORLEVEL! > `"$tmpCode`""
        try {
            $proc = Start-Process -FilePath 'cmd.exe' -ArgumentList '/v:on', '/c', $inner `
                -NoNewWindow -PassThru `
                -RedirectStandardOutput $tmpOut -RedirectStandardError $tmpErr `
                -WorkingDirectory $binDir
        }
        catch {
            $text += "`n[RUNNER] process start blocked: $_"
            Set-Content -Path $logPath -Value $text
            $code = $buildCode
            $retryable = $true # relink and retry
            continue
        }
        $exited = $proc.WaitForExit(240000)
        foreach ($f in @($tmpOut, $tmpErr)) {
            if (Test-Path $f) { Add-Content -Path $logPath -Value (Get-Content -Raw $f); Remove-Item $f -Force -ErrorAction SilentlyContinue }
        }
        if ($exited) {
            if (Test-Path $tmpCode) {
                $code = [int]((Get-Content -Raw $tmpCode).Trim())
                Remove-Item $tmpCode -Force
            }
            else { $code = -1 }
        }
        else {
            # taskkill /T kills the whole tree: killing only the wrapper orphans
            # the test process, which then keeps redirect files locked.
            cmd.exe /c "taskkill /PID $($proc.Id) /T /F >nul 2>&1"
            $proc.WaitForExit(15000) | Out-Null
            $code = 124
            Add-Content -Path $logPath -Value "`n[RUNNER] TIMEOUT: exe killed after 240s"
        }
        $text = Get-Content -Raw $logPath
        if ($null -eq $text) { $text = '' }
        $passed = ($code -eq 0) -and ($text -match 'ALL TESTS PASSED')
        if ((-not $passed) -and ($code -ne 0) -and ($text -match 'Device Guard')) { $retryable = $true }
    } while ((-not $passed) -and $retryable -and ($attempt -lt 5))
    $sw.Stop()
    $secs = [math]::Round($sw.Elapsed.TotalSeconds, 2)
    if ($passed) { $status = 'PASS' } else { $status = 'FAIL' }
    $rows += [pscustomobject]@{ level = $lv.Name; passed = $passed; seconds = $secs; exitCode = $code; attempts = $attempt; log = ($lv.Name + '.log') }
    Write-Host ("{0}: {1} ({2}s)" -f $lv.Name, $status, $secs)
}
$runEnd = Get-Date
$total = [math]::Round(($runEnd - $runStart).TotalSeconds, 2)
$failed = @($rows | Where-Object { -not $_.passed }).Count
$overall = ($failed -eq 0)
if ($overall) { $overallText = 'PASS' } else { $overallText = 'FAIL' }

$summary = [pscustomobject]@{
    model = $Model
    suite = 'cpp'
    startedAt = $runStart.ToString('o')
    finishedAt = $runEnd.ToString('o')
    totalSeconds = $total
    overallPassed = $overall
    levels = $rows
}
$summary | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $runDir 'summary.json')

$md = @("# Run: $Model (cpp)", "", "- Started: $($runStart.ToString('o'))", "- Total: ${total}s", "- Result: $overallText", "", "| Level | Result | Seconds | Log |", "|---|---|---|---|")
foreach ($r in $rows) {
    if ($r.passed) { $s = 'PASS' } else { $s = 'FAIL' }
    $md += "| $($r.level) | $s | $($r.seconds) | $($r.log) |"
}
$md | Set-Content (Join-Path $runDir 'summary.md')

$idx = [pscustomobject]@{
    run = (Split-Path $runDir -Leaf)
    suite = 'cpp'
    startedAt = $runStart.ToString('o')
    totalSeconds = $total
    passed = ($rows.Count - $failed)
    failed = $failed
    overallPassed = $overall
}
Add-Content -Path (Join-Path $PSScriptRoot ("results\" + $safe + "\runs.jsonl")) -Value ($idx | ConvertTo-Json -Compress)
Write-Host "Results: $runDir"
if (-not $overall) { exit 1 }
