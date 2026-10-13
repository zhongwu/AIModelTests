# AIModelTests — 5-Level AI Coding Benchmark (C#)

Tests code generation across 5 difficulties: `easy` → `hardest`.
Each level is a self-contained .NET 8 console project (BCL only, no NuGet).
Verified with .NET 10 SDK; all levels pass with 0 warnings.

| Level | Dir | Topic | Skills Tested | Target Time |
|-------|-----|-------|---------------|-------------|
| 1 Easy | `csharp/Level1.Easy/` | String/sequence utils | BCL, null guards, edge cases | 10 min |
| 2 Medium | `csharp/Level2.Medium/` | Generic LRU cache O(1) | generics, `Dictionary`+`LinkedList` | 30 min |
| 3 Hard | `csharp/Level3.Hard/` | Task-based thread pool | threads, TCS, exceptions, Dispose | 60 min |
| 4 Harder | `csharp/Level4.Harder/` | `PooledList<T>` + `ArrayPool` | `Span`, pooling, `IDisposable`, enumerators | 90 min |
| 5 Hardest | `csharp/Level5.Hardest/` | Lock-free bounded MPMC queue | `Interlocked`/`Volatile`, contention | 120+ min |

## How to test a model

Give the model ONLY `TASK.md` + `Starter.cs.txt`. The model must produce `Solution.cs`.
Then compile and run:

```powershell
# single level
dotnet run --project csharp\Level1.Easy\Level1.Easy.csproj

# everything (Release)
powershell -ExecutionPolicy Bypass -File csharp\run_all.ps1
```

## Scoring

- L1 pass = basic BCL/nullability.
- L2 pass = data-structure design with generics.
- L3 pass = real-world concurrency.
- L4 pass = senior memory-management mastery.
- L5 pass = expert lock-free. Most models fail here.

See each `TASK.md` for detailed rubric.

## Benchmarking a model (archived results)

Run a full suite for one model; per-level logs, timings, and summaries are
archived under `results/<model>/<timestamp>/`:

```powershell
powershell -ExecutionPolicy Bypass -File cpp\run_model.ps1 -Model "my-model"
powershell -ExecutionPolicy Bypass -File csharp\run_model.ps1 -Model "my-model"
# bash (g++/dotnet): bash cpp/run_model.sh "my-model"; bash csharp/run_model.sh "my-model"
```

Each run records wall time per level (build + test) and writes:

- `results/<model>/<timestamp>/` — `<level>.log`, `summary.json`, `summary.md`
  (C++ runs also keep the tested binaries in `bin/`)
- `results/<model>/runs.jsonl` — one-line history per run (run id, totals,
  pass/fail) for comparing models and tracking regressions over time

`summary.json` fields: `model`, `suite`, `startedAt`/`finishedAt`,
`totalSeconds`, `overallPassed`, and per-level `passed`/`seconds`/`exitCode`.

## Legacy C++ suite

The original C++ suite (`cpp/level1_easy/` … `cpp/level5_hardest/`, verified with
MSVC `cl /EHsc /std:c++17`) is kept as-is. Run it with `cpp\run_all.ps1`
(Windows, auto-finds VS) or `bash cpp/run_all.sh` (g++).
