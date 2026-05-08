## 1. Build and Run

### Build the Image
```bash
docker build -t libsixel-fuzzer .
```

### Start the Container
```bash
docker run --rm -it libsixel-fuzzer
```

The image includes a vendored GIF seed corpus from `corpus/gif/`.

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
- **ASan Enabled**: `libsixel` and the AFL harness are built with AddressSanitizer via `AFL_USE_ASAN=1`.
- **LTO Instrumentation**: Uses `afl-clang-lto` for collision-free coverage.
- **Persistent Mode**: The harness uses `__AFL_LOOP(1000)` to avoid process startup overhead.
- **GIF-Focused Seeds**: Initial seeds come from a vendored corpus of small GIF files instead of upstream PNG-heavy samples.
- **Heavy Math Disabled**: The harness disables dithering and high-quality quantization to focus on parsing logic.

`afl-fuzz` is run with `-m none` because ASan needs more virtual memory than AFL's default memory limit allows.
Leak detection is disabled at runtime with `ASAN_OPTIONS=detect_leaks=0:abort_on_error=1:symbolize=0` so the campaign focuses on crashing memory errors instead of known process-exit leaks, and to stay compatible with AFL++'s ASan checks.

## 5. Seed Corpus

The fuzzing corpus is stored in `corpus/gif/` and copied into `/fuzzing/seeds`
during the Docker build.

Why GIFs:
- The previous tiny-seed approach mostly pulled PNG files from the upstream
  `libsixel` tree.
- Mutating PNGs often gets blocked early by CRC validation, which reduces the
  amount of deeper image-decoding behavior AFL++ can explore.
- Small valid GIFs are cheaper to execute and stay structurally useful for
  longer under mutation.

Redacted with Gemini CLI
