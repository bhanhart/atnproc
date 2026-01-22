#!/usr/bin/env bash
set -euo pipefail

# Simulated shutdown test for atn_capture_convert
TMPDIR=$(mktemp -d)
TESTBIN=$TMPDIR/bin
mkdir -p "$TESTBIN"

# fake tcpdump
cat > "$TESTBIN/fake_tcpdump" <<'EOF'
#!/usr/bin/env bash
while true; do echo "FAKE_TCPDUMP line"; sleep 0.2; done
EOF
chmod +x "$TESTBIN/fake_tcpdump"

# fake awk
cat > "$TESTBIN/fake_awk" <<'EOF'
#!/usr/bin/env bash
while IFS= read -r l; do echo "FAKE_AWK:$l"; done
EOF
chmod +x "$TESTBIN/fake_awk"

# placeholder actual awk used by runtime
mkdir -p "$TMPDIR/opt/muac"
cat > "$TMPDIR/opt/muac/rtcd_routerlog.awk" <<'EOF'
# placeholder awk
{ print }
EOF

# copy capture script to tmp and make executable
cp capture_convert/online/opt/muac/atn_capture_convert.sh "$TMPDIR/atn_capture_convert.sh"
chmod +x "$TMPDIR/atn_capture_convert.sh"

# prepare env
export ARCHIVE_DIR="$TMPDIR/archive"
mkdir -p "$ARCHIVE_DIR"
export NETWORK_INTERFACE=net3
export RTCD_SNIFFED_ADDRESS=192.0.2.1
export RETENTION_DAYS=1
export RTCD_AWK_PATH="$TMPDIR/opt/muac/rtcd_routerlog.awk"

# run capture with fake tcpdump via PATH and redirect output
env PATH="$TESTBIN:$PATH" nohup "$TMPDIR/atn_capture_convert.sh" >"$TMPDIR/run.log" 2>&1 &
PID=$!

# allow startup
sleep 1
START=$(date +%s.%N)

# send SIGTERM
if kill -0 "$PID" 2>/dev/null; then
    kill -TERM "$PID" 2>/dev/null || true
else
    echo "process $PID not found when attempting to terminate"
fi

wait "$PID" || true
END=$(date +%s.%N)
ELAPSED=$(awk -v s="$START" -v e="$END" 'BEGIN{print e-s}')
printf "elapsed=%s\n" "$ELAPSED"

printf "%b" "--- run.log (tail) ---\n"
tail -n 200 "$TMPDIR/run.log" || true

printf "%b" "--- archive listing ---\n"
ls -l "$ARCHIVE_DIR" || true

printf "%b" "--- health file ---\n"
cat "$ARCHIVE_DIR/.current_pipeline" 2>/dev/null || echo '(none)'

# cleanup
rm -rf "$TMPDIR"

exit 0
