Generated extended wrapped GIF seeds for the AFL++ harness.

This corpus contains the fast `corpus/gif/*.gif` seeds plus selected slower
seeds from `corpus/excluded/*.gif`. Each file is prefixed with eight control
bytes consumed by `sixel-harness`.

The eight-byte control header is documented in the root `README.md` under
`Seed Corpus` -> `Wrapped Seeds`.

Use this corpus with:

```bash
make fuzz SEED_PROFILE=extended
```
