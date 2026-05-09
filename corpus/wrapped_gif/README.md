Generated wrapped GIF seeds for the AFL++ harness.

Each file in this directory is derived from the matching `corpus/gif/*.gif`
input, prefixed with a single control byte consumed by `sixel-harness`.

Rebuild this directory and the Docker build input with:

```bash
./generate_wrapped_seeds.sh
```
