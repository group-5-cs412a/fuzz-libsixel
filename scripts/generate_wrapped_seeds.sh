#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
SOURCE_DIR="$ROOT_DIR/corpus/gif"
WRAPPED_DIR="$ROOT_DIR/corpus/wrapped_gif"
EXCLUDED_DIR="$ROOT_DIR/corpus/excluded"
EXTENDED_WRAPPED_DIR="$ROOT_DIR/corpus/wrapped_gif_extended"
CONTROL_BYTES=8
FAST_EXCLUDE_NAMES=("poc_load_gif.gif")

shopt -s nullglob

is_fast_excluded() {
    local name=$1
    local excluded

    for excluded in "${FAST_EXCLUDE_NAMES[@]}"; do
        if [ "$name" = "$excluded" ]; then
            return 0
        fi
    done

    return 1
}

wrap_seed() {
    local seed=$1
    local output_dir=$2
    local name
    local wrapped_seed

    name=$(basename "$seed")
    wrapped_seed="$output_dir/$name"

    head -c "$CONTROL_BYTES" /dev/zero > "$wrapped_seed"
    cat "$seed" >> "$wrapped_seed"
}

fast_gifs=("$SOURCE_DIR"/*.gif)

if [ ${#fast_gifs[@]} -eq 0 ]; then
    echo "Error: no GIF seeds found in $SOURCE_DIR"
    exit 1
fi

mkdir -p "$WRAPPED_DIR" "$EXTENDED_WRAPPED_DIR"
rm -f "$WRAPPED_DIR"/*.gif
rm -f "$EXTENDED_WRAPPED_DIR"/*.gif

for seed in "${fast_gifs[@]}"; do
    name=$(basename "$seed")
    if ! is_fast_excluded "$name"; then
        wrap_seed "$seed" "$WRAPPED_DIR"
    fi
    wrap_seed "$seed" "$EXTENDED_WRAPPED_DIR"
done

fast_count=$(find "$WRAPPED_DIR" -maxdepth 1 -type f -name '*.gif' | wc -l | tr -d ' ')
extended_count=${#fast_gifs[@]}
excluded_gifs=("$EXCLUDED_DIR"/*.gif)
for seed in "${excluded_gifs[@]}"; do
    wrap_seed "$seed" "$EXTENDED_WRAPPED_DIR"
    extended_count=$((extended_count + 1))
done

echo "Generated $fast_count fast wrapped seeds in $WRAPPED_DIR"
echo "Generated $extended_count extended wrapped seeds in $EXTENDED_WRAPPED_DIR"
