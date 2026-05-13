#!/bin/bash

# Usage: ./scripts/launch_fuzzer.sh <number_of_instances>
# Example: ./scripts/launch_fuzzer.sh 4

NUM_INSTANCES=${1:-1}
SEEDS="/fuzzing/seeds"
OUTPUTS="/fuzzing/outputs"
TARGET="/usr/local/bin/sixel-harness"
shopt -s nullglob

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

echo "Starting $NUM_INSTANCES AFL++ instances (Skipping deterministic stage for speed)..."

# 1. Start the Master instance (with -d for speed)
echo "Launching Master instance (main)..."
afl-fuzz -t 3000 -d -M main -m none -i "$INPUT_ARG" -o "$OUTPUTS" -- "$TARGET" > "$OUTPUTS/main.log" 2>&1 &
sleep 2

# 2. Start Secondary instances
if [ "$NUM_INSTANCES" -gt 1 ]; then
    for i in $(seq 1 $((NUM_INSTANCES - 1))); do
        echo "Launching Secondary instance (c$i)..."
        afl-fuzz -t 3000 -S "c$i" -m none -i "$INPUT_ARG" -o "$OUTPUTS" -- "$TARGET" > "$OUTPUTS/c$i.log" 2>&1 &
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
