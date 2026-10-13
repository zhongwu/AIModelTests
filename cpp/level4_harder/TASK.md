# Level 4 — Harder: `SmallVector<T, N>` with SSO

## Prompt for the AI model

> Implement a simplified `SmallVector<T, N>` with small-buffer optimization (SSO)
> in `small_vector.hpp`. Skeleton in `starter.hpp`. Fill in `TODO`s.

### API (keep exact public interface)

```cpp
template <typename T, size_t N>
class SmallVector {
public:
    SmallVector();
    ~SmallVector();
    SmallVector(const SmallVector& other);
    SmallVector(SmallVector&& other) noexcept;
    SmallVector& operator=(const SmallVector& other);
    SmallVector& operator=(SmallVector&& other) noexcept;

    void push_back(const T& v);
    void push_back(T&& v);
    template <class... Args> void emplace_back(Args&&... args);
    void pop_back();
    void clear();
    void reserve(size_t n);
    void resize(size_t n);
    void resize(size_t n, const T& v);

    T& operator[](size_t i);
    const T& operator[](size_t i) const;
    T& at(size_t i);             // throws std::out_of_range
    const T& at(size_t i) const;

    T* data(); const T* data() const;
    size_t size() const; size_t capacity() const; bool empty() const;

    T* begin(); T* end(); const T* begin() const; const T* end() const;
};
```

Full skeleton (with `alignas` inline storage, `T*`, size/cap pointers) is in `starter.hpp`.

### Rules
- First `N` elements live in inline storage (no heap) until `size > N`; then
  fall back to heap with geometric growth (e.g. 2x).
- `reserve(n)` never shrinks; `resize` value-inits or destroys as needed.
- Strong copy semantics; move leaves source valid + empty (or at least valid).
- `at()` bounds-checks; `operator[]` unchecked.
- Iterators are raw pointers; range-for must work.
- Must work for non-trivial types (`std::string`), move-only types
  (`unique_ptr<int>` — copy ops will fail to instantiate, that's fine),
  and counting types that track constructions.
- Exception safety: `push_back`/`reserve`/`resize` provide strong guarantee
  as far as reasonable (no leaks, no double-free if a copy throws).
- No leaks (must pass `-fsanitize=address,undefined`).

### Constraints
- C++17, header-only, no external deps.
- Must use placement-new + explicit destructor calls for inline storage.
- `N` may be 0 (pure heap vector).

## Evaluation
`g++ -std=c++17 -O2 -Wall -Wextra -o test4 test.cpp && ./test4`
Tests: SSO vs heap transitions, copy/move, reserve/resize, iterators,
`std::string` + move-only, exception-safety with throwing copy type.

## Rubric
- Pass: all green + ASan/UBSan clean + no heap alloc while `size <= N`.
- Partial: works for `int` but breaks for non-trivial/move-only types.
- Fail: double-free, leak, UB in uninitialized storage, broken move.
