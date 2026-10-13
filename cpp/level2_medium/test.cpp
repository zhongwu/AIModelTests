// Level 2 tests — no external deps.
#include "starter.hpp"
#include <cassert>
#include <iostream>

#define CHECK(cond) do { \
    if (!(cond)) { std::cerr << "FAIL line " << __LINE__ << ": " #cond "\n"; return 1; } \
} while (0)

int main() {
    // Basic example (LeetCode 146)
    {
        LRUCache c(2);
        c.put(1, 1); c.put(2, 2);
        CHECK(c.get(1) == 1);
        c.put(3, 3); // evicts 2
        CHECK(c.get(2) == -1);
        c.put(4, 4); // evicts 1
        CHECK(c.get(1) == -1);
        CHECK(c.get(3) == 3);
        CHECK(c.get(4) == 4);
    }
    // Update existing key (no growth, updates recency)
    {
        LRUCache c(2);
        c.put(1, 1); c.put(2, 2);
        c.put(1, 10);
        CHECK(c.get(1) == 10);
        c.put(3, 3); // must evict 2, not 1
        CHECK(c.get(2) == -1);
        CHECK(c.get(3) == 3);
    }
    // get() refreshes recency
    {
        LRUCache c(3);
        c.put(1, 1); c.put(2, 2); c.put(3, 3);
        CHECK(c.get(1) == 1); // 1 now MRU, 2 is LRU
        c.put(4, 4); // evicts 2
        CHECK(c.get(2) == -1);
        CHECK(c.get(1) == 1);
        CHECK(c.get(3) == 3);
        CHECK(c.get(4) == 4);
    }
    // Capacity 1 and 0
    {
        LRUCache c(1);
        c.put(1, 1);
        CHECK(c.get(1) == 1);
        c.put(2, 2);
        CHECK(c.get(1) == -1);
        CHECK(c.get(2) == 2);
    }
    {
        LRUCache c(0);
        c.put(1, 1);
        CHECK(c.get(1) == -1);
        c.put(2, 2);
        CHECK(c.get(2) == -1);
    }
    {
        LRUCache c(-5);
        c.put(1, 1);
        CHECK(c.get(99) == -1);
    }
    // Missing keys
    {
        LRUCache c(2);
        CHECK(c.get(999) == -1);
        c.put(1, 1);
        CHECK(c.get(2) == -1);
    }
    // Stress: many puts, last `cap` survive
    {
        LRUCache c(10);
        for (int i = 0; i < 100; ++i) c.put(i, i * 10);
        for (int i = 0; i < 90; ++i) CHECK(c.get(i) == -1);
        for (int i = 90; i < 100; ++i) CHECK(c.get(i) == i * 10);
    }

    std::cout << "Level 2: ALL TESTS PASSED\n";
    return 0;
}
