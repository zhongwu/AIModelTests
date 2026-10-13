#!/bin/bash
# Run the C++ suite for one AI model and archive results + timings.
# Usage: bash run_model.sh "model name"
set -u
cd "$(dirname "$0")"

MODEL="${1:?Usage: bash run_model.sh \"model name\"}"
SAFE="$(printf '%s' "$MODEL" | tr -c 'A-Za-z0-9._+-' '-' | sed 's/-\+/-/g; s/^-\|-$//g')"
[ -n "$SAFE" ] || SAFE="unnamed"
STAMP="$(date '+%Y%m%d-%H%M%S')"
RUNDIR="results/$SAFE/$STAMP"
n=1
while [ -e "$RUNDIR" ]; do
  n=$((n + 1))
  RUNDIR="results/$SAFE/${STAMP}-$n"
done
mkdir -p "$RUNDIR"

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}

CXX="${CXX:-g++}"
FLAGS="-std=c++17 -O2 -Wall -Wextra"
RUN_START="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
T0=$(date +%s%N)
mkdir -p "$RUNDIR/bin"

LEVELS_JSON=""
LEVELS_MD=""
PASS_COUNT=0
FAIL_COUNT=0
i=0
for lv in level1_easy level2_medium level3_hard level4_harder level5_hardest; do
  i=$((i + 1))
  case "$lv" in
    level1_easy)   SRC="level1_easy/test.cpp level1_easy/solution.cpp"; LIBS="" ;;
    level2_medium) SRC="level2_medium/test.cpp level2_medium/solution.cpp"; LIBS="" ;;
    level3_hard)   SRC="level3_hard/test.cpp"; LIBS="-pthread" ;;
    level4_harder) SRC="level4_harder/test.cpp"; LIBS="" ;;
    level5_hardest) SRC="level5_hardest/test.cpp"; LIBS="-pthread" ;;
  esac
  s=$(date +%s%N)
  # shellcheck disable=SC2086
  if $CXX $FLAGS $LIBS -o "$RUNDIR/bin/$lv" $SRC >"$RUNDIR/$lv.log" 2>&1 \
    && "$RUNDIR/bin/$lv" >>"$RUNDIR/$lv.log" 2>&1; then
    CODE=0
  else
    CODE=$?
  fi
  e=$(date +%s%N)
  SECS="$(awk "BEGIN {printf \"%.2f\", ($e - $s) / 1000000000}")"
  if [ "$CODE" -eq 0 ] && grep -q "ALL TESTS PASSED" "$RUNDIR/$lv.log"; then
    RES=true; ST="PASS"; PASS_COUNT=$((PASS_COUNT + 1))
  else
    RES=false; ST="FAIL"; FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
  echo "$lv: $ST (${SECS}s)"
  LEVELS_JSON="$LEVELS_JSON$(printf '{"level":"%s","passed":%s,"seconds":%s,"exitCode":%d,"log":"%s.log"},' "$lv" "$RES" "$SECS" "$CODE" "$lv")"
  LEVELS_MD="$LEVELS_MD$(printf '| %s | %s | %s | %s.log |\n' "$lv" "$ST" "$SECS" "$lv")"
done

T1=$(date +%s%N)
RUN_END="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
TOTAL="$(awk "BEGIN {printf \"%.2f\", ($T1 - $T0) / 1000000000}")"
LEVELS_JSON="[${LEVELS_JSON%,}]"
if [ "$FAIL_COUNT" -eq 0 ]; then OVERALL=true; OVERALL_TEXT="PASS"; else OVERALL=false; OVERALL_TEXT="FAIL"; fi

ESC_MODEL="$(json_escape "$MODEL")"
printf '{"model":"%s","suite":"cpp","startedAt":"%s","finishedAt":"%s","totalSeconds":%s,"overallPassed":%s,"levels":%s}\n' \
  "$ESC_MODEL" "$RUN_START" "$RUN_END" "$TOTAL" "$OVERALL" "$LEVELS_JSON" >"$RUNDIR/summary.json"

{
  echo "# Run: $MODEL (cpp)"
  echo ""
  echo "- Started: $RUN_START"
  echo "- Total: ${TOTAL}s"
  echo "- Result: $OVERALL_TEXT"
  echo ""
  echo "| Level | Result | Seconds | Log |"
  echo "|---|---|---|---|"
  printf '%s' "$LEVELS_MD"
} >"$RUNDIR/summary.md"

printf '{"run":"%s","suite":"cpp","startedAt":"%s","totalSeconds":%s,"passed":%d,"failed":%d,"overallPassed":%s}\n' \
  "$(basename "$RUNDIR")" "$RUN_START" "$TOTAL" "$PASS_COUNT" "$FAIL_COUNT" "$OVERALL" \
  >>"results/$SAFE/runs.jsonl"

echo "Results: $RUNDIR"
[ "$FAIL_COUNT" -eq 0 ]
