#pragma once
#include <cstddef>
#include <stdexcept>
#include <utility>
#include <new>

// Reference solution (header-only).
template <typename T, size_t N>
class SmallVector {
public:
    SmallVector() : heap_(nullptr), size_(0), cap_(N) {}

    ~SmallVector() {
        destroy_range(ptr(), size_);
        if (heap_) ::operator delete(heap_);
    }

    SmallVector(const SmallVector& other) : heap_(nullptr), size_(0), cap_(N) {
        if (other.size_ > N) {
            heap_ = static_cast<T*>(::operator new(sizeof(T) * other.size_));
            cap_ = other.size_;
            size_t i = 0;
            try {
                for (; i < other.size_; ++i) new (heap_ + i) T(other[i]);
            } catch (...) {
                destroy_range(heap_, i);
                ::operator delete(heap_);
                heap_ = nullptr;
                throw;
            }
            size_ = other.size_;
        } else {
            T* d = ptr();
            const T* s = other.ptr_const();
            size_t i = 0;
            try {
                for (; i < other.size_; ++i) new (d + i) T(s[i]);
            } catch (...) {
                destroy_range(d, i);
                throw;
            }
            size_ = other.size_;
        }
    }

    SmallVector(SmallVector&& other) noexcept : heap_(nullptr), size_(0), cap_(N) {
        move_from(std::move(other));
    }

    SmallVector& operator=(const SmallVector& other) {
        if (this == &other) return *this;
        SmallVector tmp(other);
        *this = std::move(tmp);
        return *this;
    }

    SmallVector& operator=(SmallVector&& other) noexcept {
        if (this == &other) return *this;
        destroy_range(ptr(), size_);
        if (heap_) { ::operator delete(heap_); heap_ = nullptr; }
        size_ = 0; cap_ = N;
        move_from(std::move(other));
        return *this;
    }

    void push_back(const T& v) { emplace_back(v); }
    void push_back(T&& v) { emplace_back(std::move(v)); }

    template <class... Args>
    void emplace_back(Args&&... args) {
        if (size_ == cap_) grow();
        new (ptr() + size_) T(std::forward<Args>(args)...);
        ++size_;
    }

    void pop_back() {
        if (size_ == 0) throw std::out_of_range("pop_back on empty SmallVector");
        ptr()[size_ - 1].~T();
        --size_;
    }

    void clear() {
        destroy_range(ptr(), size_);
        size_ = 0;
    }

    void reserve(size_t n) {
        if (n <= cap_) return;
        reallocate(n);
    }

    void resize(size_t n) {
        if (n < size_) {
            destroy_range(ptr() + n, size_ - n);
            size_ = n;
        } else if (n > size_) {
            if (n > cap_) reallocate(n);
            T* p = ptr();
            for (size_t i = size_; i < n; ++i) new (p + i) T();
            size_ = n;
        }
    }

    void resize(size_t n, const T& v) {
        if (n < size_) {
            destroy_range(ptr() + n, size_ - n);
            size_ = n;
        } else if (n > size_) {
            if (n > cap_) reallocate(n);
            T* p = ptr();
            size_t i = size_;
            try {
                for (; i < n; ++i) new (p + i) T(v);
            } catch (...) {
                destroy_range(p + size_, i - size_);
                throw;
            }
            size_ = n;
        }
    }

    T& operator[](size_t i) { return ptr()[i]; }
    const T& operator[](size_t i) const { return ptr_const()[i]; }

    T& at(size_t i) {
        if (i >= size_) throw std::out_of_range("SmallVector::at");
        return ptr()[i];
    }
    const T& at(size_t i) const {
        if (i >= size_) throw std::out_of_range("SmallVector::at");
        return ptr_const()[i];
    }

    T* data() { return size_ == 0 ? nullptr_or_ptr() : ptr(); }
    const T* data() const { return size_ == 0 ? nullptr_or_ptr_const() : ptr_const(); }
    size_t size() const { return size_; }
    size_t capacity() const { return cap_; }
    bool empty() const { return size_ == 0; }

    T* begin() { return ptr(); }
    T* end() { return ptr() + size_; }
    const T* begin() const { return ptr_const(); }
    const T* end() const { return ptr_const() + size_; }

private:
    // Inline storage (empty struct member when N==0 to keep layout valid)
    alignas(T) unsigned char inlineBuf_[N == 0 ? 1 : N * sizeof(T)];
    T* heap_; // nullptr => small mode
    size_t size_;
    size_t cap_;

    bool isSmall() const { return heap_ == nullptr; }

    T* ptr() {
        return isSmall() ? reinterpret_cast<T*>(inlineBuf_) : heap_;
    }
    const T* ptr_const() const {
        return isSmall() ? reinterpret_cast<const T*>(inlineBuf_) : heap_;
    }
    T* nullptr_or_ptr() { return size_ == 0 ? (isSmall() ? reinterpret_cast<T*>(inlineBuf_) : heap_) : ptr(); }
    const T* nullptr_or_ptr_const() const { return isSmall() ? reinterpret_cast<const T*>(inlineBuf_) : heap_; }

    static void destroy_range(T* p, size_t n) {
        for (size_t i = 0; i < n; ++i) p[i].~T();
    }

    void move_from(SmallVector&& other) {
        if (other.isSmall()) {
            T* d = ptr();
            T* s = other.ptr();
            size_t n = other.size_;
            size_t i = 0;
            try {
                for (; i < n; ++i) new (d + i) T(std::move(s[i]));
            } catch (...) {
                destroy_range(d, i);
                throw;
            }
            destroy_range(s, n);
            other.size_ = 0;
            size_ = n;
            // stays small
        } else {
            heap_ = other.heap_;
            size_ = other.size_;
            cap_ = other.cap_;
            other.heap_ = nullptr;
            other.size_ = 0;
            other.cap_ = N;
        }
    }

    void grow() {
        size_t newCap = cap_ == 0 ? 1 : cap_ * 2;
        if (newCap < N + 1) newCap = N + 1;
        reallocate(newCap);
    }

    void reallocate(size_t newCap) {
        T* newBuf = static_cast<T*>(::operator new(sizeof(T) * newCap));
        T* old = ptr();
        size_t i = 0;
        try {
            for (; i < size_; ++i) new (newBuf + i) T(std::move_if_noexcept(old[i]));
        } catch (...) {
            destroy_range(newBuf, i);
            ::operator delete(newBuf);
            throw;
        }
        destroy_range(old, size_);
        if (heap_) ::operator delete(heap_);
        heap_ = newBuf;
        cap_ = newCap;
    }
};
