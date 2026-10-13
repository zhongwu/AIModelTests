#pragma once
#include <list>
#include <unordered_map>
#include <utility>

// AI deliverable: implement LRUCache::get / put in your .cpp.
// You may NOT change this public interface, but you may add private helpers.
class LRUCache {
public:
    explicit LRUCache(int capacity);
    int get(int key);
    void put(int key, int value);
private:
    int cap_;
    // front = most-recent
    std::list<std::pair<int,int>> order_;
    std::unordered_map<int, std::list<std::pair<int,int>>::iterator> map_;
};
