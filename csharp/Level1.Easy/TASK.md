# Level 1 — Easy (C#): String & Sequence Utils

## Prompt for the AI model

> Implement the three methods in `StringUtils` (see `Starter.cs.txt`).
> Only the .NET 8 base class library may be used. No NuGet packages.

### API to implement

```csharp
public static class StringUtils
{
    // Words = maximal non-space sequences. Single spaces in output, trimmed.
    // Example: "  hello   world " -> "world hello". Null -> throw ArgumentNullException.
    public static string ReverseWords(string s);

    // Case-sensitive, all chars count (including spaces). "" -> true.
    // Null -> throw ArgumentNullException.
    public static bool IsPalindrome(string s);

    // Sum of even numbers. Empty sequence -> 0. Null -> throw ArgumentNullException.
    public static int SumEven(IEnumerable<int> values);
}
```

### Rules
- Time O(n), extra space O(n) allowed. Do not mutate inputs.
- `ReverseWords("   ")` -> `""`.

## Evaluation
Give the model ONLY this file + `Starter.cs.txt`. It must produce `Solution.cs`.
Then: `dotnet run` — all asserts must pass. Any exception / non-zero exit = fail.

## Rubric
- Pass: all green, `dotnet build -warnaserror` clean.
- Partial: minor whitespace bug.
- Fail: wrong algorithm, crash on empty input, missing null guards.
