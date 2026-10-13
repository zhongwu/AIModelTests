using System;
using System.Collections.Generic;

// Level 4 tests — BCL only.
internal static class Tests
{
    private static int _failures;

    private static void Check(bool cond, string name)
    {
        if (!cond) { Console.Error.WriteLine($"FAIL: {name}"); _failures++; }
    }

    private static void CheckThrows<TEx>(Action a, string name) where TEx : Exception
    {
        try { a(); Console.Error.WriteLine($"FAIL (no throw): {name}"); _failures++; }
        catch (TEx) { }
        catch (Exception ex) { Console.Error.WriteLine($"FAIL (wrong ex {ex.GetType().Name}): {name}"); _failures++; }
    }

    public static int Main()
    {
        // 1. Basic add/index/foreach
        using (var v = new PooledList<int>())
        {
            Check(v.Count == 0 && v.Capacity == 0, "empty");
            v.Add(1); v.Add(2); v.Add(3);
            Check(v.Count == 3 && v[0] == 1 && v[2] == 3, "add/index");
            int sum = 0;
            foreach (int x in v) sum += x;
            Check(sum == 6, "foreach");
            CheckThrows<ArgumentOutOfRangeException>(() => { var _ = v[3]; }, "index oob");
            CheckThrows<ArgumentOutOfRangeException>(() => { var _ = v[-1]; }, "index neg");
        }
        // 2. Growth to 100 preserves elements
        using (var v = new PooledList<int>(2))
        {
            for (int i = 0; i < 100; i++) v.Add(i);
            Check(v.Count == 100 && v.Capacity >= 100, "growth cap");
            bool ok = true;
            for (int i = 0; i < 100; i++) if (v[i] != i) ok = false;
            Check(ok, "growth values");
        }
        // 3. Copy independence via IEnumerable ctor + ToArray
        using (var a = new PooledList<int>())
        {
            a.Add(1); a.Add(2); a.Add(3);
            using (var b = new PooledList<int>(a))
            {
                Check(b.Count == 3 && b[2] == 3, "copy ctor");
                b[0] = 99;
                Check(a[0] == 1, "copy independent");
                int[] arr = a.ToArray();
                arr[0] = -1;
                Check(a[0] == 1, "toarray copy");
            }
        }
        // 4. Insert / RemoveAt / setter
        using (var v = new PooledList<int>())
        {
            v.Add(1); v.Add(3);
            v.Insert(1, 2);
            Check(v.Count == 3 && v[1] == 2, "insert mid");
            v.Insert(0, 0);
            v.Insert(v.Count, 4);
            Check(v[0] == 0 && v[4] == 4, "insert ends");
            v.RemoveAt(0);
            Check(v[0] == 1 && v.Count == 4, "remove first");
            v.RemoveAt(v.Count - 1);
            Check(v.Count == 3, "remove last");
            v[0] = 10;
            Check(v[0] == 10, "setter");
            CheckThrows<ArgumentOutOfRangeException>(() => v.Insert(99, 1), "insert oob");
            CheckThrows<ArgumentOutOfRangeException>(() => v.RemoveAt(99), "remove oob");
        }
        // 5. EnsureCapacity / TrimExcess
        using (var v = new PooledList<int>())
        {
            v.EnsureCapacity(50);
            Check(v.Capacity >= 50 && v.Count == 0, "ensure");
            v.EnsureCapacity(1);
            Check(v.Capacity >= 50, "ensure no shrink");
            CheckThrows<ArgumentOutOfRangeException>(() => v.EnsureCapacity(-1), "ensure neg");
            for (int i = 0; i < 5; i++) v.Add(i);
            v.TrimExcess();
            // ArrayPool buckets sizes, so Capacity is >= Count but must have shrunk.
            Check(v.Count == 5 && v.Capacity >= 5 && v.Capacity < 50, "trim");
            Check(v[4] == 4, "trim values");
        }
        // 6. Clear keeps capacity
        using (var v = new PooledList<int>())
        {
            for (int i = 0; i < 10; i++) v.Add(i);
            int cap = v.Capacity;
            v.Clear();
            Check(v.Count == 0 && v.Capacity == cap, "clear keeps cap");
            v.Add(42);
            Check(v.Count == 1 && v[0] == 42, "reuse after clear");
        }
        // 7. Strings + AddRange
        using (var v = new PooledList<string>())
        {
            v.Add("hello");
            v.AddRange(new[] { "world", "!" });
            Check(v.Count == 3 && v[0] == "hello" && v[2] == "!", "strings");
            using (var w = new PooledList<string>(v))
                Check(w.Count == 3 && w[1] == "world", "string copy");
            CheckThrows<ArgumentNullException>(() => v.AddRange(null!), "addrange null");
            CheckThrows<ArgumentNullException>(() => new PooledList<string>((System.Collections.Generic.IEnumerable<string>)null!), "ctor null");
        }
        // 8. Span is a live view
        using (var v = new PooledList<int>())
        {
            v.Add(1); v.Add(2); v.Add(3);
            Span<int> s = v.AsSpan();
            Check(s.Length == 3 && s[0] == 1, "span");
            s[0] = 99;
            Check(v[0] == 99, "span live");
        }
        // 9. Enumerator invalidates on mutation
        using (var v = new PooledList<int>())
        {
            v.Add(1); v.Add(2);
            bool threw = false;
            try
            {
                foreach (int x in v) { if (x == 1) v.Add(3); }
            }
            catch (InvalidOperationException) { threw = true; }
            Check(threw, "enum invalidation");
        }
        // 10. Dispose semantics
        {
            var v = new PooledList<int>();
            v.Add(1);
            v.Dispose();
            v.Dispose(); // idempotent
            CheckThrows<ObjectDisposedException>(() => v.Add(1), "disposed add");
            CheckThrows<ObjectDisposedException>(() => { var _ = v.Count; }, "disposed count");
            CheckThrows<ObjectDisposedException>(() => { var _ = v[0]; }, "disposed index");
            CheckThrows<ObjectDisposedException>(() => v.Clear(), "disposed clear");
            CheckThrows<ObjectDisposedException>(() => v.AsSpan(), "disposed span");
            CheckThrows<ObjectDisposedException>(() => v.EnsureCapacity(8), "disposed ensure");
        }
        // 11. Struct elements + nullable strings
        using (var v = new PooledList<DateTime>())
        {
            v.Add(new DateTime(2026, 1, 1));
            Check(v.Count == 1 && v[0].Year == 2026, "struct elem");
        }
        using (var v = new PooledList<string?>())
        {
            v.Add(null); v.Add("x");
            Check(v.Count == 2 && v[0] is null && v[1] == "x", "nullable elem");
        }

        if (_failures == 0) { Console.WriteLine("Level 4: ALL TESTS PASSED"); return 0; }
        Console.Error.WriteLine($"Level 4: {_failures} FAILURES");
        return 1;
    }
}
