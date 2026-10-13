$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

# Locate vcvars64.bat (prefers vswhere latest, falls back to VS2022 Community path)
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

$vcvars = Find-VcVars
Write-Host "Using $vcvars"
$tmp = $env:TEMP

function Invoke-BuildTest($compileArgs, $exe) {
    # Run compile+test inside a VS-initialized cmd shell so cl.exe + includes resolve
    $cmd = "call `"$vcvars`" >nul && $compileArgs && `"$exe`""
    cmd.exe /c $cmd
    if ($LASTEXITCODE -ne 0) { throw "FAILED: $cmd" }
}

Write-Host "=== Level 1 (easy) ==="
Invoke-BuildTest "cl /EHsc /std:c++17 level1_easy\test.cpp level1_easy\solution.cpp /Fe:$tmp\test1.exe" "$tmp\test1.exe"

Write-Host "=== Level 2 (medium) ==="
Invoke-BuildTest "cl /EHsc /std:c++17 level2_medium\test.cpp level2_medium\solution.cpp /Fe:$tmp\test2.exe" "$tmp\test2.exe"

Write-Host "=== Level 3 (hard) ==="
Invoke-BuildTest "cl /EHsc /std:c++17 level3_hard\test.cpp /Fe:$tmp\test3.exe" "$tmp\test3.exe"

Write-Host "=== Level 4 (harder) ==="
Invoke-BuildTest "cl /EHsc /std:c++17 level4_harder\test.cpp /Fe:$tmp\test4.exe" "$tmp\test4.exe"

Write-Host "=== Level 5 (hardest) ==="
Invoke-BuildTest "cl /EHsc /std:c++17 /O2 level5_hardest\test.cpp /Fe:$tmp\test5.exe" "$tmp\test5.exe"

Write-Host "ALL LEVELS PASSED"
