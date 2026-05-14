// A compact Typst template modeled after the USENIX proceedings style.
// It uses US letter paper, a 7in text block, two 3.33in columns, Times-like
// typography, and an unnumbered proceedings-style title block.

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
        #align(center, text(size: 12pt, weight: "bold")[Abstract])
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
    This report details the design, executions and analysis of a coverage guided fuzzing campaign on the open-source library `libsixel` using the AFL++ fuzzer.

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

== Selected Entrypoint

For this campaign, we selected the *encoding path* of the library, specifically targeting the `sixel_encoder_encode` function. 

Even tough the guidelines mentioned the decoding path, we deemed that the encoder represented a larger and more critical attack surface, as applications usually rely on libsixel to process binary image formats (e.g PNG, JPEG, GIF) to output SIXEL.

Additionally, recently identified vulnerabilities were due to bugs in the encoding path.
This made the encoder a highly attractive target.
== Considered Alternatives

We initially considered fuzzing the high-level `img2sixel` function. However, we rejected this approach because high-level wrappers introduce unnecessary overhead (e.g. command-line argument parsing, I/O operations, ...). By writing a custom harness directly around `sixel_encoder_encode`, we skip all non-encoding related functionality.

We also considered using a PNG corpus, but due to strict checks by the parsing library (`libpng`), our fuzzer was not able to reach the encoding logic. Inspired by the recent CVE, we switched to a corpus of GIF files, which are not subject to such strict checks and are still able to trigger the encoding logic.



== Data Flow and Guards
Each AFL ++ test case is split into two parts: a 8-byte control header and the raw image payload.

The first 8-bytes are parsed by the harness and mapped to configuration options. They are passed to the library via `sixel_encoder_setopt` to configureencoder options such as color mode, quality, diffusion, resize/crop behavior, and animation-related flags.

The remaining bytes represents the image and are written to a temporary file. The latter is passed to `sixel_encoder_encode`, which expects a file path as input. Note that the harness receives each AFL++ test case through `stdin`, rather than through the usual `@@` filename argument, avoiding I/0 overhead.

The main data flow is therefore: \  `AFL++ testcase -> stdin -> [8-byte option header] + [GIF payload] -> temporary GIF file -> sixel_encoder_encode`.\
This lets AFL++ mutate both the image contents and the encoder configuration. The option bytes are mapped to fixed valid strings, to ensure the fuzzer explores many combinations of `libsixel` behavior.


The harness contains several guards to allow the fuzzer to efficiently explore the library:  
1. A guard ensures that the test case is at least 8 bytes long to contain the control header. This is needed because the harness expects the first 8 bytes to be valid options, and shorter inputs would be rejected before reaching the library code.
2. A guard ensures that the test case also contains a complete 6-byte GIF header after the control bytes. This is needed because the harness reconstructs an image file before calling the library API. Inputs shorter than this would only exercise trivial file rejection and would not reach the interesting decoder or encoder code. _Note that this guard can be removed to allow broader exploration of the file parsing logic with_ `make FUZZ BROAD_LOADER=1`.
3. We then have various other guards to ensure the harness passes valid options / files to the library, such as `if (fd < 0) continue;` to ensure the file has been successfully written or  `if (status != SIXEL_OK) continue;` which ensures the option values are valid and accepted by the library.


We also guard all harness option selection by mapping arbitrary AFL++ bytes into finite option sets using masks or modulo operations. This keeps crashes attributable to the library code and not to the harness (e.g. by preventing invalid option values from being passed to the library).

Finally the resize and crop options are chosen from small fixed dictionaries. This bounds generated image dimensions and crop regions, preventing AFL++ from spending time on huge allocations, very slow transformations, or timeout-heavy inputs while still exercising scaling, cropping, and resampling code.


= Instrumentation and Sanitizers

#text(blue)[
List every compiler flag and patch you applied to the target library. For each one, explain what it does and what would happen if you omitted it. If you patched the library (e.g., removing checksums), explain the effect on path discovery.
]
== Target Version 
We built *`libsixel v1.8.7`*, the latest stable release of the library At the time of writting two releases candidates were published (rc1, rc2), they address security vulnerabilities in the encoding path: These CVEs acts as a benchmark for our campaign as we should be able to find them with our setup, and they provide a good case study, as well as motivate our choice of fuzzing the encoder instead of the decoder.

== Coverage Instrumentation

We instrumented the library with AFL++'s `afl-clang-lto` / `afl-clang-lto++`, which inserts compile-time edge coverage. This gives AFL++ precise feedback for input selection. 
`CC=afl-clang-lto CXX=afl-clang-lto++` 

== *AddressSanitizer*

We also built the library with AddressSanitizer (ASan) to detect memory safety bugs. This allows us to catch memory corruption issues that might not immediately cause a crash, improving our chances of finding security vulnerabilities.
If omitted, AFL++ would still find hard crashes, but many invalid reads/writes would remain silent or become harder-to-reproduce later crashes.
`ENV AFL_USE_ASAN=1`

Because ASan reserves a large virtual address space, we run AFL++ with `-m none`; otherwise AFL++'s default memory limit can kill valid ASan-instrumented executions.

At runtime, we used \
```
ASAN_OPTIONS=detect_leaks=0
abort_on_error=1
symbolize=0
```
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



= Seed Corpus and Dictionary <sec:figs>
#text(blue)[
Describe your seeds and dictionary. Using the dictionary and havoc/splice rows from your AFL++ status screen, quantify how many new paths each strategy contributed. Explain what the dictionary entries represent in formal terms (hint: think grammar/language theory).
]
= Campaign Analysis

#text(blue)[
Include your afl-plot edges graph and AFL++ status screen screenshot. Report stability, corpus count, map density, and cycles done. Describe the shape of the edges curve and argue whether the campaign reached saturation.

]
= Crash Triage

#text(blue)[
If crashes were found: Pick one crash and show the full triage -- reproduce it, minimize it with afl-tmin, obtain an ASan stack trace. Identify the bug type and, if applicable, the corresponding CVE. If no crashes were found: Prove your setup works by injecting a synthetic bug (e.g., an off-by-one write), re-fuzzing for 60 seconds, and showing AFL++ catches it. Then argue why no real bugs were found.

]
= Attack Surface Analysis

#text(blue)[
Name two real-world applications that use your target library and describe a concrete attack scenario. Then identify at least two code paths in those applications that your harness does not exercise, and explain why these gaps matter for security.
]
= Binary-Only Fuzzing with QEMU Mode

To evaluate the library in a black-box scenario, we ran a campaign against an uninstrumented binary using AFL++ QEMU mode (`-Q`). We built vanilla versions of the harness and `libsixel` (v1.8.7) using standard `gcc` / `g++`, confirming via `nm` and through the library build configurations that no sanitizer symbols or instrumentation points were present.

#figure(
  table(
    columns: (1fr, 1fr, 1fr),
    inset: 10pt,
    align: horizon,
    [*Axis*], [*Instrumented*], [*QEMU Mode*],
    [Exec Speed], [2,670.5 execs/s], [90.1 execs/s],
    [Edges Discovered], [2,001], [2,696],
    [Corpus Count], [1,151], [565],
  ),
  caption: [Performance comparison after 300s of wall-clock time.],
)

The discrepancies between these metrics come from the differences in how each mode collects coverage and executes the target:

1. *Execution Speed*: The instrumented campaign is $tilde$30x faster. This is primarily due to the *persistent mode* (`__AFL_LOOP`), which allows the fuzzer to reuse the same process for multiple test cases. In contrast, the QEMU campaign lacks persistent mode and has the significant overhead of Just-In-Time (JIT) binary translation for every instruction.

2. *Edges Discovered*: QEMU mode discovered $tilde$35% more edges despite having 30x fewer executions. This is because compile-time instrumentation only sees branches in the source code it compiled. QEMU mode instruments the entire process address space during emulation, capturing paths within shared system libraries (e.g., `libpng`, `libjpeg`, `libc`) that are black-boxes to the instrumented version.

3. *Corpus Count*: The native fuzzer's higher throughput allowed it to explore a larger mutation space, leading to a larger corpus within the same timeframe.

Despite the performance penalty, the QEMU campaignl, when combined with `QASan` (QEMU-AddressSanitizer), successfully identified memory safety issues. By disabling the `TRUEVISION` patch (which previously filtered out small inputs), we reproduced a heap-buffer underflow in the file format detection logic. While a vanilla binary might "silently" corrupt memory without crashing, `QASan` intercepts memory-related library calls (like `memcmp`) and validates their arguments against a shadow memory map, promoting these "soft" corruptions to detectable crashes.

= Instrumentation Depth and Performance
#text(blue)[
Report the number of instrumented edges reported by afl-fuzz at startup for (a) the library alone and (b) the final harness binary. Explain why these numbers differ. Then compare your campaign's map density to the total instrumented edges and explain why not all edges were reached. Additionally, measure exec speed under three configurations using the same harness: (1) no sanitizer + fork mode, (2) ASan + fork mode, (3) ASan + persistent mode. Report the three numbers and explain the source of each speedup or slowdown.
]
