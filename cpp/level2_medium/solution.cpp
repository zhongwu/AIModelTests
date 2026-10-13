#include "starter.hpp"

LRUCache::LRUCache(int capacity) : cap_(capacity) {}

int LRUCache::get(int key) {
    auto it = map_.find(key);
    if (it == map_.end()) return -1;
    order_.splice(order_.begin(), order_, it->second);
    return it->second->second;
}

void LRUCache::put(int key, int value) {
    if (cap_ <= 0) return;
    auto it = map_.find(key);
    if (it != map_.end()) {
        it->second->second = value;
        order_.splice(order_.begin(), order_, it->second);
        return;
    }
    if ((int)order_.size() >= cap_) {
        auto lru = order_.back();
        map_.erase(lru.first);
        order_.pop_back();
    }
    order_.emplace_front(key, value);
    map_[key] = order_.begin();
}
