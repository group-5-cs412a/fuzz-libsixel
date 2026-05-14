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
        #set par(first-line-indent: 0pt)
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

For this campaign, we selected the encoding path of the library, specifically targetting the `sixel_encoder_encode` function rather than the decoding path suggested by the lab guidelines. Indeed, we judged that the encoder represents a larger and more critical attack surface, as applications usually rely on libsixel to process binary image formats (e.g PNG, JPEG, GIF) to output SIXEL. This makes the encoder a highly attractiv target. Additionally, recently identified vulnerabilities were due to bugs in the encoding path.

== Considered Alternatives

#text(blue)[
We initially considered fuzzing the high-level `img2sixel` function. However, we rejected this approach because high-level wrappers introduce unnecessary overhead (e.g. command-line argument parsing, I/O operations, ...). By writing a custom harness directly around `sixel_encoder_encode`, we skip all non-encoding related functionality.
]
*TODO: WHY WOULD IT BE (NOT) WORTH FUZZING THE DECODE PATH*

== Data Flow and Guards
#text(blue)[
*TODO: Then walk through your harness code and explain the data flow from the AFL++ input file to the library API call. For every guard in the code (error handling, dimension limits, etc.), explain why it is needed from a fuzzing perspective.*
]
= Instrumentation and Sanitizers
#text(blue)[
List every compiler flag and patch you applied to the target library. For each one, explain what it does and what would happen if you omitted it. If you patched the library (e.g., removing checksums), explain the effect on path discovery.
]
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
