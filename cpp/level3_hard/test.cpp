// Level 3 tests. Includes the implementation under test.
// When grading an AI model: copy the model's header over solution.hpp content
// (or compile with the model's file). Reference: g++ ... test.cpp -pthread
#include "solution.hpp"

#include <atomic>
#include <chrono>
#include <iostream>
#include <memory>
#include <numeric>
#include <stdexcept>
#include <vector>

#define CHECK(cond) do { \
    if (!(cond)) { std::cerr << "FAIL line " << __LINE__ << ": " #cond "\n"; std::exit(1); } \
} while (0)

int main() {
    // 1. Parallel sum
    {
        ThreadPool pool(4);
        std::vector<std::future<int>> futs;
        for (int i = 0; i < 100; ++i)
            futs.push_back(pool.enqueue([i] { return i * i; }));
        long sum = 0;
        for (auto& f : futs) sum += f.get();
        long expect = 0;
        for (int i = 0; i < 100; ++i) expect += i * i;
        CHECK(sum == expect);
    }
    // 2. Void tasks + side effects
    {
        ThreadPool pool(4);
        std::atomic<int> n{0};
        std::vector<std::future<void>> futs;
        for (int i = 0; i < 200; ++i)
            futs.push_back(pool.enqueue([&n] { n.fetch_add(1); }));
        for (auto& f : futs) f.get();
        CHECK(n.load() == 200);
    }
    // 3. Exception propagation
    {
        ThreadPool pool(2);
        auto f = pool.enqueue([]() -> int { throw std::runtime_error("boom"); return 42; });
        bool caught = false;
        try { f.get(); } catch (const std::runtime_error& e) {
            caught = std::string(e.what()) == "boom";
        }
        CHECK(caught);
    }
    // 4. Move-only argument (unique_ptr)
    {
        ThreadPool pool(2);
        auto f = pool.enqueue([](std::unique_ptr<int> p) { return *p + 1; },
                              std::make_unique<int>(41));
        CHECK(f.get() == 42);
    }
    // 5. shutdown() drains queue; enqueue-after-shutdown throws
    {
        ThreadPool pool(2);
        std::atomic<int> n{0};
        std::vector<std::future<void>> futs;
        for (int i = 0; i < 50; ++i)
            futs.push_back(pool.enqueue([&n] { n.fetch_add(1); }));
        pool.shutdown();
        for (auto& f : futs) f.get();
        CHECK(n.load() == 50);
        bool threw = false;
        try { pool.enqueue([] {}); } catch (const std::runtime_error&) { threw = true; }
        CHECK(threw);
        pool.shutdown(); // idempotent, must not hang/crash
    }
    // 6. Destructor drains (no explicit shutdown)
    {
        std::atomic<int> n{0};
        {
            ThreadPool pool(2);
            for (int i = 0; i < 50; ++i)
                pool.enqueue([&n] { n.fetch_add(1); });
            // no get(), no shutdown() — destructor must run all tasks
        }
        // tasks were fire-and-forget; give a bounded wait for drain-on-destroy
        // (destructor joins, so by here count must be complete)
        CHECK(n.load() == 50);
    }
    // 7. Multi-producer stress
    {
        ThreadPool pool(8);
        std::atomic<long> sum{0};
        std::vector<std::thread> producers;
        std::vector<std::future<void>> futs;
        std::mutex fm;
        for (int p = 0; p < 4; ++p) {
            producers.emplace_back([&] {
                for (int i = 0; i < 250; ++i) {
                    auto f = pool.enqueue([&sum] { sum.fetch_add(1); });
                    std::lock_guard<std::mutex> lk(fm);
                    futs.push_back(std::move(f));
                }
            });
        }
        for (auto& t : producers) t.join();
        for (auto& f : futs) f.get();
        CHECK(sum.load() == 1000);
    }
    // 8. numThreads == 0 falls back (must not crash/hang)
    {
        ThreadPool pool(0);
        CHECK(pool.enqueue([] { return 7; }).get() == 7);
    }

    std::cout << "Level 3: ALL TESTS PASSED\n";
    return 0;
}
