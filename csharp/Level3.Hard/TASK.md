# Level 3 — Hard (C#): Task-Based Thread Pool

## Prompt for the AI model

> Implement a general-purpose thread pool (see `Starter.cs.txt`). BCL only, no NuGet.

### API (keep exact public surface)

```csharp
public sealed class SimpleThreadPool : IDisposable
{
    public SimpleThreadPool(int numThreads); // <=0 -> Environment.ProcessorCount (fallback 4)
    public Task<T> Enqueue<T>(Func<T> fn);   // Task completes with result; fn exceptions surface via Task
    public Task Enqueue(Action action);      // Task completes when action finishes
    public void Dispose();                   // drains queued work, joins workers, idempotent
}
```

### Rules
- Constructor spawns `numThreads` background workers.
- `Enqueue` returns a `Task` (use `TaskCompletionSource` with
  `RunContinuationsAsynchronously`); exceptions from `fn`/`action` must be
  observable via the `Task` (test awaits with timeout and expects the original
  exception type). Support closures capturing locals.
- `Dispose` drains: all queued work runs before workers exit. Idempotent.
- `Enqueue` after dispose throws `ObjectDisposedException`.
- Workers must not busy-spin; no deadlock; concurrent `Enqueue` from many
  threads must work. Null `fn`/`action` -> `ArgumentNullException`.

## Evaluation
`dotnet run` — includes parallel sum, void side effects, exception
propagation, closure capture, post-dispose throw, dispose-drains, and
multi-producer stress. Any hang (guarded by timeouts) = fail.

## Rubric
- Pass: all green, no deadlock, exceptions propagate with original type.
- Partial: works single-threaded, breaks under contention.
- Fail: deadlock, lost tasks, swallowed exceptions, crash on Dispose.
