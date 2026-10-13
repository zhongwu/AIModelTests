// Level 4 tests. Includes implementation under test.
#include "solution.hpp"

#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
#include <cstdlib>

#define CHECK(cond) do { \
    if (!(cond)) { std::cerr << "FAIL line " << __LINE__ << ": " #cond "\n"; std::exit(1); } \
} while (0)

// Counting type to verify constructions / destructions
struct Counted {
    static int alive;
    int v;
    explicit Counted(int v = 0) : v(v) { ++alive; }
    Counted(const Counted& o) : v(o.v) { ++alive; }
    Counted(Counted&& o) noexcept : v(o.v) { ++alive; o.v = -1; }
    Counted& operator=(const Counted& o) { v = o.v; return *this; }
    Counted& operator=(Counted&& o) noexcept { v = o.v; o.v = -1; return *this; }
    ~Counted() { --alive; }
};
int Counted::alive = 0;

// Throwing copy type for exception-safety test
struct ThrowCopy {
    int v;
    static int countdown; // throws when reaches 0
    explicit ThrowCopy(int v = 0) : v(v) {}
    ThrowCopy(const ThrowCopy& o) : v(o.v) {
        if (countdown-- <= 0) throw std::runtime_error("copy failed");
    }
    ThrowCopy(ThrowCopy&& o) noexcept : v(o.v) {}
};
int ThrowCopy::countdown = 1000000;

int main() {
    // 1. Basic int + SSO uses inline storage (no heap while size <= N)
    {
        SmallVector<int, 4> v;
        CHECK(v.empty() && v.size() == 0 && v.capacity() >= 4);
        v.push_back(1); v.push_back(2); v.emplace_back(3);
        CHECK(v.size() == 3);
        CHECK(v[0] == 1 && v[1] == 2 && v[2] == 3);
        CHECK(v.capacity() >= 4);
        int sum = 0;
        for (int x : v) sum += x;
        CHECK(sum == 6);
        v.pop_back();
        CHECK(v.size() == 2);
        v.clear();
        CHECK(v.empty());
    }
    // 2. Growth past N preserves elements
    {
        SmallVector<int, 2> v;
        for (int i = 0; i < 100; ++i) v.push_back(i);
        CHECK(v.size() == 100);
        CHECK(v.capacity() >= 100);
        for (int i = 0; i < 100; ++i) CHECK(v[i] == i);
        CHECK(v.at(99) == 99);
        bool threw = false;
        try { v.at(100); } catch (const std::out_of_range&) { threw = true; }
        CHECK(threw);
    }
    // 3. Copy semantics (deep copy)
    {
        SmallVector<int, 2> a;
        a.push_back(1); a.push_back(2); a.push_back(3); // heap mode
        SmallVector<int, 2> b(a);
        CHECK(b.size() == 3 && b[0] == 1 && b[2] == 3);
        b[0] = 99;
        CHECK(a[0] == 1);
        SmallVector<int, 2> c;
        c = a;
        CHECK(c.size() == 3 && c[1] == 2);
        c = c; // self-assign must not break
        CHECK(c.size() == 3);
    }
    // 4. Move semantics (source valid; heap stolen when large)
    {
        SmallVector<int, 4> a;
        for (int i = 0; i < 10; ++i) a.push_back(i);
        SmallVector<int, 4> b(std::move(a));
        CHECK(b.size() == 10 && b[9] == 9);
        // a must be valid (may be empty); just check it can be reused/destroyed
        a.clear(); a.push_back(42);
        CHECK(a.size() == 1 && a[0] == 42);

        SmallVector<int, 4> s;
        s.push_back(1); s.push_back(2);
        SmallVector<int, 4> t(std::move(s));
        CHECK(t.size() == 2 && t[0] == 1);
    }
    // 5. reserve / resize
    {
        SmallVector<int, 2> v;
        v.reserve(50);
        CHECK(v.capacity() >= 50 && v.size() == 0);
        v.reserve(1); // must not shrink
        CHECK(v.capacity() >= 50);
        v.resize(5);
        CHECK(v.size() == 5);
        v.resize(5, 99);
        CHECK(v.size() == 5);
        v.resize(8, 7);
        CHECK(v.size() == 8 && v[5] == 7 && v[7] == 7);
        v.resize(2);
        CHECK(v.size() == 2);
    }
    // 6. Non-trivial type std::string
    {
        SmallVector<std::string, 2> v;
        v.push_back("hello");
        v.emplace_back("world");
        v.emplace_back("!");
        CHECK(v.size() == 3 && v[0] == "hello" && v[2] == "!");
        SmallVector<std::string, 2> w(v);
        CHECK(w.size() == 3 && w[1] == "world");
        w.clear();
        CHECK(w.empty());
    }
    // 7. Move-only type
    {
        SmallVector<std::unique_ptr<int>, 2> v;
        v.push_back(std::make_unique<int>(5));
        v.emplace_back(std::make_unique<int>(6));
        v.emplace_back(std::make_unique<int>(7));
        CHECK(v.size() == 3 && *v[0] == 5 && *v[2] == 7);
        SmallVector<std::unique_ptr<int>, 2> w(std::move(v));
        CHECK(w.size() == 3 && *w[1] == 6);
    }
    // 8. No leak with counting type (incl. growth + copy + move)
    {
        Counted::alive = 0;
        {
            SmallVector<Counted, 2> v;
            v.emplace_back(1); v.emplace_back(2); v.emplace_back(3);
            CHECK(Counted::alive == 3);
            SmallVector<Counted, 2> w(v);
            CHECK(Counted::alive == 6);
            SmallVector<Counted, 2> u(std::move(v));
            // v's elements moved-from then destroyed; u owns 3
            CHECK(u.size() == 3);
        }
        CHECK(Counted::alive == 0);
    }
    // 9. Exception safety: throwing copy must not leak/corrupt
    {
        SmallVector<ThrowCopy, 2> v;
        v.emplace_back(1); v.emplace_back(2);
        ThrowCopy::countdown = 0; // next COPY throws (move is noexcept)
        bool threw = false;
        size_t before = v.size();
        try {
            ThrowCopy src(3);      // direct ctor, no throw
            v.push_back(src);      // const& overload -> copy -> throws
        } catch (...) { threw = true; }
        CHECK(threw);
        CHECK(v.size() == before); // strong-ish guarantee
        ThrowCopy::countdown = 1000000;
    }
    // 10. N == 0 works (pure heap)
    {
        SmallVector<int, 0> v;
        CHECK(v.empty());
        for (int i = 0; i < 10; ++i) v.push_back(i);
        CHECK(v.size() == 10 && v[9] == 9);
    }

    std::cout << "Level 4: ALL TESTS PASSED\n";
    return 0;
}
