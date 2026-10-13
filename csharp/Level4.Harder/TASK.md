# Level 4 — Harder (C#): `PooledList<T>` with `ArrayPool`

## Prompt for the AI model

> Implement an `ArrayPool<T>`-backed list (see `Starter.cs.txt`). BCL only, no NuGet.

### API (keep exact public surface)

```csharp
public sealed class PooledList<T> : IDisposable, IEnumerable<T>
{
    public PooledList();
    public PooledList(int capacity);
    public PooledList(IEnumerable<T> items); // null -> ArgumentNullException
    public int Count { get; }
    public int Capacity { get; }
    public T this[int index] { get; set; }   // out of range -> ArgumentOutOfRangeException
    public void Add(T item);
    public void AddRange(IEnumerable<T> items); // null -> ArgumentNullException
    public void Insert(int index, T item);       // 0..Count; else ArgumentOutOfRangeException
    public void RemoveAt(int index);
    public void Clear();              // keeps rented buffer
    public void EnsureCapacity(int n); // never shrinks; negative -> ArgumentOutOfRangeException
    public void TrimExcess();
    public Span<T> AsSpan();          // live view; mutating it mutates the list
    public T[] ToArray();
    public void Dispose();            // returns buffer to pool; idempotent
}
```

### Rules
- Back storage with `ArrayPool<T>.Shared.Rent/Return`. `Capacity` = rented length
  (`0` when empty; otherwise pool-bucketed, so `>=` requested). Growth ~2x.
  `EnsureCapacity` never shrinks. `TrimExcess` shrinks toward `Count`
  (returns old buffer). `Clear` keeps capacity but releases
  references (`Array.Clear` when `T` contains references).
- After `Dispose`: every member throws `ObjectDisposedException` (except
  `Dispose` itself, which is idempotent). Buffers must be returned exactly once.
- `foreach` enumerator must detect mutation during enumeration and throw
  `InvalidOperationException`.
- Must work for value types, `string`, and nullable element types.
- No leaks: rented arrays always returned (use `Return(..., clearArray: true)`
  when `T` contains references).

## Evaluation
`dotnet run` — growth, copy independence, Insert/RemoveAt, Ensure/Trim,
Clear-keeps-capacity, Dispose semantics, enumerator invalidation, Span,
`string` + struct elements.

## Rubric
- Pass: all green + arrays rented (not `new T[]` per Add) + pool returned exactly once.
- Partial: works for `int` but breaks for reference types / after Dispose.
- Fail: use-after-Dispose silently works, double-return to pool, enumerator misses mutation.
