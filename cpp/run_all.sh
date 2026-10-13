#!/bin/bash
set -e
cd "$(dirname "$0")"
CXX=${CXX:-g++}
FLAGS="-std=c++17 -O2 -Wall -Wextra"

echo "=== Level 1 (easy) ==="
$CXX $FLAGS -o /tmp/test1 level1_easy/test.cpp level1_easy/solution.cpp && /tmp/test1

echo "=== Level 2 (medium) ==="
$CXX $FLAGS -o /tmp/test2 level2_medium/test.cpp level2_medium/solution.cpp && /tmp/test2

echo "=== Level 3 (hard) ==="
$CXX $FLAGS -pthread -o /tmp/test3 level3_hard/test.cpp && /tmp/test3

echo "=== Level 4 (harder) ==="
$CXX $FLAGS -o /tmp/test4 level4_harder/test.cpp && /tmp/test4

echo "=== Level 5 (hardest) ==="
$CXX $FLAGS -pthread -o /tmp/test5 level5_hardest/test.cpp && /tmp/test5

echo "ALL LEVELS PASSED"
