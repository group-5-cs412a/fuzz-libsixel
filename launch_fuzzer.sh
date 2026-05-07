#!/bin/bash

# Usage: ./launch_fuzzer.sh <number_of_instances>
# Example: ./launch_fuzzer.sh 4

NUM_INSTANCES=${1:-1}
SEEDS="/fuzzing/seeds"
OUTPUTS="/fuzzing/outputs"
TARGET="/usr/local/bin/sixel-harness"

mkdir -p "$SEEDS" "$OUTPUTS"

if [ ! -d "$SEEDS" ] || [ -z "$(ls -A "$SEEDS")" ]; then
    echo "Error: Seeds directory $SEEDS is empty or missing."
    exit 1
fi

echo "Starting $NUM_INSTANCES AFL++ instances (Skipping deterministic stage for speed)..."

# 1. Start the Master instance (with -d for speed)
echo "Launching Master instance (main)..."
afl-fuzz -d -M main -m none -i "$SEEDS" -o "$OUTPUTS" -- "$TARGET" @@ > "$OUTPUTS/main.log" 2>&1 &
sleep 2

# 2. Start Secondary instances
if [ "$NUM_INSTANCES" -gt 1 ]; then
    for i in $(seq 1 $((NUM_INSTANCES - 1))); do
        echo "Launching Secondary instance (c$i)..."
        afl-fuzz -S "c$i" -m none -i "$SEEDS" -o "$OUTPUTS" -- "$TARGET" @@ > "$OUTPUTS/c$i.log" 2>&1 &
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
    echo "Note: If speed is still low, ensure you are using TINY seeds."
    sleep 5
done
