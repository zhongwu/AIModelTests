# Level 5 — Hardest (C#): Lock-Free Bounded MPMC Queue

## Prompt for the AI model

> Implement a **bounded multi-producer multi-consumer lock-free queue**
> (Dmitry Vyukov's algorithm, C# port — see `Starter.cs.txt`). BCL only, no NuGet.

### API (keep exact public surface)

```csharp
public sealed class BoundedMpmcQueue<T>
{
    public BoundedMpmcQueue(int capacity); // <1 -> ArgumentOutOfRangeException; rounds up to pow2
    public int Capacity { get; }           // usable slots (>= requested)
    public bool IsEmpty { get; }           // exact when quiescent; approximate under concurrency
    public int Count { get; }              // exact when quiescent; approximate under concurrency
    public bool TryEnqueue(T item);        // false only when full
    public bool TryDequeue(out T result);  // false only when empty (result = default!)
}
```

### Rules
- Bounded ring buffer with per-cell sequence numbers (Vyukov 2010).
- Lock-free using only `Interlocked` + `Volatile`. **No `lock`, `Monitor`,
  `Mutex`, `Semaphore`, `BlockingCollection`, or `ConcurrentQueue`.**
- Correct publish/consume ordering: `Volatile.Read` for sequence handoff,
  `Volatile.Write` for publication, `Interlocked.CompareExchange` for
  head/tail claims. Must survive `-c Release` + ARM memory model reasoning
  (no raw racy reads of sequence/counters).
- Support reference types, value types, and nullable element types.
- `TryEnqueue` fails only when full; `TryDequeue` fails only when empty.
- Counters must be 64-bit (wrap-safe for the hammer test).

Reference algorithm: each cell has `sequence`; enqueue at `pos = tail`,
wait until `cell.sequence == pos`, CAS tail, store item,
`sequence = pos + 1` (release); dequeue mirrors with `head` and
`sequence = pos + mask + 1`. Index with `pos & mask`.

### Constraints
- Must pass single-threaded FIFO + 4P/4C hammer test with 200k items
  (no lost/duplicated items, each value dequeued exactly once).
- Grader greps for `\block\b`, `Monitor`, `Mutex`, `Semaphore`,
  `BlockingCollection`, or `ConcurrentQueue` as whole words
  (`Interlocked` is required and does not count) — any hit = fail.

## Evaluation
`dotnet run -c Release` — contention test guarded by a 60s timeout.

## Rubric
- Pass: all green incl. hammer test, no locks, no data loss.
- Partial: SPSC correct but MPMC loses items.
- Fail: deadlock, wrap bug, lost/duplicated items, blocking primitives.
- Expected to fail on most models — that is the point.
