using System;
using System.Buffers;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.CompilerServices;

// Reference solution.
public sealed class PooledList<T> : IDisposable, IEnumerable<T>
{
    private static readonly ArrayPool<T> Pool = ArrayPool<T>.Shared;
    private T[] _items;
    private int _size;
    private int _version;
    private bool _disposed;

    public PooledList()
    {
        _items = Array.Empty<T>();
    }

    public PooledList(int capacity)
    {
        if (capacity < 0) throw new ArgumentOutOfRangeException(nameof(capacity));
        _items = capacity == 0 ? Array.Empty<T>() : Pool.Rent(capacity);
    }

    public PooledList(IEnumerable<T> items)
    {
        ArgumentNullException.ThrowIfNull(items);
        _items = Array.Empty<T>();
        foreach (var it in items) Add(it);
    }

    public int Count
    {
        get { ThrowIfDisposed(); return _size; }
    }

    public int Capacity
    {
        get { ThrowIfDisposed(); return _items.Length; }
    }

    public T this[int index]
    {
        get
        {
            ThrowIfDisposed();
            if ((uint)index >= (uint)_size) throw new ArgumentOutOfRangeException(nameof(index));
            return _items[index];
        }
        set
        {
            ThrowIfDisposed();
            if ((uint)index >= (uint)_size) throw new ArgumentOutOfRangeException(nameof(index));
            _items[index] = value;
            _version++;
        }
    }

    public void Add(T item)
    {
        ThrowIfDisposed();
        if (_size == _items.Length) Grow(1);
        _items[_size++] = item;
        _version++;
    }

    public void AddRange(IEnumerable<T> items)
    {
        ArgumentNullException.ThrowIfNull(items);
        ThrowIfDisposed();
        if (items is ICollection<T> c)
        {
            EnsureCapacity(_size + c.Count);
            c.CopyTo(_items, _size);
            _size += c.Count;
            _version++;
            return;
        }
        foreach (var it in items) Add(it);
    }

    public void Insert(int index, T item)
    {
        ThrowIfDisposed();
        if ((uint)index > (uint)_size) throw new ArgumentOutOfRangeException(nameof(index));
        if (_size == _items.Length) Grow(1);
        Array.Copy(_items, index, _items, index + 1, _size - index);
        _items[index] = item;
        _size++;
        _version++;
    }

    public void RemoveAt(int index)
    {
        ThrowIfDisposed();
        if ((uint)index >= (uint)_size) throw new ArgumentOutOfRangeException(nameof(index));
        Array.Copy(_items, index + 1, _items, index, _size - index - 1);
        _size--;
        if (RuntimeHelpers.IsReferenceOrContainsReferences<T>())
            _items[_size] = default!;
        _version++;
    }

    public void Clear()
    {
        ThrowIfDisposed();
        if (RuntimeHelpers.IsReferenceOrContainsReferences<T>())
            Array.Clear(_items, 0, _size);
        _size = 0;
        _version++;
    }

    public void EnsureCapacity(int n)
    {
        ThrowIfDisposed();
        if (n < 0) throw new ArgumentOutOfRangeException(nameof(n));
        if (_items.Length >= n) return;
        int newCap = _items.Length == 0 ? 4 : _items.Length * 2;
        if (newCap < n) newCap = n;
        RentSwap(newCap);
    }

    public void TrimExcess()
    {
        ThrowIfDisposed();
        if (_size == _items.Length) return;
        if (_size == 0)
        {
            ReturnCurrent();
            _items = Array.Empty<T>();
            _version++;
            return;
        }
        RentSwap(_size);
        _version++;
    }

    public Span<T> AsSpan()
    {
        ThrowIfDisposed();
        return new Span<T>(_items, 0, _size);
    }

    public T[] ToArray()
    {
        ThrowIfDisposed();
        if (_size == 0) return Array.Empty<T>();
        var a = new T[_size];
        Array.Copy(_items, a, _size);
        return a;
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        ReturnCurrent();
        _items = Array.Empty<T>();
        _size = 0;
        _version++;
    }

    public Enumerator GetEnumerator() => new(this);

    IEnumerator<T> IEnumerable<T>.GetEnumerator() => new Enumerator(this);

    IEnumerator IEnumerable.GetEnumerator() => new Enumerator(this);

    public struct Enumerator : IEnumerator<T>
    {
        private readonly PooledList<T> _list;
        private readonly int _version;
        private int _index;
        private T? _current;

        internal Enumerator(PooledList<T> list)
        {
            _list = list;
            _version = list._version;
            _index = -1;
            _current = default;
        }

        public T Current => _current!;
        object? IEnumerator.Current => Current;

        public bool MoveNext()
        {
            if (_version != _list._version)
                throw new InvalidOperationException("Collection was modified during enumeration.");
            if (_list._disposed)
                throw new ObjectDisposedException(nameof(PooledList<T>));
            if (++_index < _list._size)
            {
                _current = _list._items[_index];
                return true;
            }
            _current = default;
            return false;
        }

        public void Reset()
        {
            if (_version != _list._version)
                throw new InvalidOperationException("Collection was modified during enumeration.");
            _index = -1;
            _current = default;
        }

        public void Dispose() { }
    }

    private void ThrowIfDisposed()
    {
        if (_disposed) throw new ObjectDisposedException(nameof(PooledList<T>));
    }

    private void Grow(int extra)
    {
        int need = _size + extra;
        int newCap = _items.Length == 0 ? 4 : _items.Length * 2;
        if (newCap < need) newCap = need;
        RentSwap(newCap);
    }

    private void RentSwap(int newCap)
    {
        T[] fresh = Pool.Rent(newCap);
        if (_size > 0) Array.Copy(_items, fresh, _size);
        ReturnCurrent();
        _items = fresh;
    }

    private void ReturnCurrent()
    {
        if (_items.Length == 0) return;
        Pool.Return(_items, RuntimeHelpers.IsReferenceOrContainsReferences<T>());
        _items = Array.Empty<T>();
    }
}
