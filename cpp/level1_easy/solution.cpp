#include "starter.hpp"
#include <sstream>

std::string reverseWords(const std::string& s) {
    std::istringstream in(s);
    std::string word, out;
    while (in >> word) {
        if (!out.empty()) out = word + " " + out;
        else out = word;
    }
    return out;
}

bool isPalindrome(const std::string& s) {
    size_t i = 0, j = s.size();
    if (j == 0) return true;
    --j;
    while (i < j) {
        if (s[i] != s[j]) return false;
        ++i; --j;
    }
    return true;
}

int sumEven(const std::vector<int>& v) {
    int sum = 0;
    for (int x : v) if (x % 2 == 0) sum += x;
    return sum;
}
