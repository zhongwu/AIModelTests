$ErrorActionPreference = "Stop"

$levels = @("Level1.Easy", "Level2.Medium", "Level3.Hard", "Level4.Harder", "Level5.Hardest")
foreach ($lv in $levels) {
    Write-Host "=== $lv ==="
    dotnet run -c Release --project "$PSScriptRoot\$lv\$lv.csproj"
    if ($LASTEXITCODE -ne 0) { throw "$lv FAILED" }
}
Write-Host "ALL C# LEVELS PASSED"
