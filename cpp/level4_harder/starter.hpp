#pragma once
#include <cstddef>
#include <stdexcept>
#include <utility>

// AI deliverable: fill in TODOs. Keep public API identical.
// You may add private helpers.
template <typename T, size_t N>
class SmallVector {
public:
    SmallVector() {
        // TODO
    }
    ~SmallVector() {
        // TODO
    }
    SmallVector(const SmallVector& other) {
        // TODO
        (void)other;
    }
    SmallVector(SmallVector&& other) noexcept {
        // TODO
        (void)other;
    }
    SmallVector& operator=(const SmallVector& other) {
        // TODO
        (void)other;
        return *this;
    }
    SmallVector& operator=(SmallVector&& other) noexcept {
        // TODO
        (void)other;
        return *this;
    }

    void push_back(const T& v) { /* TODO */ (void)v; }
    void push_back(T&& v) { /* TODO */ (void)v; }
    template <class... Args> void emplace_back(Args&&... args) { /* TODO */ }

    void pop_back() { /* TODO */ }
    void clear() { /* TODO */ }
    void reserve(size_t n) { /* TODO */ (void)n; }
    void resize(size_t n) { /* TODO */ (void)n; }
    void resize(size_t n, const T& v) { /* TODO */ (void)n; (void)v; }

    T& operator[](size_t i) { /* TODO */ static T* p = nullptr; return *p; }
    const T& operator[](size_t i) const { /* TODO */ static T* p = nullptr; return *p; }
    T& at(size_t i) { /* TODO */ (void)i; static T* p = nullptr; return *p; }
    const T& at(size_t i) const { /* TODO */ (void)i; static T* p = nullptr; return *p; }

    T* data() { /* TODO */ return nullptr; }
    const T* data() const { /* TODO */ return nullptr; }
    size_t size() const { /* TODO */ return 0; }
    size_t capacity() const { /* TODO */ return 0; }
    bool empty() const { /* TODO */ return true; }

    T* begin() { /* TODO */ return nullptr; }
    T* end() { /* TODO */ return nullptr; }
    const T* begin() const { /* TODO */ return nullptr; }
    const T* end() const { /* TODO */ return nullptr; }

private:
    // TODO: add inline storage (alignas), heap pointer, size_, capacity_
    // Hint: bool isSmall() const { return heap_ == nullptr; ... }
};
