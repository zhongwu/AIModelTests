# Test a local Ollama model on all cpp + csharp levels and archive results.
# Usage: powershell -ExecutionPolicy Bypass -File run_model_ai.ps1 -Model "gemma4:12b"
# Reference solutions are backed up and restored (try/finally); model IO is
# copied into each suite's run dir for audit.
param(
    [Parameter(Position = 0)]
    [string]$Model = "gemma4:12b",
    [string]$OllamaHost = "http://localhost:11434"
)
$ErrorActionPreference = "Stop"

function Sanitize-ModelName([string]$n) {
    $clean = $n.Trim()
    foreach ($c in [IO.Path]::GetInvalidFileNameChars()) { $clean = $clean.Replace($c, '-') }
    foreach ($c in @(' ', '/', '\', ':', '*', '?', '"', '<', '>', '|')) { $clean = $clean.Replace($c, '-') }
    while ($clean.Contains('--')) { $clean = $clean.Replace('--', '-') }
    if ([string]::IsNullOrWhiteSpace($clean)) { $clean = 'unnamed' }
    return $clean
}

function Extract-Code([string]$t) {
    if ([string]::IsNullOrWhiteSpace($t)) { return '' }
    $s = $t.Trim()
    $m = [regex]::Match($s, '(?s)```(?:[a-zA-Z+#]*\s*)?(.*?)```')
    if ($m.Success) { $s = $m.Groups[1].Value.Trim() }
    $lines = $s -split "`r?`n"
    if ($lines.Count -gt 0 -and $lines[0] -match '^\s*```') {
        if ($lines.Count -gt 1) { $lines = $lines[1..($lines.Count - 1)] } else { $lines = @() }
    }
    if ($lines.Count -gt 0 -and $lines[-1] -match '^\s*```\s*$') {
        if ($lines.Count -gt 1) { $lines = $lines[0..($lines.Count - 2)] } else { $lines = @() }
    }
    $code = ($lines -join "`n").Trim()
    if ($code -eq '') { return '' }
    return $code + "`n"
}

function Invoke-Model([string]$prompt) {
    $body = @{
        model = $Model
        prompt = $prompt
        stream = $false
        # NOTE: gemma4 is a thinking model; with thinking on, reasoning tokens can
        # fill the whole context window and leave `response` empty. Disable it so
        # the full window is available for the answer.
        think = $false
        options = @{ temperature = 0; num_predict = 16384 }
    } | ConvertTo-Json -Depth 6
    $resp = Invoke-RestMethod -Uri "$OllamaHost/api/generate" -Method Post `
        -Body $body -ContentType 'application/json' -TimeoutSec 1500
    return [string]$resp.response
}

$root = $PSScriptRoot
$levels = @(
    @{ Suite = 'cpp'; Dir = 'cpp/level1_easy';    Lang = 'C++'; PromptFiles = @('TASK.md', 'starter.hpp', 'starter.cpp'); Deliverable = 'cpp/level1_easy/solution.cpp' },
    @{ Suite = 'cpp'; Dir = 'cpp/level2_medium';  Lang = 'C++'; PromptFiles = @('TASK.md', 'starter.hpp', 'starter.cpp'); Deliverable = 'cpp/level2_medium/solution.cpp' },
    @{ Suite = 'cpp'; Dir = 'cpp/level3_hard';    Lang = 'C++'; PromptFiles = @('TASK.md', 'starter.hpp'); Deliverable = 'cpp/level3_hard/solution.hpp' },
    @{ Suite = 'cpp'; Dir = 'cpp/level4_harder';  Lang = 'C++'; PromptFiles = @('TASK.md', 'starter.hpp'); Deliverable = 'cpp/level4_harder/solution.hpp' },
    @{ Suite = 'cpp'; Dir = 'cpp/level5_hardest'; Lang = 'C++'; PromptFiles = @('TASK.md', 'starter.hpp'); Deliverable = 'cpp/level5_hardest/solution.hpp' },
    @{ Suite = 'csharp'; Dir = 'csharp/Level1.Easy';    Lang = 'C#'; PromptFiles = @('TASK.md', 'Starter.cs.txt'); Deliverable = 'csharp/Level1.Easy/Solution.cs' },
    @{ Suite = 'csharp'; Dir = 'csharp/Level2.Medium';  Lang = 'C#'; PromptFiles = @('TASK.md', 'Starter.cs.txt'); Deliverable = 'csharp/Level2.Medium/Solution.cs' },
    @{ Suite = 'csharp'; Dir = 'csharp/Level3.Hard';    Lang = 'C#'; PromptFiles = @('TASK.md', 'Starter.cs.txt'); Deliverable = 'csharp/Level3.Hard/Solution.cs' },
    @{ Suite = 'csharp'; Dir = 'csharp/Level4.Harder';  Lang = 'C#'; PromptFiles = @('TASK.md', 'Starter.cs.txt'); Deliverable = 'csharp/Level4.Harder/Solution.cs' },
    @{ Suite = 'csharp'; Dir = 'csharp/Level5.Hardest'; Lang = 'C#'; PromptFiles = @('TASK.md', 'Starter.cs.txt'); Deliverable = 'csharp/Level5.Hardest/Solution.cs' }
)

# Back up reference solutions.
$backupRoot = Join-Path ([IO.Path]::GetTempPath()) ("aimodel-backup\" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $backupRoot | Out-Null
foreach ($lv in $levels) {
    $src = Join-Path $root $lv.Deliverable
    $dst = Join-Path $backupRoot $lv.Deliverable
    New-Item -ItemType Directory -Path (Split-Path $dst) -Force | Out-Null
    Copy-Item $src $dst
}

$ioRoot = Join-Path ([IO.Path]::GetTempPath()) ("aimodel-io\" + (Sanitize-ModelName $Model) + "\" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $ioRoot | Out-Null

try {
    foreach ($lv in $levels) {
        $d = Join-Path $root $lv.Dir
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.AppendLine("You are an expert $($lv.Lang) programmer. Complete the task below.")
        [void]$sb.AppendLine("RULES:")
        [void]$sb.AppendLine("- Output ONLY the complete final content of the file $($lv.Deliverable | Split-Path -Leaf).")
        [void]$sb.AppendLine("- No markdown fences, no explanations, no extra text before or after the code.")
        [void]$sb.AppendLine("- Keep every #include / using and the exact public API. Implement every TODO so all tests pass.")
        foreach ($f in $lv.PromptFiles) {
            [void]$sb.AppendLine()
            [void]$sb.AppendLine("--- FILE: $f ---")
            [void]$sb.AppendLine([IO.File]::ReadAllText((Join-Path $d $f)))
        }
        $prompt = $sb.ToString()
        $tag = "$($lv.Suite)/$($lv.Dir | Split-Path -Leaf)"
        Set-Content -Path (Join-Path $ioRoot ($tag.Replace('/', '_') + '.prompt.txt')) -Value $prompt
        Write-Host "Generating $tag ..."
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $raw = Invoke-Model $prompt
        }
        catch {
            Write-Host "  MODEL CALL FAILED: $_"
            $raw = ''
        }
        $sw.Stop()
        Set-Content -Path (Join-Path $ioRoot ($tag.Replace('/', '_') + '.raw.txt')) -Value $raw
        $code = Extract-Code $raw
        if ($code -eq '') { $code = "#error MODEL PRODUCED NO OUTPUT`n" }
        Set-Content -Path (Join-Path $root $lv.Deliverable) -Value $code -NoNewline:$false
        Write-Host ("  done in {0}s, {1} chars extracted" -f [math]::Round($sw.Elapsed.TotalSeconds), $code.Length)
    }

    foreach ($suite in @('cpp', 'csharp')) {
        Write-Host "=== Running $suite suite ==="
        powershell -ExecutionPolicy Bypass -File (Join-Path $root "$suite\run_model.ps1") -Model $Model
        Write-Host "$suite suite exit: $LASTEXITCODE"
    }
}
finally {
    foreach ($lv in $levels) {
        Copy-Item (Join-Path $backupRoot $lv.Deliverable) (Join-Path $root $lv.Deliverable) -Force
    }
    Write-Host "Reference solutions restored."
}

# Attach model IO to each suite's latest run dir for audit.
$safe = Sanitize-ModelName $Model
foreach ($suite in @('cpp', 'csharp')) {
    $resDir = Join-Path $root "$suite\results\$safe"
    if (-not (Test-Path $resDir)) { continue }
    $latest = Get-ChildItem $resDir -Directory | Sort-Object Name -Descending | Select-Object -First 1
    if ($null -eq $latest) { continue }
    $dest = Join-Path $latest.FullName 'model_io'
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    Copy-Item (Join-Path $ioRoot '*') $dest -Force
    Write-Host "Model IO archived to $dest"
}
Write-Host "DONE. Model: $Model"
