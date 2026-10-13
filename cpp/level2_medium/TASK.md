# Level 2 — Medium: LRU Cache O(1)

## Prompt for the AI model

> Implement an LRU (Least Recently Used) cache in `lru_cache.h`.
> Starter declares `class LRUCache`. Fill in the `TODO` methods so all tests pass.
> Only C++17 STL allowed.

### API (`starter.hpp` / `lru_cache.h`)

```cpp
class LRUCache {
public:
    explicit LRUCache(int capacity);
    int get(int key);            // return -1 if missing; else mark most-recent
    void put(int key, int value); // insert/update + mark most-recent; evict LRU if over capacity
};
```

### Rules
- `get` and `put` must be O(1) average. Expected: `unordered_map` + doubly-linked list.
- `capacity <= 0`: cache stores nothing (`get` always -1, `put` no-op).
- `put` on existing key updates value and recency (no size growth).
- Eviction removes the *least* recently used entry when size would exceed capacity.
- Recency order: every successful `get` and every `put` makes that key most-recent.

Example:
```
LRUCache c(2);
c.put(1,1); c.put(2,2); c.get(1); // -> 1
c.put(3,3); // evicts 2
c.get(2);   // -> -1
```

### Constraints
- No memory leaks, no raw `new` without RAII (use STL containers).
- Must compile with `-Wall -Wextra` without warnings.

## Evaluation
`g++ -std=c++17 -O2 -Wall -Wextra -o test2 test.cpp solution.cpp && ./test2`

## Rubric
- Pass: all asserts green + O(1) design (check: uses hash map + list, no linear scan).
- Partial: correct behavior but O(n).
- Fail: wrong eviction order, crash on capacity 0.
