#pragma once
#include <condition_variable>
#include <functional>
#include <future>
#include <mutex>
#include <queue>
#include <stdexcept>
#include <thread>
#include <tuple>
#include <type_traits>
#include <utility>
#include <vector>

// Reference solution (header-only). Test includes this as "solution.hpp"
// via -include or copy. Kept here as solution_impl.hpp for clarity.
class ThreadPool {
public:
    explicit ThreadPool(size_t numThreads) : stop_(false) {
        if (numThreads == 0) {
            numThreads = std::thread::hardware_concurrency();
            if (numThreads == 0) numThreads = 4;
        }
        for (size_t i = 0; i < numThreads; ++i) {
            workers_.emplace_back([this] {
                for (;;) {
                    std::function<void()> task;
                    {
                        std::unique_lock<std::mutex> lk(mutex_);
                        cv_.wait(lk, [this] { return stop_ || !tasks_.empty(); });
                        if (stop_ && tasks_.empty()) return;
                        task = std::move(tasks_.front());
                        tasks_.pop();
                    }
                    task();
                }
            });
        }
    }

    ~ThreadPool() { shutdown(); }

    ThreadPool(const ThreadPool&) = delete;
    ThreadPool& operator=(const ThreadPool&) = delete;

    template <class F, class... Args>
    auto enqueue(F&& f, Args&&... args)
        -> std::future<std::invoke_result_t<std::decay_t<F>, std::decay_t<Args>...>> {
        using Ret = std::invoke_result_t<std::decay_t<F>, std::decay_t<Args>...>;
        // Bind via shared tuple + apply so move-only args work (std::bind would copy).
        auto bound = std::make_shared<
            std::tuple<std::decay_t<F>, std::decay_t<Args>...>>(
            std::forward<F>(f), std::forward<Args>(args)...);
        auto task = std::make_shared<std::packaged_task<Ret()>>(
            [bound]() mutable -> Ret {
                return std::apply(
                    [](auto& fn, auto&... a) -> Ret {
                        return std::invoke(std::move(fn), std::move(a)...);
                    },
                    *bound);
            });
        std::future<Ret> fut = task->get_future();
        {
            std::lock_guard<std::mutex> lk(mutex_);
            if (stop_) throw std::runtime_error("enqueue on stopped ThreadPool");
            tasks_.emplace([task]() { (*task)(); });
        }
        cv_.notify_one();
        return fut;
    }

    void shutdown() {
        {
            std::lock_guard<std::mutex> lk(mutex_);
            if (stop_) return;
            stop_ = true;
        }
        cv_.notify_all();
        for (auto& w : workers_) if (w.joinable()) w.join();
        workers_.clear();
    }

private:
    std::vector<std::thread> workers_;
    std::queue<std::function<void()>> tasks_;
    std::mutex mutex_;
    std::condition_variable cv_;
    bool stop_;
};
