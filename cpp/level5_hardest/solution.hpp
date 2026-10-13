#pragma once
#include <atomic>
#include <cstddef>
#include <cstdint>
#include <new>
#include <stdexcept>
#include <utility>

// Reference solution: Vyukov bounded MPMC queue.
template <typename T>
class MpmcQueue {
public:
    explicit MpmcQueue(size_t capacity) {
        if (capacity < 1) throw std::invalid_argument("capacity must be >= 1");
        size_t n = 1;
        while (n < capacity) n <<= 1;
        size_ = n;
        mask_ = n - 1;
        buffer_ = new Cell[n];
        for (size_t i = 0; i < n; ++i)
            buffer_[i].sequence.store(i, std::memory_order_relaxed);
        head_.store(0, std::memory_order_relaxed);
        tail_.store(0, std::memory_order_relaxed);
    }

    ~MpmcQueue() {
        T tmp;
        while (try_dequeue(tmp)) {}
        delete[] buffer_;
    }

    MpmcQueue(const MpmcQueue&) = delete;
    MpmcQueue& operator=(const MpmcQueue&) = delete;

    bool try_enqueue(const T& v) {
        Cell* c;
        size_t pos = tail_.load(std::memory_order_relaxed);
        for (;;) {
            c = &buffer_[pos & mask_];
            size_t seq = c->sequence.load(std::memory_order_acquire);
            intptr_t diff = (intptr_t)seq - (intptr_t)pos;
            if (diff == 0) {
                if (tail_.compare_exchange_weak(pos, pos + 1, std::memory_order_relaxed))
                    break;
            } else if (diff < 0) {
                return false; // full
            } else {
                pos = tail_.load(std::memory_order_relaxed);
            }
        }
        new (c->storage) T(v);
        c->sequence.store(pos + 1, std::memory_order_release);
        return true;
    }

    bool try_enqueue(T&& v) {
        Cell* c;
        size_t pos = tail_.load(std::memory_order_relaxed);
        for (;;) {
            c = &buffer_[pos & mask_];
            size_t seq = c->sequence.load(std::memory_order_acquire);
            intptr_t diff = (intptr_t)seq - (intptr_t)pos;
            if (diff == 0) {
                if (tail_.compare_exchange_weak(pos, pos + 1, std::memory_order_relaxed))
                    break;
            } else if (diff < 0) {
                return false;
            } else {
                pos = tail_.load(std::memory_order_relaxed);
            }
        }
        new (c->storage) T(std::move(v));
        c->sequence.store(pos + 1, std::memory_order_release);
        return true;
    }

    bool try_dequeue(T& out) {
        Cell* c;
        size_t pos = head_.load(std::memory_order_relaxed);
        for (;;) {
            c = &buffer_[pos & mask_];
            size_t seq = c->sequence.load(std::memory_order_acquire);
            intptr_t diff = (intptr_t)seq - (intptr_t)(pos + 1);
            if (diff == 0) {
                if (head_.compare_exchange_weak(pos, pos + 1, std::memory_order_relaxed))
                    break;
            } else if (diff < 0) {
                return false; // empty
            } else {
                pos = head_.load(std::memory_order_relaxed);
            }
        }
        T* p = reinterpret_cast<T*>(c->storage);
        out = std::move(*p);
        p->~T();
        c->sequence.store(pos + mask_ + 1, std::memory_order_release);
        return true;
    }

    size_t capacity() const { return size_; }

    bool empty() const {
        size_t h = head_.load(std::memory_order_acquire);
        size_t t = tail_.load(std::memory_order_acquire);
        return h >= t; // approximate under concurrency
    }

    size_t size() const {
        size_t h = head_.load(std::memory_order_acquire);
        size_t t = tail_.load(std::memory_order_acquire);
        return t >= h ? (t - h) : 0;
    }

private:
    struct Cell {
        std::atomic<size_t> sequence;
        alignas(T) unsigned char storage[sizeof(T)];
        Cell() : sequence(0) {}
    };
    Cell* buffer_ = nullptr;
    size_t mask_ = 0;
    size_t size_ = 0;
    alignas(64) std::atomic<size_t> head_{0};
    alignas(64) std::atomic<size_t> tail_{0};
};
