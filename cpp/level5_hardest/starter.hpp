#pragma once
#include <atomic>
#include <cstddef>
#include <utility>

// AI deliverable: implement Vyukov bounded MPMC queue. Keep public API identical.
// No mutexes allowed.
template <typename T>
class MpmcQueue {
public:
    explicit MpmcQueue(size_t capacity) {
        // TODO: round up to pow2, alloc cells, init sequences
        (void)capacity;
    }
    ~MpmcQueue() {
        // TODO: drain + free
    }
    MpmcQueue(const MpmcQueue&) = delete;
    MpmcQueue& operator=(const MpmcQueue&) = delete;

    bool try_enqueue(const T& v) { /* TODO */ (void)v; return false; }
    bool try_enqueue(T&& v) { /* TODO */ (void)v; return false; }
    bool try_dequeue(T& out) { /* TODO */ (void)out; return false; }

    size_t capacity() const { /* TODO */ return 0; }
    bool empty() const { /* TODO */ return true; }
    size_t size() const { /* TODO */ return 0; }

private:
    // TODO: Cell { atomic<size_t> seq; aligned storage for T; }, buffer_, mask_, head_, tail_
};
