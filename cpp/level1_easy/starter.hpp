#pragma once
#include <string>
#include <vector>

// Reverse order of words (see TASK.md). Single spaces, trimmed.
std::string reverseWords(const std::string& s);

// Case-sensitive palindrome check on all chars. "" -> true.
bool isPalindrome(const std::string& s);

// Sum of even numbers. {} -> 0.
int sumEven(const std::vector<int>& v);
