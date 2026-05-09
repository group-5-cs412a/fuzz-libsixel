#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SOURCE_DIR="$ROOT_DIR/corpus/gif"
WRAPPED_DIR="$ROOT_DIR/corpus/wrapped_gif"

shopt -s nullglob

gifs=("$SOURCE_DIR"/*.gif)

if [ ${#gifs[@]} -eq 0 ]; then
    echo "Error: no GIF seeds found in $SOURCE_DIR"
    exit 1
fi

mkdir -p "$WRAPPED_DIR"
rm -f "$WRAPPED_DIR"/*.gif

for seed in "${gifs[@]}"; do
    name=$(basename "$seed")
    wrapped_seed="$WRAPPED_DIR/$name"

    printf '\0' > "$wrapped_seed"
    cat "$seed" >> "$wrapped_seed"
done

echo "Generated ${#gifs[@]} wrapped seeds in $WRAPPED_DIR"
