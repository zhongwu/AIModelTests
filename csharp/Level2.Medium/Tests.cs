using System;

// Level 2 tests — BCL only.
internal static class Tests
{
    private static int _failures;

    private static void Check(bool cond, string name)
    {
        if (!cond) { Console.Error.WriteLine($"FAIL: {name}"); _failures++; }
    }

    public static int Main()
    {
        // Basic example
        {
            var c = new LruCache<int, int>(2);
            c.Put(1, 1); c.Put(2, 2);
            Check(c.TryGet(1, out int v1) && v1 == 1, "basic get");
            c.Put(3, 3);
            Check(!c.TryGet(2, out _), "basic evicted");
            c.Put(4, 4);
            Check(!c.TryGet(1, out _), "basic evicted2");
            Check(c.TryGet(3, out int v3) && v3 == 3, "basic keep3");
            Check(c.TryGet(4, out int v4) && v4 == 4, "basic keep4");
            Check(c.Count == 2, "basic count");
        }
        // Update existing: no growth, updates recency
        {
            var c = new LruCache<int, int>(2);
            c.Put(1, 1); c.Put(2, 2);
            c.Put(1, 10);
            Check(c.Count == 2, "update count");
            Check(c.TryGet(1, out int v) && v == 10, "update value");
            c.Put(3, 3);
            Check(!c.TryGet(2, out _), "update evicts LRU");
            Check(c.TryGet(3, out _) && c.TryGet(1, out _), "update keeps");
        }
        // TryGet refreshes recency
        {
            var c = new LruCache<int, int>(3);
            c.Put(1, 1); c.Put(2, 2); c.Put(3, 3);
            Check(c.TryGet(1, out _), "recency touch");
            c.Put(4, 4);
            Check(!c.TryGet(2, out _), "recency evicts 2");
            Check(c.TryGet(1, out _) && c.TryGet(3, out _) && c.TryGet(4, out _), "recency keeps");
        }
        // ContainsKey does not disturb recency
        {
            var c = new LruCache<int, int>(2);
            c.Put(1, 1); c.Put(2, 2);
            Check(c.ContainsKey(1), "contains");
            c.Put(3, 3); // LRU is still 1 if ContainsKey is pure
            Check(!c.TryGet(1, out _), "contains pure");
            Check(c.TryGet(2, out _) && c.TryGet(3, out _), "contains keeps");
            Check(!c.ContainsKey(99), "contains missing");
        }
        // Capacity 1 / 0 / negative
        {
            var c = new LruCache<int, int>(1);
            c.Put(1, 1);
            Check(c.TryGet(1, out int v) && v == 1, "cap1 get");
            c.Put(2, 2);
            Check(!c.TryGet(1, out _), "cap1 evict");
            Check(c.TryGet(2, out _) && c.Count == 1, "cap1 keep");
        }
        {
            var c = new LruCache<int, int>(0);
            c.Put(1, 1);
            Check(!c.TryGet(1, out _), "cap0 empty");
            Check(c.Count == 0 && c.Capacity == 0, "cap0 count");
            Check(!c.TryGet(99, out _), "cap0 missing");
        }
        {
            var c = new LruCache<int, int>(-5);
            c.Put(1, 1);
            Check(!c.TryGet(1, out _) && c.Count == 0, "capneg empty");
        }
        // Remove + Clear
        {
            var c = new LruCache<string, int>(3);
            c.Put("a", 1); c.Put("b", 2);
            Check(c.Remove("a") && !c.TryGet("a", out _), "remove");
            Check(!c.Remove("zzz"), "remove missing");
            Check(c.Count == 1, "remove count");
            c.Clear();
            Check(c.Count == 0 && !c.TryGet("b", out _), "clear");
            c.Put("c", 3);
            Check(c.TryGet("c", out int v) && v == 3, "reuse after clear");
        }
        // Generic value type + stress
        {
            var c = new LruCache<int, string>(10);
            for (int i = 0; i < 100; i++) c.Put(i, "v" + i);
            Check(c.Count == 10, "stress count");
            for (int i = 0; i < 90; i++) Check(!c.TryGet(i, out _), $"stress gone {i}");
            for (int i = 90; i < 100; i++)
                Check(c.TryGet(i, out string? s) && s == "v" + i, $"stress keep {i}");
        }

        if (_failures == 0) { Console.WriteLine("Level 2: ALL TESTS PASSED"); return 0; }
        Console.Error.WriteLine($"Level 2: {_failures} FAILURES");
        return 1;
    }
}
