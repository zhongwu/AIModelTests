using System;
using System.Collections.Generic;

// Level 1 tests — BCL only, no test framework.
internal static class Tests
{
    private static int _failures;

    private static void Check(bool cond, string name)
    {
        if (!cond)
        {
            Console.Error.WriteLine($"FAIL: {name}");
            _failures++;
        }
    }

    private static void CheckThrows<TEx>(Action a, string name) where TEx : Exception
    {
        try { a(); Console.Error.WriteLine($"FAIL (no throw): {name}"); _failures++; }
        catch (TEx) { }
        catch (Exception ex) { Console.Error.WriteLine($"FAIL (wrong ex {ex.GetType().Name}): {name}"); _failures++; }
    }

    public static int Main()
    {
        Check(StringUtils.ReverseWords("  hello   world ") == "world hello", "reverse basic");
        Check(StringUtils.ReverseWords("a") == "a", "reverse single");
        Check(StringUtils.ReverseWords("") == "", "reverse empty");
        Check(StringUtils.ReverseWords("   ") == "", "reverse blanks");
        Check(StringUtils.ReverseWords("a b c") == "c b a", "reverse three");
        Check(StringUtils.ReverseWords("  ab  cd  ") == "cd ab", "reverse pad");
        Check(StringUtils.ReverseWords("hello") == "hello", "reverse one");
        Check(StringUtils.ReverseWords("one two") == "two one", "reverse two");
        CheckThrows<ArgumentNullException>(() => StringUtils.ReverseWords(null!), "reverse null");

        Check(StringUtils.IsPalindrome("") == true, "pal empty");
        Check(StringUtils.IsPalindrome("a") == true, "pal single");
        Check(StringUtils.IsPalindrome("abba") == true, "pal abba");
        Check(StringUtils.IsPalindrome("Abba") == false, "pal case");
        Check(StringUtils.IsPalindrome("abc") == false, "pal abc");
        Check(StringUtils.IsPalindrome("a a") == true, "pal spaces");
        Check(StringUtils.IsPalindrome("  ") == true, "pal blanks");
        Check(StringUtils.IsPalindrome("racecar") == true, "pal racecar");
        CheckThrows<ArgumentNullException>(() => StringUtils.IsPalindrome(null!), "pal null");

        Check(StringUtils.SumEven(Array.Empty<int>()) == 0, "sum empty");
        Check(StringUtils.SumEven(new[] { 1, 3, 5 }) == 0, "sum odds");
        Check(StringUtils.SumEven(new[] { 2, 4, 6 }) == 12, "sum evens");
        Check(StringUtils.SumEven(new[] { 1, 2, 3, 4 }) == 6, "sum mixed");
        Check(StringUtils.SumEven(new[] { -2, -3, 4 }) == 2, "sum negative");
        Check(StringUtils.SumEven(new[] { 0 }) == 0, "sum zero");
        Check(StringUtils.SumEven(new List<int> { 1000000, 1000001 }) == 1000000, "sum big");
        CheckThrows<ArgumentNullException>(() => StringUtils.SumEven(null!), "sum null");

        if (_failures == 0) { Console.WriteLine("Level 1: ALL TESTS PASSED"); return 0; }
        Console.Error.WriteLine($"Level 1: {_failures} FAILURES");
        return 1;
    }
}
