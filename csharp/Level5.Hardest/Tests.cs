using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Threading;

// Level 5 tests — BCL only.
internal static class Tests
{
    private static int _failures;

    private static void Check(bool cond, string name)
    {
        if (!cond) { Console.Error.WriteLine($"FAIL: {name}"); _failures++; }
    }

    public static int Main()
    {
        // 1. Basic FIFO single-threaded
        {
            var q = new BoundedMpmcQueue<int>(8);
            Check(q.IsEmpty && q.Count == 0 && q.Capacity >= 8, "init");
            for (int i = 0; i < 8; i++) Check(q.TryEnqueue(i), $"enq {i}");
            Check(!q.TryEnqueue(99), "full");
            Check(q.Count == 8, "count full");
            for (int i = 0; i < 8; i++)
                Check(q.TryDequeue(out int v) && v == i, $"deq {i}");
            Check(!q.TryDequeue(out _), "empty");
            Check(q.IsEmpty && q.Count == 0, "drained");
        }
        // 2. Wrap-around (reuse slots many times)
        {
            var q = new BoundedMpmcQueue<int>(4);
            for (int round = 0; round < 100; round++)
            {
                for (int i = 0; i < 4; i++) Check(q.TryEnqueue(round * 10 + i), $"wrap enq r{round} i{i}");
                for (int i = 0; i < 4; i++)
                    Check(q.TryDequeue(out int v) && v == round * 10 + i, $"wrap deq r{round} i{i}");
            }
        }
        // 3. Reference type
        {
            var q = new BoundedMpmcQueue<string>(4);
            Check(q.TryEnqueue("hello"), "str enq1");
            string s = "world";
            Check(q.TryEnqueue(s), "str enq2");
            Check(q.TryEnqueue("!"), "str enq3");
            Check(q.TryDequeue(out string? o1) && o1 == "hello", "str deq1");
            Check(q.TryDequeue(out string? o2) && o2 == "world", "str deq2");
            Check(q.TryDequeue(out string? o3) && o3 == "!", "str deq3");
        }
        // 4. Nullable value type elements
        {
            var q = new BoundedMpmcQueue<int?>(4);
            Check(q.TryEnqueue(null), "null enq");
            Check(q.TryEnqueue(5), "val enq");
            Check(q.TryDequeue(out int? a) && a is null, "null deq");
            Check(q.TryDequeue(out int? b) && b == 5, "val deq");
        }
        // 5. Non-power-of-2 rounds up
        {
            var q = new BoundedMpmcQueue<int>(7);
            Check(q.Capacity >= 7, "roundup");
            for (int i = 0; i < q.Capacity; i++) Check(q.TryEnqueue(i), $"fill {i}");
            Check(!q.TryEnqueue(999), "roundup full");
        }
        // 6. Invalid capacity throws
        {
            bool threw = false;
            try { var _ = new BoundedMpmcQueue<int>(0); }
            catch (ArgumentOutOfRangeException) { threw = true; }
            Check(threw, "cap0 throws");
        }
        // 7. MPMC hammer: 4 producers x 50k + 4 consumers, each value exactly once
        {
            const int kProducers = 4, kPerProducer = 50000;
            int kTotal = kProducers * kPerProducer;
            var q = new BoundedMpmcQueue<int>(1024);
            var seen = new int[kTotal]; // 0=unseen, 1=seen via CompareExchange
            int produced = 0, consumed = 0;
            var sw = Stopwatch.StartNew();
            var prod = new List<Thread>();
            for (int p = 0; p < kProducers; p++)
            {
                int b = p * kPerProducer;
                var th = new Thread(() =>
                {
                    for (int i = 0; i < kPerProducer; i++)
                    {
                        int v = b + i;
                        while (!q.TryEnqueue(v)) Thread.Yield();
                        Interlocked.Increment(ref produced);
                    }
                });
                prod.Add(th);
                th.Start();
            }
            var cons = new List<Thread>();
            var consFail = new List<string>();
            for (int c = 0; c < 4; c++)
            {
                var th = new Thread(() =>
                {
                    while (Volatile.Read(ref consumed) < kTotal)
                    {
                        if (q.TryDequeue(out int v))
                        {
                            if ((uint)v >= (uint)kTotal)
                            {
                                lock (consFail) consFail.Add($"oob {v}");
                                return;
                            }
                            if (Interlocked.CompareExchange(ref seen[v], 1, 0) != 0)
                            {
                                lock (consFail) consFail.Add($"dup {v}");
                                return;
                            }
                            Interlocked.Increment(ref consumed);
                        }
                        else
                        {
                            if (sw.Elapsed > TimeSpan.FromSeconds(60))
                            {
                                lock (consFail) consFail.Add("timeout");
                                return;
                            }
                            Thread.Yield();
                        }
                    }
                });
                cons.Add(th);
                th.Start();
            }
            foreach (var th in prod) th.Join();
            foreach (var th in cons) th.Join();
            Check(Volatile.Read(ref produced) == kTotal, "hammer produced");
            Check(Volatile.Read(ref consumed) == kTotal, "hammer consumed");
            foreach (var f in consFail) { Console.Error.WriteLine($"FAIL: hammer {f}"); _failures++; }
            bool allSeen = true;
            for (int i = 0; i < kTotal; i++) if (Volatile.Read(ref seen[i]) != 1) { allSeen = false; break; }
            Check(allSeen, "hammer all seen");
            Check(q.IsEmpty, "hammer drained");
        }

        if (_failures == 0) { Console.WriteLine("Level 5: ALL TESTS PASSED"); return 0; }
        Console.Error.WriteLine($"Level 5: {_failures} FAILURES");
        return 1;
    }
}
