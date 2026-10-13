// Level 1 tests — no external deps.
#include "starter.hpp"
#include <cassert>
#include <iostream>

#define CHECK(cond) do { \
    if (!(cond)) { std::cerr << "FAIL line " << __LINE__ << ": " #cond "\n"; return 1; } \
} while (0)

int main() {
    // reverseWords
    CHECK(reverseWords("  hello   world ") == "world hello");
    CHECK(reverseWords("a") == "a");
    CHECK(reverseWords("") == "");
    CHECK(reverseWords("   ") == "");
    CHECK(reverseWords("a b c") == "c b a");
    CHECK(reverseWords("  ab  cd  ") == "cd ab");
    CHECK(reverseWords("hello") == "hello");
    CHECK(reverseWords(" a  ") == "a");
    CHECK(reverseWords("one two") == "two one");

    // isPalindrome
    CHECK(isPalindrome("") == true);
    CHECK(isPalindrome("a") == true);
    CHECK(isPalindrome("abba") == true);
    CHECK(isPalindrome("Abba") == false);
    CHECK(isPalindrome("abc") == false);
    CHECK(isPalindrome("a a") == true);
    CHECK(isPalindrome("  ") == true);
    CHECK(isPalindrome("ab a") == false);
    CHECK(isPalindrome("racecar") == true);

    // sumEven
    CHECK(sumEven({}) == 0);
    CHECK(sumEven({1, 3, 5}) == 0);
    CHECK(sumEven({2, 4, 6}) == 12);
    CHECK(sumEven({1, 2, 3, 4}) == 6);
    CHECK(sumEven({-2, -3, 4}) == 2);
    CHECK(sumEven({0}) == 0);
    CHECK(sumEven({-1, -5}) == 0);
    CHECK(sumEven({1000000, 1000001}) == 1000000);

    std::cout << "Level 1: ALL TESTS PASSED\n";
    return 0;
}
