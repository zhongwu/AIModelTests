using System;
using System.Collections.Generic;

// Reference solution.
public sealed class LruCache<TKey, TValue> where TKey : notnull
{
    private readonly int _capacity;
    private readonly Dictionary<TKey, LinkedListNode<KeyValuePair<TKey, TValue>>> _map;
    private readonly LinkedList<KeyValuePair<TKey, TValue>> _order = new(); // First = MRU

    public LruCache(int capacity)
    {
        _capacity = capacity;
        _map = new Dictionary<TKey, LinkedListNode<KeyValuePair<TKey, TValue>>>(capacity > 0 ? capacity : 0);
    }

    public int Capacity => _capacity;
    public int Count => _map.Count;

    public bool TryGet(TKey key, out TValue value)
    {
        ArgumentNullException.ThrowIfNull(key);
        if (_map.TryGetValue(key, out var node))
        {
            _order.Remove(node);
            _order.AddFirst(node);
            value = node.Value.Value;
            return true;
        }
        value = default!;
        return false;
    }

    public void Put(TKey key, TValue value)
    {
        ArgumentNullException.ThrowIfNull(key);
        if (_capacity <= 0) return;
        if (_map.TryGetValue(key, out var node))
        {
            node.Value = new KeyValuePair<TKey, TValue>(key, value);
            _order.Remove(node);
            _order.AddFirst(node);
            return;
        }
        if (_map.Count >= _capacity)
        {
            var lru = _order.Last!;
            _map.Remove(lru.Value.Key);
            _order.RemoveLast();
        }
        var fresh = _order.AddFirst(new KeyValuePair<TKey, TValue>(key, value));
        _map[key] = fresh;
    }

    public bool Remove(TKey key)
    {
        ArgumentNullException.ThrowIfNull(key);
        if (_map.TryGetValue(key, out var node))
        {
            _order.Remove(node);
            _map.Remove(key);
            return true;
        }
        return false;
    }

    public bool ContainsKey(TKey key)
    {
        ArgumentNullException.ThrowIfNull(key);
        return _map.ContainsKey(key);
    }

    public void Clear()
    {
        _map.Clear();
        _order.Clear();
    }
}
