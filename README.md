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

The launcher wraps each GIF seed with a single leading control byte. The
harness interprets that byte as a selector for a small set of valid
`img2sixel` flag/value pairs, and treats the remaining bytes as the GIF input.

### Manual Start (Single Instance)
```bash
afl-fuzz -t 5000 -m none -x /fuzzing/img2sixel.dict -i /fuzzing/afl-seeds -o /fuzzing/outputs -- /usr/local/bin/sixel-harness
```

The wrapped GIF corpus currently includes at least one slow seed, so the
default AFL timeout of `1000 ms` is too low for a fresh dry run. Use
`-t 5000` unless you also trim the seed set.

Current byte-0 mapping is intentionally small:

- `0`: no extra flag
- `1`: `-B '#000000'`
- `2`: `-B '#ffffff'`
- `3`: `-B '#ff00ff'`
- `4`: `-q low`
- `5`: `-q high`
- `6`: `-d none`
- `7`: `-S`

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
- **Simple Flag Mutation**: A one-byte selector drives a tiny set of valid `img2sixel` options before the GIF payload reaches `sixel_encoder_encode()`.

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
