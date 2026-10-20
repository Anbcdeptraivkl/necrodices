# Fusion Pixel Font — Latin subset

- Source: https://github.com/TakWolf/fusion-pixel-font, release 2026.09.25,
  `fusion-pixel-font-{12px,8px}-proportional-otf.woff2` (files `*-latin.otf.woff2`).
- Licence: SIL Open Font License 1.1 (`OFL.txt`), no Reserved Font Name; free to use,
  modify and ship with the game. Copyright (c) 2022, TakWolf.
- Modified: subset to Latin with fontTools (Basic Latin, Latin-1, Latin Extended-A, general
  punctuation, euro, trademark, arrows, minus) and saved as OTF:

      python -m fontTools.subset <in>.otf.woff2 --unicodes="U+0020-007E,U+00A0-017F,U+2010-2027,U+2030-203A,U+20AC,U+2122,U+2190-2195,U+2212" --flavor= --layout-features='*' --output-file=fusion_pixel_12px.otf

- Design sizes: 12 px (units per em 1200) and 8 px (800). Use them only at these sizes or
  whole multiples (docs/design/art_direction.md §7, D33).
