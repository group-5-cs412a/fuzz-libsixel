#!/bin/bash

# Usage: ./launch_fuzzer.sh <number_of_instances> <timeout_ms> <mode: native|qemu>
# Example: ./launch_fuzzer.sh 4 500 qemu

NUM_INSTANCES=${1:-1}
TIMEOUT=${2:-3000}
MODE=${3:-native}
SEEDS="/fuzzing/seeds"
OUTPUTS="/fuzzing/outputs"
TARGET="/usr/local/bin/sixel-harness"
AFL_FLAGS=""
if [ "$MODE" = "qemu" ]; then
    echo "Running in QEMU mode..."
    TARGET="/usr/local/bin/sixel-harness-qemu"
    AFL_FLAGS="-Q"

    ARCH=$(uname -m)
    if [[ "$ARCH" == "arm64" || "$ARCH" == "aarch64" ]]; then
        echo "Note: QASan is disabled because it is often unstable on arm64/aarch64."
    else
        export AFL_USE_QASAN=1
    fi
fi

mkdir -p "$SEEDS" "$OUTPUTS"

seeds=("$SEEDS"/*.gif)

if [ ${#seeds[@]} -eq 0 ]; then
    echo "Error: no wrapped GIF seeds found in $SEEDS"
    exit 1
fi

INPUT_ARG="$SEEDS"
if [ -d "$OUTPUTS/main" ]; then
    echo "Existing AFL output detected in $OUTPUTS; resuming with -i-"
    INPUT_ARG="-"
fi

echo "Starting $NUM_INSTANCES AFL++ instances in $MODE mode with timeout ${TIMEOUT}ms..."

# 1. Start the Master instance (with -d for speed)
echo "Launching Master instance (main)..."
afl-fuzz $AFL_FLAGS -t "$TIMEOUT" -d -M main -m none -i "$INPUT_ARG" -o "$OUTPUTS" -- "$TARGET" > "$OUTPUTS/main.log" 2>&1 &
sleep 2

# Check if the master instance actually started
if ! pgrep -x afl-fuzz > /dev/null; then
    echo "Error: AFL++ failed to start. Check $OUTPUTS/main.log for details:"
    cat "$OUTPUTS/main.log"
    exit 1
fi

# 2. Start Secondary instances
if [ "$NUM_INSTANCES" -gt 1 ]; then
    for i in $(seq 1 $((NUM_INSTANCES - 1))); do
        echo "Launching Secondary instance (c$i)..."
        afl-fuzz $AFL_FLAGS -t "$TIMEOUT" -S "c$i" -m none -i "$INPUT_ARG" -o "$OUTPUTS" -- "$TARGET" > "$OUTPUTS/c$i.log" 2>&1 &
    done
fi

# Live Monitor
while true; do
    clear
    echo "Fuzzing Status (Press Ctrl+C to exit monitor)"
    echo "----------------------------------------------------"
    afl-whatsup "$OUTPUTS"
    echo "----------------------------------------------------"
    echo "Active AFL processes: $(pgrep -c afl-fuzz)"
    echo "Note: speed depends heavily on keeping the GIF seed corpus small."
    sleep 5
done
