using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

// Level 3 tests — BCL only. Timeouts turn hangs into failures.
internal static class Tests
{
    private static int _failures;
    private static readonly TimeSpan Hang = TimeSpan.FromSeconds(30);

    private static void Check(bool cond, string name)
    {
        if (!cond) { Console.Error.WriteLine($"FAIL: {name}"); _failures++; }
    }

    private static T Get<T>(Task<T> t, string name)
    {
        // Note: Task.Wait rethrows faulted tasks wrapped in AggregateException,
        // so swallow it here and unwrap the original below via GetResult().
        try
        {
            if (!t.Wait(Hang)) { Console.Error.WriteLine($"FAIL (hang): {name}"); _failures++; throw new TimeoutException(name); }
        }
        catch (AggregateException) { }
        return t.GetAwaiter().GetResult();
    }

    private static void Wait(Task t, string name)
    {
        try
        {
            if (!t.Wait(Hang)) { Console.Error.WriteLine($"FAIL (hang): {name}"); _failures++; throw new TimeoutException(name); }
        }
        catch (AggregateException) { }
        t.GetAwaiter().GetResult();
    }

    public static int Main()
    {
        try
        {
            // 1. Parallel sum
            using (var pool = new SimpleThreadPool(4))
            {
                var tasks = new List<Task<int>>();
                for (int i = 0; i < 100; i++) { int c = i; tasks.Add(pool.Enqueue(() => c * c)); }
                long sum = 0;
                foreach (var t in tasks) sum += Get(t, "sum task");
                long expect = 0;
                for (int i = 0; i < 100; i++) expect += (long)i * i;
                Check(sum == expect, "parallel sum");
            }
            // 2. Void side effects
            using (var pool = new SimpleThreadPool(4))
            {
                int n = 0;
                var tasks = new List<Task>();
                for (int i = 0; i < 200; i++) tasks.Add(pool.Enqueue(() => Interlocked.Increment(ref n)));
                foreach (var t in tasks) Wait(t, "void task");
                Check(Volatile.Read(ref n) == 200, "void count");
            }
            // 3. Exception propagation keeps original type
            using (var pool = new SimpleThreadPool(2))
            {
                var t = pool.Enqueue<int>(() => throw new InvalidOperationException("boom"));
                bool caught = false;
                try { Get(t, "ex task"); }
                catch (InvalidOperationException ex) { caught = ex.Message == "boom"; }
                catch (Exception) { }
                Check(caught, "exception type+message");
                Check(t.IsFaulted, "task faulted");
            }
            // 4. Closure capture
            using (var pool = new SimpleThreadPool(2))
            {
                int captured = 41;
                Check(Get(pool.Enqueue(() => captured + 1), "closure") == 42, "closure value");
            }
            // 5. Null args
            using (var pool = new SimpleThreadPool(2))
            {
                bool n1 = false, n2 = false;
                try { pool.Enqueue<int>(null!); } catch (ArgumentNullException) { n1 = true; }
                try { pool.Enqueue(null!); } catch (ArgumentNullException) { n2 = true; }
                Check(n1 && n2, "null guards");
            }
            // 6. Dispose drains; Enqueue-after-Dispose throws; idempotent
            {
                var pool = new SimpleThreadPool(2);
                int n = 0;
                var tasks = new List<Task>();
                for (int i = 0; i < 50; i++) tasks.Add(pool.Enqueue(() => Interlocked.Increment(ref n)));
                pool.Dispose();
                foreach (var t in tasks) Wait(t, "drain task");
                Check(Volatile.Read(ref n) == 50, "dispose drains");
                bool threw = false;
                try { pool.Enqueue(() => { }); } catch (ObjectDisposedException) { threw = true; }
                Check(threw, "enqueue after dispose");
                pool.Dispose(); // must not hang/throw
            }
            // 7. Implicit drain via using without awaiting
            {
                int n = 0;
                using (var pool = new SimpleThreadPool(2))
                    for (int i = 0; i < 50; i++) pool.Enqueue(() => Interlocked.Increment(ref n));
                Check(Volatile.Read(ref n) == 50, "using drains");
            }
            // 8. Multi-producer stress
            using (var pool = new SimpleThreadPool(8))
            {
                long sum = 0;
                var producers = new List<Thread>();
                var bag = new List<Task>();
                var gate = new object();
                for (int p = 0; p < 4; p++)
                {
                    var th = new Thread(() =>
                    {
                        for (int i = 0; i < 250; i++)
                        {
                            var t = pool.Enqueue(() => Interlocked.Increment(ref sum));
                            lock (gate) bag.Add(t);
                        }
                    });
                    producers.Add(th);
                    th.Start();
                }
                foreach (var th in producers) th.Join();
                foreach (var t in bag) Wait(t, "stress task");
                Check(Interlocked.Read(ref sum) == 1000, "stress count");
            }
            // 9. numThreads == 0 fallback
            using (var pool = new SimpleThreadPool(0))
                Check(Get(pool.Enqueue(() => 7), "fallback") == 7, "fallback works");
        }
        catch (TimeoutException) { /* already counted */ }

        if (_failures == 0) { Console.WriteLine("Level 3: ALL TESTS PASSED"); return 0; }
        Console.Error.WriteLine($"Level 3: {_failures} FAILURES");
        return 1;
    }
}
