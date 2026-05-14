Generated wrapped GIF seeds for the AFL++ harness.

Each file in this directory is derived from the matching `corpus/gif/*.gif`
input, prefixed with eight control bytes consumed by `sixel-harness`.
Timeout-prone seeds from `corpus/gif` are omitted here and kept in the extended
wrapped corpus.

The eight-byte control header is documented in the root `README.md` under
`Seed Corpus` -> `Wrapped Seeds`.

Rebuild this directory with:

```bash
./scripts/generate_wrapped_seeds.sh
```
