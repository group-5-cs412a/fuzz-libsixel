#!/bin/bash
# Ensure libraries are found
export LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}
shopt -s nullglob

seeds=(/fuzzing/seeds/*.gif)

if [ ${#seeds[@]} -eq 0 ]; then
    echo "Error: no GIF seeds found in /fuzzing/seeds"
    exit 1
fi

# Test if img2sixel works on all seeds
echo "Testing img2sixel on seeds..."
for seed in "${seeds[@]}"; do
    echo "Processing $seed"
    /usr/local/bin/img2sixel -o /dev/null "$seed"
    if [ $? -ne 0 ]; then
        echo "Error: img2sixel failed on $seed"
        exit 1
    fi
done
echo "All seeds processed successfully."

echo "Testing with AFL_DEBUG=1..."
AFL_DEBUG=1 /usr/local/bin/img2sixel -o /dev/null "${seeds[0]}"
