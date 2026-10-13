using System;
using System.Collections.Generic;

// Reference solution. Tests compile against this file.
// When grading a model: replace this file with the model's output.
public static class StringUtils
{
    public static string ReverseWords(string s)
    {
        ArgumentNullException.ThrowIfNull(s);
        string[] words = s.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        Array.Reverse(words);
        return string.Join(' ', words);
    }

    public static bool IsPalindrome(string s)
    {
        ArgumentNullException.ThrowIfNull(s);
        int i = 0, j = s.Length - 1;
        while (i < j)
        {
            if (s[i] != s[j]) return false;
            i++; j--;
        }
        return true;
    }

    public static int SumEven(IEnumerable<int> values)
    {
        ArgumentNullException.ThrowIfNull(values);
        int sum = 0;
        foreach (int x in values)
            if (x % 2 == 0) sum += x;
        return sum;
    }
}
