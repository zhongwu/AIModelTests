# Level 3 — Hard: ThreadPool with Futures

## Prompt for the AI model

> Implement a general-purpose thread pool in `thread_pool.hpp`.
> Starter skeleton is given. Fill in the `TODO`s so all tests pass.

### API (`thread_pool.hpp` — keep exact public interface)

```cpp
#pragma once
// ... includes ...
class ThreadPool {
public:
    explicit ThreadPool(size_t numThreads);
    ~ThreadPool();
    // No copy
    ThreadPool(const ThreadPool&) = delete;
    ThreadPool& operator=(const ThreadPool&) = delete;

    template <class F, class... Args>
    auto enqueue(F&& f, Args&&... args)
        -> std::future<std::invoke_result_t<F, Args...>>;

    void shutdown(); // idempotent, waits for all tasks
};
```

Full skeleton with private members (`workers_`, `tasks_`, `mutex_`, `cv_`, `stop_`)
is in `starter.hpp`. You may add private helpers but must not change the public API.

### Rules
- `enqueue` returns a `std::future` holding the task result; exceptions thrown
  by the task must be delivered through the future (use `std::packaged_task`).
- Perfect-forward `f` and `args` (support move-only args, e.g. `unique_ptr`).
- Constructor spawns `numThreads` workers; `numThreads == 0` means
  `std::thread::hardware_concurrency()` (fallback 4 if that is 0).
- Destructor calls `shutdown()` if not already shut down (no hang, no crash, no leak).
- `shutdown()` is idempotent; `enqueue` after shutdown/stop throws `std::runtime_error`.
- Workers wait on `condition_variable`, handle spurious wakeups, drain queue on shutdown
  (all enqueued tasks run before workers exit).
- Thread-safe: concurrent `enqueue` from multiple threads must work.

### Constraints
- C++17 only, no external deps. Compile with `-pthread`.
- No busy-wait. No data races (must pass `-fsanitize=thread` ideally).

## Evaluation
`g++ -std=c++17 -O2 -Wall -Wextra -pthread -o test3 test.cpp solution_impl.hpp` (header-only)
`./test3` — includes parallel sum, exception propagation, move-only args,
post-shutdown throw, destructor-drain, and multi-producer stress.

## Rubric
- Pass: all green, no deadlock, no race, clean `-Wall -Wextra`.
- Partial: works single-threaded but breaks under contention.
- Fail: deadlock, lost tasks, swallowed exceptions, crash on shutdown.
