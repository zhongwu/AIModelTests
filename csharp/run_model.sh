#!/bin/bash
# Run the C# suite for one AI model and archive results + timings.
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

RUN_START="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
T0=$(date +%s%N)

LEVELS_JSON=""
LEVELS_MD=""
PASS_COUNT=0
FAIL_COUNT=0
for lv in Level1.Easy Level2.Medium Level3.Hard Level4.Harder Level5.Hardest; do
  s=$(date +%s%N)
  if dotnet run -c Release --project "$lv/$lv.csproj" >"$RUNDIR/$lv.log" 2>&1; then
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
printf '{"model":"%s","suite":"csharp","startedAt":"%s","finishedAt":"%s","totalSeconds":%s,"overallPassed":%s,"levels":%s}\n' \
  "$ESC_MODEL" "$RUN_START" "$RUN_END" "$TOTAL" "$OVERALL" "$LEVELS_JSON" >"$RUNDIR/summary.json"

{
  echo "# Run: $MODEL (csharp)"
  echo ""
  echo "- Started: $RUN_START"
  echo "- Total: ${TOTAL}s"
  echo "- Result: $OVERALL_TEXT"
  echo ""
  echo "| Level | Result | Seconds | Log |"
  echo "|---|---|---|---|"
  printf '%s' "$LEVELS_MD"
} >"$RUNDIR/summary.md"

printf '{"run":"%s","suite":"csharp","startedAt":"%s","totalSeconds":%s,"passed":%d,"failed":%d,"overallPassed":%s}\n' \
  "$(basename "$RUNDIR")" "$RUN_START" "$TOTAL" "$PASS_COUNT" "$FAIL_COUNT" "$OVERALL" \
  >>"results/$SAFE/runs.jsonl"

echo "Results: $RUNDIR"
[ "$FAIL_COUNT" -eq 0 ]
