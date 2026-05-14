repository : https://github.com/group-5-cs412a/fuzz-libsixel/settings

## 1. Build and Run with Makefile (Recommended)
The recommended entrypoint is the project `Makefile`, which keeps AFL++ outputs on
the host under `outputs/<timestamp>/` so each fuzzing run is preserved separately.

First build with `make build`, then start fuzzing with `make fuzz` or `make fuzz-threaded` to launch multiple parallel instances.

To visualize progress, you can generate AFL plots with `make plot`. This will create a `plot/` directory inside your latest output run folder (e.g., `outputs/20260512-123456/plot/`). You can also specify a specific run directory with `make plot RUN_DIR=outputs/my-run`.

`make fuzz` uses a GIF-focused fast mode by default. To also exercise generic
image-loader dispatch, including non-GIF payloads that can reach GD/libpng/etc.,
run:

```bash
make fuzz BROAD_LOADER=1
```

To skip the short Truevision-triggering inputs during GIF-focused fuzzing, run:

```bash
make fuzz TRUEVISION_PATCH=1
```

The same option also works with `make fuzz-threaded`. It passes
`TRUEVISION_PATCH=1` to the harness, which skips wrapped inputs whose image
payload is 18 bytes or smaller after excluding the 8-byte control header.

To use the GIF dictionary during fuzzing, run:

```bash
make fuzz USE_DICT=1
```

The dictionary file (`gif.dict`) contains common GIF format keywords and structures
that aims to guide AFL++ mutations towards more meaningful GIF inputs. The `USE_DICT` flag works with `make fuzz`, `make fuzz-threaded`,
and `make fuzz-qemu`.


## 2. Build and Run Manually

### Build the Image
```bash
docker build -t libsixel-fuzzer .
```

### Start the Container
It is recommended to run the container as your current host user so that output files are not owned by root:
```bash
docker run --rm -it --user $(id -u):$(id -g) libsixel-fuzzer
```

### Manual Start (Single Instance)
```bash
afl-fuzz -t 1000 -m none -G 65536 -i /fuzzing/seeds -o /fuzzing/outputs -- /usr/local/bin/sixel-harness
```

Set `SIXEL_HARNESS_ALLOW_NONGIF=1` to let mutations that no longer have GIF
magic bytes reach libsixel's generic image loader. This is useful for broader
bug discovery but can be much slower.

Set `TRUEVISION_PATCH=1` to discard wrapped inputs whose image payload is not
greater than 18 bytes. The size check excludes the 8 control bytes consumed by
the harness.

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
- **Control Header Mutation**: An eight-byte selector drives valid encoder options before the GIF payload reaches `sixel_encoder_encode()`.
- **Fast GIF Gate**: By default, the harness skips payloads whose post-header bytes no longer start with `GIF87a` or `GIF89a`. Set `SIXEL_HARNESS_ALLOW_NONGIF=1` for broader loader fuzzing.
- **Truevision Patch Gate**: Set `TRUEVISION_PATCH=1` to skip image payloads of 18 bytes or less, excluding the 8-byte control header.

`afl-fuzz` is run with `-m none` because ASan needs more virtual memory than AFL's default memory limit allows.
Leak detection is disabled at runtime with `ASAN_OPTIONS=detect_leaks=0:abort_on_error=1:symbolize=0` so the campaign focuses on crashing memory errors instead of known process-exit leaks, and to stay compatible with AFL++'s ASan checks.

## 5. Seed Corpus

Raw GIF seeds live in `corpus/gif/`. Run `./scripts/generate_wrapped_seeds.sh` to
rebuild the wrapped corpora in `corpus/wrapped_gif/` and
`corpus/wrapped_gif_extended/`.

Why GIFs:
- The previous tiny-seed approach mostly pulled PNG files from the upstream
  `libsixel` tree.
- Mutating PNGs often gets blocked early by CRC validation, which reduces the
  amount of deeper image-decoding behavior AFL++ can explore.
- Small valid GIFs are cheaper to execute and stay structurally useful for
  longer under mutation.

### Wrapped Seeds

Wrapped seed format:

```text
8-byte control header || GIF87a/GIF89a payload
```

The control header is interpreted by `harness.c` as follows:

- **Byte 0:** Color mode and background color.
  - `byte0 & 3` selects color mode: `0` default adaptive palette, `1` high-color, `2` monochrome, `3` builtin palette.
  - `(byte0 >> 2) & 3` selects no background override, `#000000`, `#FFFFFF`, or `#FF0000`.
- **Byte 1:** Color count or builtin palette detail.
  - Default mode uses `byte1 & 7` to select `2, 4, 8, 16, 32, 64, 128, 256`.
  - Builtin mode uses `(byte1 >> 3) & 7` to select `xterm16, xterm256, vt340mono, vt340color, gray1, gray2, gray4, gray8`.
- **Byte 2:** Quality and diffusion.
  - `byte2 & 3` selects `auto, high, low, full`.
  - `(byte2 >> 2) % 9` selects `auto, none, fs, atkinson, jajuni, stucki, burkes, a_dither, x_dither`.
- **Byte 3:** Palette and quantization methods.
  - `byte3 & 1` selects palette type `rgb` or `hls`.
  - `(byte3 >> 1) % 3` selects largest-box method `auto, norm, lum`.
  - `(byte3 >> 3) & 3` selects representative color method `auto, center, average, histogram`.
- **Byte 4:** Output policy and flags.
  - `byte4 % 3` selects encode policy `auto, fast, size`.
  - Bits `0x04, 0x08, 0x10, 0x20, 0x40` enable 8-bit output, GRI limit, invert, ignore-delay, and static mode.
- **Byte 5:** Resize and resampling.
  - `byte5 % 10` selects `nearest, gaussian, hanning, hamming, bilinear, welsh, bicubic, lanczos2, lanczos3, lanczos4`.
  - `(byte5 >> 4) & 3` selects no resize, width-only, height-only, or width-and-height.
  - Resize dimensions come from `1, 2, 4, 8, 16, 32, 64`.
- **Byte 6:** Crop and crop/resize ordering.
  - `byte6 % 5` selects no crop or one of `1x1+0+0, 2x2+0+0, 4x4+1+1, 8x8+0+0`.
  - Bit `0x80` applies crop before resize; otherwise resize is configured before crop.
- **Byte 7:** Animation and macro options.
  - `byte7 % 3` selects loop mode `auto, force, disable`.
  - Bit `0x04` enables macro output.
  - Bit `0x08` sets a macro number from `(byte7 >> 4) & 0x0f`.

The harness intentionally avoids known option conflicts: `SIXEL_OPTFLAG_COLORS`
is only set in default adaptive-palette mode, not high-color, monochrome, or
builtin-palette mode.
