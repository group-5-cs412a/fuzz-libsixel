Vendored GIF fuzzing seeds for `libsixel`.

These files are intentionally small and cover a mix of valid GIF features that
are useful for fuzzing: tiny images, transparency, animation, and interlacing.

Sources:
- `transparent-1x1.gif`, `pjw-thumbnail.gif`, `animated-red-blue.gif`,
  `hippopotamus.regular.gif`, `hippopotamus.interlaced.gif` from
  `google/wuffs` `test/data/`
- `treescap.gif`, `treescap-interlaced.gif`, `gifgrid.gif`, `x-trans.gif`
  from `mirrorer/giflib` `pic/`
