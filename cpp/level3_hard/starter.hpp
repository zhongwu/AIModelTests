#pragma once
#include <condition_variable>
#include <functional>
#include <future>
#include <mutex>
#include <queue>
#include <stdexcept>
#include <thread>
#include <type_traits>
#include <utility>
#include <vector>

// AI deliverable: fill in the TODO bodies. Keep the public API identical.
class ThreadPool {
public:
    explicit ThreadPool(size_t numThreads) {
        // TODO: spawn workers; handle numThreads==0 -> hardware_concurrency (fallback 4)
    }

    ~ThreadPool() {
        // TODO: shutdown if needed
    }

    ThreadPool(const ThreadPool&) = delete;
    ThreadPool& operator=(const ThreadPool&) = delete;

    template <class F, class... Args>
    auto enqueue(F&& f, Args&&... args)
        -> std::future<std::invoke_result_t<F, Args...>> {
        // TODO: packaged_task + queue + notify; throw if stopped
        using Ret = std::invoke_result_t<F, Args...>;
        std::promise<Ret> p;
        (void)p;
        return p.get_future(); // placeholder
    }

    void shutdown() {
        // TODO: idempotent stop + join
    }

private:
    // TODO: add workers_, tasks_, mutex_, cv_, stop_ flag
};
