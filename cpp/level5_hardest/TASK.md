# Level 5 — Hardest: Lock-Free Bounded MPMC Queue

## Prompt for the AI model

> Implement a **bounded multi-producer multi-consumer (MPMC) lock-free queue**
> (Dmitry Vyukov's algorithm) in `mpmc_queue.hpp`. Skeleton in `starter.hpp`.

### API (keep exact public interface, `T` = element type)

```cpp
template <typename T>
class MpmcQueue {
public:
    explicit MpmcQueue(size_t capacity); // capacity = max elements; rounded up to pow2 internally
    ~MpmcQueue();
    MpmcQueue(const MpmcQueue&) = delete;
    MpmcQueue& operator=(const MpmcQueue&) = delete;

    bool try_enqueue(const T& v); // false if full
    bool try_enqueue(T&& v);
    bool try_dequeue(T& out);      // false if empty
    size_t capacity() const;
    bool empty() const;  // approximate under concurrency; exact when quiescent
    size_t size() const; // approximate; exact when quiescent
};
```

### Rules
- Bounded, fixed capacity, ring buffer with per-cell sequence numbers.
- Lock-free using only `std::atomic<size_t>` head/tail + per-cell sequence.
  **No mutexes, no spinlocks, no blocking.**
- Correct `memory_order`: `relaxed` for counters where possible, `acquire`/`release`
  for publish/consume handoff. Must be correct under `-O2` on x86 + ARM model.
- Support non-trivial + move-only `T` (placement-new, explicit destroy).
- `capacity()` returns usable slots. Internal mask = pow2 ceiling. `capacity < 1` → throw.
- `try_enqueue` fails (false) only when full; `try_dequeue` fails only when empty.
- Single header, C++17, no external deps.
- Destructor drains + frees; no leaks.

Reference algorithm (Vyukov 2010, `1024cores.net`):
each cell has `sequence_`; enqueue at `pos = tail.fetch_add(1)`, wait until
`cell.sequence == pos`, then construct + `sequence.store(pos+1, release)`;
dequeue symmetric with `head`. Wrap `pos` with `mask`.

### Constraints
- Must pass single-threaded FIFO tests AND 4P+4C hammer test with 200k items
  (no lost/duplicated items, each value consumed exactly once).
- Must pass `-fsanitize=thread` with no data-race reports on atomics
  (correct ordering, no raw racy access to cell storage).

## Evaluation
`g++ -std=c++17 -O2 -Wall -Wextra -pthread -o test5 test.cpp && ./test5`

## Rubric
- Pass: all green incl. contention test, no mutex in code (`grep -i mutex` empty),
  clean TSan.
- Partial: SPSC correct but MPMC loses items.
- Fail: deadlock, ABA/wrap bug, use-after-free, data race.
- This level is *expected* to fail on most models — that is the point.
