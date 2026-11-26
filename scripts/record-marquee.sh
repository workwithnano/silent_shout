#!/bin/bash
# Films the scrolling marquee on the pool simulator and samples the app's CPU while it runs.
# Called by `make record-marquee OUT=<file>` inside the sim lane's `run`, which holds the slot,
# boots the pool device and exports SIM_UDID. Never boots a simulator of its own.
#
#   scripts/record-marquee.sh <out.mp4> <xcodebuild destination>
#
# Writes <out> (upright, H.264), <out minus extension>-raw.mov (the simulator's own portrait
# recording), <base>-frame-N.png (four frames a second apart), and <base>-cpu.txt.
# MarqueeRecordingTests explains the marker-file handshake with the UI test.
set -euo pipefail

OUT=${1:?usage: record-marquee.sh <out.mp4> <destination>}
DEST=${2:?usage: record-marquee.sh <out.mp4> <destination>}
: "${SIM_UDID:?run this through sim-lane.sh run (make record-marquee)}"

ROOT=$(cd "$(dirname "$0")/.." && pwd)
case "$OUT" in /*) ;; *) OUT="$ROOT/$OUT" ;; esac
BASE="${OUT%.*}"
RAW="$BASE-raw.mov"
STATE="$ROOT/build/recordings/.state"
TOOL="$ROOT/build/recordings/.marquee-video"
mkdir -p "$(dirname "$OUT")" "$STATE"
rm -f "$STATE"/* "$RAW" "$OUT" "$BASE"-frame-*.png "$BASE-cpu.txt"

# The video tool (rotate, frames, compare) uses only AVFoundation and CoreGraphics.
xcrun swiftc -O -swift-version 6 -o "$TOOL" "$ROOT/scripts/marquee-video.swift"

XCB_LOG="$STATE/xcodebuild.log"
REC_LOG="$STATE/recorder.log"
xcb_pid=""
rec_pid=""
cleanup() {
  # Only the processes this script started.
  if [ -n "$rec_pid" ] && kill -0 "$rec_pid" 2>/dev/null; then kill -INT "$rec_pid" 2>/dev/null || true; wait "$rec_pid" 2>/dev/null || true; fi
  if [ -n "$xcb_pid" ] && kill -0 "$xcb_pid" 2>/dev/null; then kill "$xcb_pid" 2>/dev/null || true; fi
}
trap cleanup EXIT

# Waits until a marker file exists, or gives up after $2 seconds (returns 1).
wait_for() {
  local file=$1 limit=$2 waited=0
  while [ ! -e "$file" ]; do
    if [ -n "$xcb_pid" ] && ! kill -0 "$xcb_pid" 2>/dev/null; then echo "record-marquee: xcodebuild ended before $file" >&2; return 1; fi
    [ "$waited" -ge $((limit * 5)) ] && { echo "record-marquee: no $(basename "$file") after ${limit}s" >&2; return 1; }
    perl -e 'select(undef, undef, undef, 0.2)'
    waited=$((waited + 1))
  done
}

echo "record-marquee: running MarqueeRecordingTests (log: $XCB_LOG)"
TEST_RUNNER_MARQUEE_RECORD_DIR="$STATE" perl -e 'alarm 600; exec @ARGV' -- \
  xcodebuild -project "$ROOT/SilentShout.xcodeproj" -scheme SilentShout \
  -only-testing:SilentShoutUITests/MarqueeRecordingTests \
  -destination "$DEST" -derivedDataPath "$ROOT/build" -parallel-testing-enabled NO test \
  > "$XCB_LOG" 2>&1 &
xcb_pid=$!

wait_for "$STATE/ready" 400

xcrun simctl io "$SIM_UDID" recordVideo --codec=h264 --force "$RAW" > "$REC_LOG" 2>&1 &
rec_pid=$!
# The recorder prints this once frames are being written.
n=0
until grep -q "Recording started" "$REC_LOG" 2>/dev/null; do
  kill -0 "$rec_pid" 2>/dev/null || { echo "record-marquee: recorder exited:"; cat "$REC_LOG"; exit 1; }
  [ "$n" -ge 150 ] && { echo "record-marquee: recorder did not start in 30 s" >&2; exit 1; }
  perl -e 'select(undef, undef, undef, 0.2)'; n=$((n + 1))
done
rec_start=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
touch "$STATE/recording"

wait_for "$STATE/shouting" 60
shout_at=$(perl -MTime::HiRes=time -e "printf '%.3f', time - $rec_start")
echo "record-marquee: shout up ${shout_at}s into the recording"

# CPU while the marquee runs. Simulator apps are host processes. `top` gives instantaneous
# figures from its second sample on (the first is an average since launch), so take 11 and
# drop the first. The simulator's render server (backboardd) does Core Animation's work, so it
# is sampled too.
app_pid=$(pgrep -f '/SilentShout\.app/SilentShout( |$)' | head -1 || true)
bb_pid=$(pgrep -f "Devices/$SIM_UDID/.*backboardd|CoreSimulator.*/backboardd$" | head -1 || true)
[ -z "$bb_pid" ] && bb_pid=$(pgrep -x backboardd | head -1 || true)
{
  echo "app pid: ${app_pid:-not found}   simulator backboardd pid: ${bb_pid:-not found}"
  if [ -n "$app_pid" ]; then
    args=(-pid "$app_pid"); [ -n "$bb_pid" ] && args+=(-pid "$bb_pid")
    top -l 11 -s 1 "${args[@]}" -stats pid,cpu,command 2>/dev/null \
      | awk -v app="$app_pid" -v bb="$bb_pid" '
          /^PID/ { sample++; next }
          sample > 1 && $1 == app { a[++na] = $2 }
          sample > 1 && bb != "" && $1 == bb { b[++nb] = $2 }
          END {
            line = "app %CPU samples:"; s = 0; for (i = 1; i <= na; i++) { line = line " " a[i]; s += a[i] }
            print line; if (na) printf "app mean: %.1f%% over %d samples\n", s / na, na
            if (nb) { line = "backboardd %CPU samples:"; s = 0; for (i = 1; i <= nb; i++) { line = line " " b[i]; s += b[i] }
              print line; printf "backboardd mean: %.1f%% over %d samples\n", s / nb, nb }
          }'
  fi
} | tee "$BASE-cpu.txt"

wait_for "$STATE/done" 60
kill -INT "$rec_pid"
wait "$rec_pid" || true
rec_pid=""

# Let the test finish (it terminates the app and turns the phone back upright).
wait "$xcb_pid" || echo "record-marquee: xcodebuild exited non-zero; see $XCB_LOG" >&2
xcb_pid=""
grep -E "Test Case .*(passed|failed|skipped)|TEST (SUCCEEDED|FAILED)" "$XCB_LOG" | tail -3 || true

"$TOOL" rotate "$RAW" "$OUT"
# Four frames a second apart, starting 3 s after the shout was reported up.
times=$(perl -e "printf '%.3f %.3f %.3f %.3f', map { $shout_at + \$_ } 3, 4, 5, 6")
"$TOOL" frames "$RAW" "$BASE-frame" $times
ls -l "$RAW" "$OUT" "$BASE"-frame-*.png
"$TOOL" info "$OUT"
