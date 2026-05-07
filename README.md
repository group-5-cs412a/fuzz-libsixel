## 1. Build and Run

### Build the Image
```bash
docker build -t libsixel-fuzzer .
```

### Start the Container
```bash
docker run --rm -it libsixel-fuzzer
```

## 2. Launch Fuzzing

### Quick Start (Automatic Multi-core)
Use the included launch script to start a master and several secondary instances.
```bash
# Launch 4 parallel instances
./launch_fuzzer.sh 4
```

### Manual Start (Single Instance)
```bash
afl-fuzz -m none -i /fuzzing/seeds -o /fuzzing/outputs -- /usr/local/bin/sixel-harness @@
```

## 3. Triaging Crashes

When the fuzzer finds a crash, it is saved in `/fuzzing/outputs/<instance>/crashes/`.

### Analyze with GDB
To see where the program died:
```bash
gdb --args /usr/local/bin/sixel-harness /fuzzing/outputs/main/crashes/id:000000...
(gdb) run
(gdb) bt
```

## 4. Performance Optimizations
- **LTO Instrumentation**: Uses `afl-clang-lto` for collision-free coverage.
- **Persistent Mode**: The harness uses `__AFL_LOOP(1000)` to avoid process startup overhead.
- **Small Seeds**: Initial seeds are filtered to be `<= 200 bytes` to maximize execution speed.
- **Heavy Math Disabled**: The harness disables dithering and high-quality quantization to focus on parsing logic.

Redacted with Gemini CLI