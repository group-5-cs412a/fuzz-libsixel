// A compact Typst template modeled after the USENIX proceedings style.
// It uses US letter paper, a 7in text block, two 3.33in columns, Times-like
// typography, and an unnumbered proceedings-style title block.

#import "@preview/codelst:2.0.2": sourcecode, code-frame

#let lab-code-frame(code) = code-frame(
  fill: rgb("#f7f9fc"),
  stroke: 0.7pt + rgb("#6b8fca"),
  inset: (x: 0.45em, y: 0.45em),
  radius: 3pt,
  text(size: 8pt, code),
)

#let lab-code(
  lang: "text",
  numbering: "1",
  body,
) = sourcecode(
  lang: lang,
  numbering: numbering,
  frame: lab-code-frame,
  body,
)

#let simple-code-frame(code) = code-frame(
  stroke: none,
  fill: rgb("#f7f9fc"),
  inset: (x: 0.25em, y: 0.25em),
  text(size: 6pt, code),
)
#let  simple-code(
  lang: "text",
  numbering: "1",
  body,
) = sourcecode(
  lang: lang,
  numbering: numbering,
  frame: simple-code-frame,
  body,
)

#let lab-table(..args) = {
  set text(size: 8pt)
  table(
    stroke: 0.45pt + rgb("#6b8fca"),
    fill: (x, y) => if y == 0 { rgb("#eef3fb") } else { none },
    inset: (x: 4.5pt, y: 3.5pt),
    align: (x, y) => if y == 0 { center + horizon } else { center + horizon },
    ..args,
  )
}



#let usenix(
  title: none,
  authors: (),
  date: none,
  abstract: none,
  bibliography: none,
  body,
) = {
  set document(title: title)
  set page(
    paper: "us-letter",
    margin: (
      left: 0.75in,
      right: 0.75in,
      top: 1in,
      bottom: 1in,
    ),
    numbering: "1",
    number-align: center,
  )
  set text(
    font: "Times New Roman",
    size: 10pt,
    lang: "en",
    region: "US",
  )
  set par(justify: true, leading: 0.65em, spacing: 0.9em, first-line-indent: 1.5em)
  set heading(numbering: "1.1")
  set list(indent: 1.2em, body-indent: 0.5em)
  set enum(indent: 1.2em, body-indent: 0.5em)
  set math.equation(numbering: "(1)")

  show heading.where(level: 1): it => {
    v(0.85em)
    text(size: 12pt, weight: "bold", it)
    v(0.35em)
  }
  show heading.where(level: 2): it => {
    v(0.65em)
    text(size: 10pt, weight: "bold", it)
    v(0.2em)
  }
  show heading.where(level: 3): it => {
    v(0.45em)
    text(size: 10pt, weight: "bold", style: "italic", it)
    h(0.5em)
  }
  show figure.caption: it => {
    set text(size: 9pt)
    align(center, it)
  }
  show footnote.entry: set text(size: 8pt)
  show ref: it => text(fill: black, it)
  show link: it => text(fill: black, it)

  block(width: 100%, height: 2.5in)[
    #align(center)[
      #v(1fr)
      #v(2em)
      #text(size: 14pt, weight: "bold", title)

      #v(0.375in)

      #text(size: 12pt)[
        #grid(
          columns: authors.map(_ => 1fr),
          gutter: 1.4em,
          ..authors.map(author => align(center)[
            #author.name\
            #text(style: "italic", author.affiliation)\
            #if author.at("email", default: none) != none {
              link("mailto:" + author.email)[#author.email]
            }
          ]),
        )
      ]

      #v(1fr)
    ]
  ]

  columns(2, gutter: 0.33in)[
    #if abstract != none {
      block(width: 100%)[
        #align(center, text(size: 12pt, weight: "bold")[Introduction])
        #v(0.35em)
        #abstract
      ]


    }

    #body

    #if bibliography != none {
      v(0.8em)
      bibliography
    }
  ]
}

#show: usenix.with(
  title: [Fuzzing Libsixel \
    A report for CS-412],
  abstract: [
    This report details the design, executions and analysis of a coverage guided fuzzing campaign on the open-source library `libsixel` using the AFL++ fuzzer. The target repository was pinned to version 1.8.7, to ensure reproducibility.

    `libsixel` is an encoder/decoder library for SIXEL, an image format for printer and terminal imaging.

    The project is comprised of two parts: white-box fuzzing (source-instrumented) and black-box (binary-only, using QEMU).
  ],
  authors: (
    (
      name: [Maria Bennani],
      affiliation: [EPFL],
    ),
    (
      name: [Sean Perazzolo],
      affiliation: [EPFL],
    ),
    (
      name: [Valuthy Karunakaran],
      affiliation: [EPFL],
    ),
  ),
  bibliography: none,
)

= Harness Design

== Selected Entrypoint And Considered Alternatives

For this campaign, we selected the *encoding path* of the library, specifically targeting the `sixel_encoder_encode` function. 

Even tough the guidelines suggested fuzzing the decoding path, recently identified vulnerabilities were due to bugs in the encoding path.
This made the encoder a highly attractive target.

We initially considered fuzzing the high-level `img2sixel` function. However, we rejected this approach because high-level wrappers introduce unnecessary overhead (e.g. command-line argument parsing, I/O operations, ...). By writing a custom harness directly around `sixel_encoder_encode`, we skip all non-encoding related functionality.

We also considered using a PNG corpus, but due to strict checks by the parsing library (`libpng`), our fuzzer was not able to reach the encoding logic. Inspired by the recent CVE, we switched to a corpus of GIF files, which are not subject to such strict checks and are still able to trigger the encoding logic.

== Data Flow and Guards
Each AFL ++ test case is split into two parts: a 8-byte control header and the raw image payload.

The first 8-bytes are parsed by the harness and mapped to configuration options. They are passed to the library via `sixel_encoder_setopt` to configureencoder options such as color mode, quality, diffusion, resize/crop behavior, and animation-related flags.

The remaining bytes represents the image and are written to a temporary file. The latter is passed to `sixel_encoder_encode`, which expects a file path as input. Note that the harness receives each AFL++ test case through `stdin`, rather than through the usual `@@` filename argument, avoiding I/0 overhead.

The main data flow is therefore: 

#simple-code[

`AFL++ testcase -> stdin -> [8-byte option header] + [GIF payload] -> temporary GIF file -> sixel_encoder_encode`.
]
This lets AFL++ mutate both the image contents and the encoder configuration. The option bytes are mapped to fixed valid strings, to ensure the fuzzer explores many combinations of `libsixel` behavior.


The harness contains several guards to allow the fuzzer to efficiently explore the library:  
1. A guard ensures that the test case is at least 8 bytes long to contain the control header. This is needed because the harness expects the first 8 bytes to be valid options, and shorter inputs would be rejected before reaching the library code.
2. A guard ensures that the test case also contains a complete 6-byte GIF header after the control bytes. This is needed because the harness reconstructs an image file before calling the library API. Inputs shorter than this would only exercise trivial file rejection and would not reach the interesting decoder or encoder code. _Note that this guard can be removed to allow broader exploration of the file parsing logic with_ `make FUZZ BROAD_LOADER=1`.
3. We then have various other guards to ensure the harness passes valid options / files to the library, such as `if (fd < 0) continue;` to ensure the file has been successfully written or  `if (status != SIXEL_OK) continue;` which ensures the option values are valid and accepted by the library.


We also guard all harness option selection by mapping arbitrary AFL++ bytes into finite option sets using masks or modulo operations. This keeps crashes attributable to the library code and not to the harness (e.g. by preventing invalid option values from being passed to the library).

Finally the resize and crop options are chosen from small fixed dictionaries. This bounds generated image dimensions and crop regions, preventing AFL++ from spending time on huge allocations, very slow transformations, or timeout-heavy inputs while still exercising scaling, cropping, and resampling code.


= Instrumentation and Sanitizers

// List every compiler flag and patch you applied to the target library. For each one, explain what it does and what would happen if you omitted it. If you patched the library (e.g., removing checksums), explain the effect on path discovery.
== Target Version 
We built *`libsixel v1.8.7`*, the latest stable release of the library. At the time of writting, two releases candidates were published (r1, r2), they address security vulnerabilities in the encoding path: These CVEs acts as a benchmark for our campaign as we should be able to find them with our setup, and they provide a good case study, as well as motivate our choice of fuzzing the encoder instead of the decoder.

== Coverage Instrumentation

We instrumented the library with AFL++'s `afl-clang-lto` / `afl-clang-lto++`, which inserts compile-time edge coverage. This gives AFL++ precise feedback for input selection. 
#sourcecode(
  lang: "bash",
  frame: lab-code-frame,
)[```bash
CC=afl-clang-lto CXX=afl-clang-lto++
```]

== *AddressSanitizer*

We also built the library with AddressSanitizer (ASan) to detect memory safety bugs. This allows us to catch memory corruption issues that might not immediately cause a crash, improving our chances of finding security vulnerabilities.
If omitted, AFL++ would still find hard crashes, but many invalid reads/writes would remain silent or become harder-to-reproduce later crashes.
#sourcecode(
  lang: "bash",
  frame: lab-code-frame,
)[```bash
ENV AFL_USE_ASAN=1
```]

Because ASan reserves a large virtual address space, we run AFL++ with `-m none`; otherwise AFL++'s default memory limit can kill valid ASan-instrumented executions.

At runtime, we used the following ASAN_OPTIONS\
#sourcecode(
  lang: "bash",
  frame: lab-code-frame,
)[```bash
detect_leaks=0
abort_on_error=1
symbolize=0
```]
Leak detection was disabled because the persistent harness intentionally runs many iterations in one process, and leak reports at process exit are less useful for this campaign than immediate memory-safety crashes. `abort_on_error=1` ensures sanitizer findings terminate the process in a way AFL++ records as a crash. `symbolize=0` avoids the overhead of online symbolization during fuzzing; symbolization can be done later during triage.


== Build Configuration

The flags `-g -O2` were used to include debug symbols for better crash triage and to optimize the code for more realistic performance.

`--prefix=/usr/local` ensures the harness links against the freshly built instrumented library. `--with-gd`, `--with-jpeg`, and `--with-png` enable the image backends relevant to realistic encoder inputs; `--with-gd` is especially important for GIF handling. `--with-libcurl=no`, `--with-gdk-pixbuf2=no`, and `--disable-python` remove network, GUI, and language-binding components that our harness does not exercise.

== Linking

When linking the final harness, we used `-Wl,--whole-archive -lsixel -Wl,--no-whole-archive`. This forces the linker to include the full static `libsixel` archive in the final binary instead of only the object files directly referenced by the harness. This is useful for instrumentation accounting and comparison because the final binary contains the library code rather than only a minimal linker-selected subset. Without `--whole-archive`, the binary would be smaller, but some instrumented library edges would be absent from the final executable.

== Patching
The library was configured with `--disable-shared --enable-static`. This makes the harness link against a static `libsixel` archive instead of a shared library. Static linking makes the fuzzing binary self-contained and ensures that the instrumented library code is the code executed by AFL++. If we used an uninstrumented shared system library by mistake, AFL++ would mainly see coverage from the harness rather than from the target library.





We did not apply a source patch to `libsixel`. In particular, there was no checksum-removal patch comparable to the `libpng` CRC patch discussed in the handout. Our main format was GIF, whose magic-byte check is handled at the harness level by preserving or filtering for `GIF87a`/`GIF89a`.

The optional `TRUEVISION_PATCH=1` setting in our setup is not a patch to the target library; it is a harness-side filter that skips very small image payloads to avoid shallow file-detection behavior and focus executions on deeper parsing paths.



= Seed Corpus and Dictionary
// Describe your seeds and dictionary. Using the dictionary and havoc/splice rows from your AFL++ status screen, quantify how many new paths each strategy contributed. Explain what the dictionary entries represent in formal terms (hint: think grammar/language theory).
We selected a raw seed corpus of 10 small GIF files that cover a variety of features of the GIF format. The corpus includes both `GIF87a` and `GIF89a` files, 1x1 edge-case images, transparent GIFs, interlaced and non-interlaced variants of the same image, small 32x32 thumbnails, and larger 100x100 images. This gave AFL++ structurally valid starting points while keeping dry-run and mutation cost low.

Two seeds were selected in particular because they are proof-of-concept inputs for the vulnerability classes we aimed to rediscover:

- `poc_load_gif.gif`: a 32x32 two-frame animated GIF. This exercises the multi-frame GIF loading path and is relevant to the `load_gif()` use-after-free class of bugs.
- `poc1_gif_oob.gif`: a minimal 1x1 GIF. This seed stresses boundary conditions in the image loader and conversion path, especially tiny dimensions and short image data.

Before fuzzing, each raw GIF is wrapped with the 8-byte harness control header described earlier, yielding inputs of the form `control header || GIF payload`.

To keep the baseline campaign fast, we excluded expensive seeds from the default corpus, they can optionally be included by using the appropriate flag when running the campaign.

== Mutation Strategy Analysis
The AFL++ strategy-yield table shows that dictionary-based mutations contributed 136 new paths. The dictionary row reports `136/458k, 0/459k, 0/0, 0/0`, meaning that the first dictionary mutation mode found 136 interesting inputs over about 458k executions. The havoc/splice row reports `973/1.88M, 0/0`, so havoc contributed 973 new paths over about 1.88M executions, while splicing did not contribute in this run, AFL++ did not spent executions in the splice stage.

The numbers are reported in @strategy-yield-summary 


= Campaign Analysis

The main greybox campaign *ran for an hour*.
The AFL++ status screen is shown in @status-screen, and the `afl-plot` graphs are shown in
@edges-plot, @exec-speed-plot, @high-freq-plot, and @low-freq-plot. 

At the end of the run, AFL++ reported a *corpus count of 1515 inputs*, with 122 favored
items and 242 inputs that discovered new edges.

The campaign completed two full
queue cycles (not shown in the status screen). 
It also found *51 unique crashes* and 58 saved hangs.

AFL++ reported *99.96% stability*, which means that repeated executions of the same inputs almost always produced the same coverage. 

The bitmap density was 10.34% for the whole corpus, with 5.44 bits per tuple. This indicates that the campaign
reached a meaningful part of the instrumented program, while still remaining far from bitmap saturation.

The edge curve rises quickly at the beginning of the run and then continues as smaller step increases. This is the expected shape for a useful fuzzing campaign: AFL++ first discovers shallow parsing paths from the initial GIF
seeds, then later reaches deeper behavior through mutation and queue cycling.

The status screen reports that a new path had been found 58 seconds before the screenshot, so the campaign was still productive when it was stopped.
For this reason, *we do not consider the campaign saturated*. The run is long enough to validate the harness and demonstrate that AFL++ reaches meaningful
decoder behavior, especially since it found 51 unique crashes. 
However, because new paths were still being found near the end of the hour long run, a longer campaign, would likely discover additional coverage and possibly more crashes.

= Crash Triage

// If crashes were found: Pick one crash and show the full triage -- reproduce it, minimize it with afl-tmin, obtain an ASan stack trace. Identify the bug type and, if applicable, the corresponding CVE. If no crashes were found: Prove your setup works by injecting a synthetic bug (e.g., an off-by-one write), re-fuzzing for 60 seconds, and showing AFL++ catches it. Then argue why no real bugs were found.


Crash selected: AFL++ `crash id:000047 from outputs/20260514-142308/default/crashes`.
#text(red)[fix path to put final path of the results]

One of the two crashes we found was a *heap-based buffer overflow*, specifically it is an *out-of-bounds write* in libsixel's GIF decoder. The input reaches
`load_gif()`, which calls`gif_init_frame()`. AddressSanitizer reports an out-of-bounds
write at fromgif.c:241:

    `frame->palette[pg->transparent * 3 + 0] = bgcolor[0];`

The root cause is that the GIF transparency index from the Graphic Control Extension is
used as an index into frame->palette without checking that it is smaller than the number
of palette entries. In the crashing input, the transparent index is 0xdf, while the GIF is
a tiny 1x1 image with a much smaller palette. This causes writes past the heap allocation
for frame->palette.

Under ASan the program aborts with SIGABRT, without ASan the
bug may corrupt adjacent heap memory.

This Bug does not have a assigned CVE but has been already reported and fixed in the release candidate: https://github.com/saitoha/libsixel/issues/220.

The triage included reproducing the bug with our harness, then with `img2sixel` and finally with a minimized version.

All commands necessary for the full triage, as well as the stacktrace are in the Appendix @appendix-triage 

= Attack Surface Analysis

#text(blue)[
Name two real-world applications that use your target library and describe a concrete attack scenario. Then identify at least two code paths in those applications that your harness does not exercise, and explain why these gaps matter for security.
]
= Binary-Only Fuzzing with QEMU Mode

To evaluate the library in a black-box scenario, we ran a campaign against an uninstrumented binary using AFL++ QEMU mode (`-Q`). We built vanilla versions of the harness and `libsixel` (v1.8.7) using standard `gcc` / `g++`, confirming via `nm` and through the library build configurations that no sanitizer symbols or instrumentation points were present.

The full performance comparison after 300 seconds is reported in @qemu-performance-table.

The discrepancies between these metrics come from the differences in how each mode collects coverage and executes the target:

1. *Execution Speed*: The instrumented campaign is $tilde$30x faster. This is primarily due to the *persistent mode* (`__AFL_LOOP`), which allows the fuzzer to reuse the same process for multiple test cases. In contrast, the QEMU campaign lacks persistent mode and has the significant overhead of Just-In-Time (JIT) binary translation for every instruction.

2. *Edges Discovered*: QEMU mode discovered $tilde$35% more edges despite having 30x fewer executions. This is because compile-time instrumentation only sees branches in the source code it compiled. QEMU mode instruments the entire process address space during emulation, capturing paths within shared system libraries (e.g., `libpng`, `libjpeg`, `libc`) that are black-boxes to the instrumented version.

3. *Corpus Count*: The native fuzzer's higher throughput allowed it to explore a larger mutation space, leading to a larger corpus within the same timeframe.

Despite the performance penalty, the QEMU campaign, when combined with `QASan` (QEMU-AddressSanitizer), successfully identified memory safety issues. By disabling the `TRUEVISION` patch (which previously filtered out small inputs), we reproduced a heap-buffer underflow in the file format detection logic. While a vanilla binary might "silently" corrupt memory without crashing, `QASan` intercepts memory-related library calls (like `memcmp`) and validates their arguments against a shadow memory map, promoting these "soft" corruptions to detectable crashes.

= Instrumentation Depth and Performance
#text(blue)[
Report the number of instrumented edges reported by afl-fuzz at startup for (a) the library alone and (b) the final harness binary. Explain why these numbers differ. Then compare your campaign's map density to the total instrumented edges and explain why not all edges were reached. Additionally, measure exec speed under three configurations using the same harness: (1) no sanitizer + fork mode, (2) ASan + fork mode, (3) ASan + persistent mode. Report the three numbers and explain the source of each speedup or slowdown.
]

#colbreak()

= Appendix 

== Fuzzing Speed Measurements

#figure(
  lab-table(
    columns: (1.25fr, 1fr, 0.8fr, 1fr, 1.25fr),
    [*Profile*], [*Loader*], [*Time*], [*Execs*], [*Speed*],
    [`fast`], [`0`], [74s], [241,802], [*3235.72 exec/s*],
    [`extended`], [`0`], [73s], [195,386], [*2656.29 exec/s*],
    [`fast`], [`1`], [74s], [124,718], [*1670.21 exec/s*],
    [`extended`], [`1`], [73s], [51,441], [*698.60 exec/s*],
  ),
  caption: [AFL++ speed comparison across seed profile and loader configurations.],
)

#v(1em)

#figure(
  lab-table(
    columns: (1.25fr, 1fr, 1fr),
    [*Metric*], [*`-t 1000`*], [*`-t 5000`*],
    [Run time], [74s], [74s],
    [Execs done], [227,021], [215,103],
    [Speed], [*3038.45 exec/s*], [*2878.36 exec/s*],
    [Corpus count], [717], [762],
    [Bitmap coverage], [9.34%], [9.61%],
    [Edges found], [1853], [1905],
    [Crashes], [26], [29],
    [Hangs], [8], [0],
  ),
  caption: [Timeout A/B test using `SEED_PROFILE=fast BROAD_LOADER=0`.],
)

#v(1em)


== Fuzzing Strategy Yields

#figure(
  lab-table(
    columns: (1.1fr, 1.75fr, 1.15fr),
    [*Strategy*], [*Yield*], [*Impact*],
    [Bit flips], [29/40.3k, 20/40.3k, 16/40.2k], [Small],
    [Byte flips], [2/5035, 2/5025, 4/5005], [Small],
    [Arithmetics], [86/351k, 31/696k, 27/693k], [Moderate],
    [Known ints], [3/45.1k, 5/189k, 16/279k], [Small],
    [*Dictionary*], [*136/458k*, 0/459k, 0/0, 0/0], [*Useful*],
    [*Havoc/splice*], [*973/1.88M*, 0/0], [*Dominant*],
    [Py/custom/rq], [unused, unused, unused, unused], [Not used],
    [Trim/eff], [8.57%/481k, 98.83%], [Corpus cleanup],
  ),
  caption: [AFL++ strategy-yield summary. Havoc produced the most interesting inputs, while dictionary mutations also contributed meaningful new paths.],
) <strategy-yield-summary>

#v(1em)

== Campaign analysis

#figure(
  image(
    "./img/AFL_status_screen.png",
    width: 100%,
  ), caption: [AFL++ status screen during the greybox campaign.]
) <status-screen>

#v(1em)

#figure(
  image(
    "./img/edges.png",
    width: 100%,
  ), caption: [AFL++ edge coverage over time.]
) <edges-plot>

#v(1em)

#figure(
  image(
    "./img/exec_speed.png",
    width: 100%,
  ), caption: [AFL++ execution speed over time.]
) <exec-speed-plot>

#v(1em)

#figure(
  image(
    "./img/high_freq.png",
    width: 100%,
  ), caption: [High-frequency AFL++ plot metrics.]
) <high-freq-plot>

#v(1em)

#figure(
  image(
    "./img/low_freq.png",
    width: 100%,
  ), caption: [Low-frequency AFL++ plot metrics.]
) <low-freq-plot>


== Crash triage <appendix-triage>

#figure(
simple-code[```
ERROR: AddressSanitizer: heap-buffer-overflow
WRITE of size 1
  #0 0x... in gif_init_frame /src/libsixel/src/fromgif.c:241:61
  #1 0x... in load_gif /src/libsixel/src/fromgif.c:675:22
  #2 0x... in load_with_builtin /src/libsixel/src/loader.c:948:18
  #3 0x... in sixel_helper_load_image_file /src/libsixel/src/loader.c:1462:18
  #4 0x... in sixel_encoder_encode /src/libsixel/src/encoder.c:1816:14
  #5 0x... in main /src/harness.c:215:9

SUMMARY: AddressSanitizer: heap-buffer-overflow /src/libsixel/src/fromgif.c:241:61 in gif_init_frame 
```], caption: "Backtrace of crash 47.")

 #v(1em)
=== afl-tmin

#figure(
  simple-code[
    ``` mkdir -p triage

docker run --rm \
  -v "$PWD:/host" \
  -e ASAN_OPTIONS=detect_leaks=0:abort_on_error=1:symbolize=1 \
  libsixel-fuzzer \
  afl-tmin -m none -t 1000 \
  -i '/host/outputs/20260514-142308/default/crashes/id:000047...' \
  -o /host/triage/id000047.min \
  -- /usr/local/bin/sixel-harness
  ```
  ], caption:"Command to minimise the seed."
)

#v(1.0em)

#figure(
  simple-code()[`
Read 51 bytes from input.
Program exits with a signal, minimizing in crash mode.
File size reduced by: 23.53% (to 39 bytes)
Characters simplified: 69.23%
Number of execs done: 249
Output written to: triage/id000047.min`
  ],
  caption: "Afl-tmin result."
)

#v(1.0em)

#figure(
  simple-code[
    ```
    docker run --rm \
  -v "$PWD:/host" \
  -e ASAN_OPTIONS=detect_leaks=0:abort_on_error=1:symbolize=1 \
  libsixel-fuzzer \
  /bin/bash -lc '/usr/local/bin/sixel-harness < /host/triage/id000047.min'
  ```
  ], caption:"Reproducing the crash with minimised seed."
)

#v(1.0em)

#figure(
  simple-code[
    ```
docker run --rm \
  -v "$PWD:/host" \
  -e ASAN_OPTIONS=detect_leaks=0:abort_on_error=1:symbolize=1 \
  libsixel-fuzzer \
  /bin/bash -lc 'img2sixel -o /dev/null -g -p 256 -q auto -d auto -t rgb -f auto -s auto -E auto -B "#FF0000" -l auto /host/triage/id000047.min.gif'
  ```], caption : "Running img2sixel with minimised input"
  )

== QEMU Performance Comparison

#figure(
  lab-table(
    columns: (1.15fr, 1fr, 1fr),
    [*Axis*], [*Instrumented*], [*QEMU mode*],
    [Exec speed], [2,670.5 exec/s], [90.1 exec/s],
    [Edges discovered], [2,001], [2,696],
    [Corpus count], [1,151], [565],
  ),
  caption: [Performance comparison after 300 seconds of wall-clock time.],
) <qemu-performance-table>

#v(1em)
