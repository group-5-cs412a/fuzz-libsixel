
## 1. Build and Run with Makefile (Recommended)
The recommended entrypoint is the project `Makefile`, which keeps AFL++ outputs on
the host under `outputs/<timestamp>/` so each fuzzing run is preserved separately.

First build with `make build`, then start fuzzing with `make fuzz` or `make fuzz-threaded` to launch multiple parallel instances.


## 2. Build and Run Manually

### Build the Image
```bash
docker build -t libsixel-fuzzer .
```

### Start the Container
```bash
docker run --rm -it libsixel-fuzzer
```

### Manual Start (Single Instance)
```bash
afl-fuzz -t 5000 -m none -i /fuzzing/seeds -o /fuzzing/outputs -- /usr/local/bin/sixel-harness
```

The wrapped GIF corpus currently includes at least one slow seed, so the
default AFL timeout of `1000 ms` is too low for a fresh dry run. Use
`-t 5000` unless you also trim the seed set.




## 3. Triaging Crashes

When the fuzzer finds a crash, it is saved in `/fuzzing/outputs/<instance>/crashes/`.

### Analyze with GDB
To see where the program died, pipe the crash into the harness via standard input (since the harness now reads from stdin):
```bash
gdb /usr/local/bin/sixel-harness
(gdb) run < /fuzzing/outputs/main/crashes/id:000000...
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

Raw GIF seeds live in `corpus/gif/`. Run `./generate_wrapped_seeds.sh` to
rebuild the wrapped corpus in `corpus/wrapped_gif/`.

Why GIFs:
- The previous tiny-seed approach mostly pulled PNG files from the upstream
  `libsixel` tree.
- Mutating PNGs often gets blocked early by CRC validation, which reduces the
  amount of deeper image-decoding behavior AFL++ can explore.
- Small valid GIFs are cheaper to execute and stay structurally useful for
  longer under mutation.

### Wrapped Seeds

Current byte-0 mapping uses bitwise flags to configure multiple options simultaneously:

- **Bits 0-1 (2 bits):** Quality (`auto`, `high`, `low`, `full`)
- **Bits 2-4 (3 bits):** Diffusion (`auto`, `none`, `fs`, `atkinson`, `jajuni`, `stucki`, `burkes`, `a_dither`)
- **Bits 5-6 (2 bits):** Background Color (`None`, `#000000`, `#FFFFFF`, `#FF0000`)
- **Bit 7 (1 bit):** Encode Policy (`fast`, `auto`)
