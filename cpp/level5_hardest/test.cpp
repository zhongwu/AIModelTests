// Level 5 tests. Includes implementation under test.
#include "solution.hpp"

#include <atomic>
#include <chrono>
#include <iostream>
#include <memory>
#include <string>
#include <thread>
#include <vector>

#define CHECK(cond) do { \
    if (!(cond)) { std::cerr << "FAIL line " << __LINE__ << ": " #cond "\n"; std::exit(1); } \
} while (0)

int main() {
    // 1. Basic FIFO single-threaded
    {
        MpmcQueue<int> q(8);
        CHECK(q.empty() && q.size() == 0);
        CHECK(q.capacity() >= 8);
        for (int i = 0; i < 8; ++i) CHECK(q.try_enqueue(i));
        CHECK(!q.try_enqueue(99)); // full
        CHECK(q.size() == 8);
        for (int i = 0; i < 8; ++i) {
            int v = -1;
            CHECK(q.try_dequeue(v));
            CHECK(v == i);
        }
        int v;
        CHECK(!q.try_dequeue(v)); // empty
        CHECK(q.empty());
    }
    // 2. Wrap-around (reuse slots many times)
    {
        MpmcQueue<int> q(4);
        for (int round = 0; round < 100; ++round) {
            for (int i = 0; i < 4; ++i) CHECK(q.try_enqueue(round * 10 + i));
            for (int i = 0; i < 4; ++i) {
                int v = -1;
                CHECK(q.try_dequeue(v));
                CHECK(v == round * 10 + i);
            }
        }
    }
    // 3. Non-trivial type (std::string)
    {
        MpmcQueue<std::string> q(4);
        CHECK(q.try_enqueue(std::string("hello")));
        std::string s = "world";
        CHECK(q.try_enqueue(s));
        CHECK(q.try_enqueue(std::string("!")));
        std::string o;
        CHECK(q.try_dequeue(o) && o == "hello");
        CHECK(q.try_dequeue(o) && o == "world");
        CHECK(q.try_dequeue(o) && o == "!");
    }
    // 4. Move-only type
    {
        MpmcQueue<std::unique_ptr<int>> q(4);
        CHECK(q.try_enqueue(std::make_unique<int>(41)));
        std::unique_ptr<int> o;
        CHECK(q.try_dequeue(o));
        CHECK(o && *o == 41);
    }
    // 5. Non-power-of-2 capacity rounds up
    {
        MpmcQueue<int> q(7);
        CHECK(q.capacity() >= 7);
        for (int i = 0; i < (int)q.capacity(); ++i) CHECK(q.try_enqueue(i));
        CHECK(!q.try_enqueue(999));
    }
    // 6. Invalid capacity throws
    {
        bool threw = false;
        try { MpmcQueue<int> q(0); } catch (...) { threw = true; }
        CHECK(threw);
    }
    // 7. MPMC hammer: 4 producers x 50k + 4 consumers, each value exactly once
    {
        const int kProducers = 4, kPerProducer = 50000;
        const int kTotal = kProducers * kPerProducer;
        MpmcQueue<int> q(1024);
        std::atomic<int> produced{0};
        auto seen = std::make_unique<std::atomic<char>[]>(kTotal);
        for (int i = 0; i < kTotal; ++i) seen[i].store(0);
        std::atomic<int> consumed{0};
        std::atomic<bool> producersDone{false};
        std::atomic<bool> hammerFailed{false};
        auto hammerStart = std::chrono::steady_clock::now();
        auto hammerExpired = [&] {
            return std::chrono::steady_clock::now() - hammerStart > std::chrono::seconds(60);
        };

        std::vector<std::thread> prod;
        for (int p = 0; p < kProducers; ++p) {
            prod.emplace_back([&, p] {
                int base = p * kPerProducer;
                for (int i = 0; i < kPerProducer; ++i) {
                    int v = base + i;
                    while (!q.try_enqueue(v)) {
                        if (hammerExpired()) { hammerFailed.store(true); return; }
                        std::this_thread::yield();
                    }
                    produced.fetch_add(1);
                }
            });
        }
        std::vector<std::thread> cons;
        for (int c = 0; c < 4; ++c) {
            cons.emplace_back([&] {
                int v;
                while (consumed.load() < kTotal) {
                    if (q.try_dequeue(v)) {
                        CHECK(v >= 0 && v < kTotal);
                        char prev = seen[v].exchange(1);
                        CHECK(prev == 0); // duplicate delivery = fail
                        consumed.fetch_add(1);
                    } else {
                        if (producersDone.load() && q.empty()) break;
                        if (hammerExpired()) { hammerFailed.store(true); return; }
                        std::this_thread::yield();
                    }
                }
            });
        }
        for (auto& t : prod) t.join();
        producersDone.store(true);
        for (auto& t : cons) t.join();
        CHECK(produced.load() == kTotal);
        CHECK(consumed.load() == kTotal);
        CHECK(!hammerFailed.load()); // no thread gave up on the 60s guard
        for (int i = 0; i < kTotal; ++i) CHECK(seen[i].load() == 1);
        CHECK(q.empty());
    }

    std::cout << "Level 5: ALL TESTS PASSED\n";
    return 0;
}
