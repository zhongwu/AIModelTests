using System;
using System.Threading;

// Reference solution: Vyukov bounded MPMC queue, C# port.
public sealed class BoundedMpmcQueue<T>
{
    private sealed class Cell
    {
        public long Sequence;
        public T? Value;
    }

    private readonly Cell[] _buffer;
    private readonly int _mask;
    private readonly int _capacity;
    private long _head;
    private long _tail;

    public BoundedMpmcQueue(int capacity)
    {
        if (capacity < 1) throw new ArgumentOutOfRangeException(nameof(capacity));
        int n = 1;
        while (n < capacity) n <<= 1;
        _capacity = n;
        _mask = n - 1;
        _buffer = new Cell[n];
        for (int i = 0; i < n; i++)
            _buffer[i] = new Cell { Sequence = i };
    }

    public int Capacity => _capacity;

    public bool IsEmpty => Volatile.Read(ref _head) >= Volatile.Read(ref _tail);

    public int Count
    {
        get
        {
            long h = Volatile.Read(ref _head);
            long t = Volatile.Read(ref _tail);
            long d = t - h;
            if (d <= 0) return 0;
            return d > int.MaxValue ? int.MaxValue : (int)d;
        }
    }

    public bool TryEnqueue(T item)
    {
        Cell cell;
        long pos = Volatile.Read(ref _tail);
        for (;;)
        {
            cell = _buffer[(int)(pos & _mask)];
            long seq = Volatile.Read(ref cell.Sequence);
            long diff = seq - pos;
            if (diff == 0)
            {
                if (Interlocked.CompareExchange(ref _tail, pos + 1, pos) == pos)
                    break;
            }
            else if (diff < 0)
            {
                return false; // full
            }
            else
            {
                pos = Volatile.Read(ref _tail);
            }
        }
        cell.Value = item;
        Volatile.Write(ref cell.Sequence, pos + 1);
        return true;
    }

    public bool TryDequeue(out T result)
    {
        Cell cell;
        long pos = Volatile.Read(ref _head);
        for (;;)
        {
            cell = _buffer[(int)(pos & _mask)];
            long seq = Volatile.Read(ref cell.Sequence);
            long diff = seq - (pos + 1);
            if (diff == 0)
            {
                if (Interlocked.CompareExchange(ref _head, pos + 1, pos) == pos)
                    break;
            }
            else if (diff < 0)
            {
                result = default!;
                return false; // empty
            }
            else
            {
                pos = Volatile.Read(ref _head);
            }
        }
        result = cell.Value!;
        cell.Value = default;
        Volatile.Write(ref cell.Sequence, pos + _mask + 1);
        return true;
    }
}
