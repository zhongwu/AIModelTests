# Level 1 — Easy: String & Vector Utils

## Prompt for the AI model

> Implement the three functions declared in `starter.hpp` in a new file (or inline).
> You may only use the C++17 standard library. No external deps.
> Functions must handle all edge cases and must not crash.

### API to implement (`starter.hpp`)

```cpp
#pragma once
#include <string>
#include <vector>

std::string reverseWords(const std::string& s);
bool isPalindrome(const std::string& s);
int sumEven(const std::vector<int>& v);
```

### Rules
- `reverseWords`: reverse order of words separated by spaces. Words = maximal
  non-space sequences. Output has single spaces, no leading/trailing spaces.
  Example: `"  hello   world "` → `"world hello"`.
- `isPalindrome`: case-sensitive, considers ALL characters (including spaces).
  Empty string is a palindrome. Example: `"abba"` → true, `"Abba"` → false.
- `sumEven`: sum of even numbers. Empty vector → 0.

### Constraints
- Time: O(n), extra space O(n) allowed.
- Must not modify inputs.

## Evaluation
Run: `g++ -std=c++17 -O2 -Wall -Wextra -o test1 test.cpp solution.cpp && ./test1`
All 30 asserts must pass. Any crash / leak / timeout = fail.

## Rubric (for human grader)
- Pass: all tests green, compiles clean with `-Wall -Wextra`.
- Partial: minor whitespace bug.
- Fail: wrong algorithm, crash on empty input.
