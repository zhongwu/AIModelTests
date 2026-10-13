using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

// Reference solution.
public sealed class SimpleThreadPool : IDisposable
{
    private readonly BlockingCollection<Action> _queue = new();
    private readonly List<Thread> _workers = new();
    private int _disposed; // 0/1 via Interlocked

    public SimpleThreadPool(int numThreads)
    {
        if (numThreads <= 0)
        {
            numThreads = Environment.ProcessorCount;
            if (numThreads <= 0) numThreads = 4;
        }
        for (int i = 0; i < numThreads; i++)
        {
            var t = new Thread(() =>
            {
                foreach (var work in _queue.GetConsumingEnumerable())
                {
                    try { work(); }
                    catch { /* work() captures into its TCS; never throws */ }
                }
            })
            {
                IsBackground = true,
                Name = $"SimpleThreadPool worker {i}"
            };
            t.Start();
            _workers.Add(t);
        }
    }

    public Task<T> Enqueue<T>(Func<T> fn)
    {
        ArgumentNullException.ThrowIfNull(fn);
        var tcs = new TaskCompletionSource<T>(TaskCreationOptions.RunContinuationsAsynchronously);
        Action work = () =>
        {
            try { tcs.SetResult(fn()); }
            catch (Exception ex) { tcs.SetException(ex); }
        };
        try { _queue.Add(work); }
        catch (InvalidOperationException) { throw new ObjectDisposedException(nameof(SimpleThreadPool)); }
        if (Volatile.Read(ref _disposed) == 1)
        {
            // Raced with Dispose: queue is completing; surface as disposed.
            throw new ObjectDisposedException(nameof(SimpleThreadPool));
        }
        return tcs.Task;
    }

    public Task Enqueue(Action action)
    {
        ArgumentNullException.ThrowIfNull(action);
        var tcs = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        Action work = () =>
        {
            try { action(); tcs.SetResult(); }
            catch (Exception ex) { tcs.SetException(ex); }
        };
        try { _queue.Add(work); }
        catch (InvalidOperationException) { throw new ObjectDisposedException(nameof(SimpleThreadPool)); }
        if (Volatile.Read(ref _disposed) == 1)
        {
            throw new ObjectDisposedException(nameof(SimpleThreadPool));
        }
        return tcs.Task;
    }

    public void Dispose()
    {
        if (Interlocked.Exchange(ref _disposed, 1) == 1) return;
        _queue.CompleteAdding();
        foreach (var w in _workers) w.Join();
        _queue.Dispose();
    }
}
