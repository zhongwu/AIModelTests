# Level 2 — Medium (C#): Generic LRU Cache O(1)

## Prompt for the AI model

> Implement a generic LRU cache (see `Starter.cs.txt`). BCL only, no NuGet.

### API (keep exact public surface)

```csharp
public sealed class LruCache<TKey, TValue> where TKey : notnull
{
    public LruCache(int capacity);
    public int Capacity { get; }
    public int Count { get; }
    public bool TryGet(TKey key, out TValue value); // false if missing; else mark most-recent
    public void Put(TKey key, TValue value);        // insert/update + mark most-recent; evict LRU if over capacity
    public bool Remove(TKey key);
    public bool ContainsKey(TKey key);              // must NOT change recency
    public void Clear();
}
```

### Rules
- `TryGet` and `Put` must be O(1) average (`Dictionary` + `LinkedList`).
- `capacity <= 0`: store nothing (`TryGet` always false, `Put` no-op, `Count == 0`).
- `Put` on existing key updates value + recency without growing.
- Eviction removes the *least* recently used entry when size would exceed capacity.
- `ContainsKey` / failed `TryGet` must not affect recency. Null key -> throw `ArgumentNullException`.
- No leaks of internal nodes after `Remove`/`Clear`/eviction.

Example:
```
var c = new LruCache<int,int>(2);
c.Put(1,1); c.Put(2,2); c.TryGet(1, out _); // 1 now MRU
c.Put(3,3); // evicts 2
```

## Evaluation
`dotnet run` — all asserts green = pass.

## Rubric
- Pass: behavior + O(1) design (hash map + linked list, no linear scan).
- Partial: correct but O(n).
- Fail: wrong eviction order, `ContainsKey` disturbs recency, crash on capacity 0.
