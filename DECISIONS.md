# Decisions

Ambiguities resolved and deviations from GAME_SPEC / ART_SPEC (GAME_SPEC §0.6). One row per
decision: the why, and what it rules out. Numbers live in `data/`, not here.

| ID | Date | Decision | Why |
| --- | --- | --- | --- |
| D-A01 | 2026-10-20 | Engine pinned to **Godot 4.6.3 stable** (spec says 4.3+), GDScript only | Installed version; C# cannot target Web |
| D-A02 | 2026-10-20 | ~~Display settings `viewport` / `expand` / `integer`~~ — superseded by D-A08 | — |
| D-A03 | 2026-10-20 | Renderer **GL Compatibility** (desktop + mobile) | Web export requires it; one renderer for every target |
| D-A04 | 2026-10-20 | Tests use an in-house headless runner (`tests/_run.gd`, `tools\test.cmd`) instead of GUT / gdUnit4 | No addon to install/version; supports `--changed`; reused from a sibling project |
| D-A05 | 2026-10-20 | Main scene is a preload-free boot scene that loads + validates data after the first frame | Mobile cold-start compile blocks the first frame (team-kb f835d663); boot shows data errors on screen |
| D-A06 | 2026-10-20 | `user://` uses custom dir `NecroDices` | Keeps saves out of the shared Godot app-data folder |
| D-A07 | 2026-10-20 | Specs stay at repo root (`GAME_SPEC.md`, `ART_SPEC.md`, `DECISIONS.md`); plans / tech notes in `docs/` | Specs cross-reference each other by root file name |
| D-D01 | 2026-10-20 | `strings_en.json` is a flat key → string map without `version` | A version key would be a fake string entry |
| D-D02 | 2026-10-20 | Relic `text` written as short sentences; only OVERGROWTH (`{counter}`) and BLACK_GRIMOIRE (`{value}`) have live placeholders | Spec gives effects, not UI text |
| D-D03 | 2026-10-20 | `units.json` carries `tier_rank` (T3 3 … WISP 0) and `mini`; consumables always have `element` and `modifier` (null when n/a) | §5.2 WILD tie-break and ART §4.4 mini mapping read them; uniform rows |
| D-D04 | 2026-10-20 | Boss HP multiplier comes from `boss_rules[].hp_mult`; `curve.role_mult.BOSS` is the default (2.0) | Inquisitor ×1.5 (§6.9) |
| D-D05 | 2026-10-20 | Face modifiers in `economy.json.modifiers` reuse relic op names (`add_power`, `mul_count`, `add_money` at COMMIT) | One interpreter for faces and relics |
| D-R01 | 2026-10-20 | Placeholder rules: 1 px transparent border only on 16×16 icons (8×8 stat icons use full canvas); legion banner follows unit rules, shopkeeper enemy rules; `spark` / `die_bound` may be pure white (`tint` flag) | Spec leaves these sizes unassigned; white is tinted at runtime (ART §4.6, §10) |
| D-R02 | 2026-10-20 | Floating units: FROST_BAT, VOLT_GHOST, FLAME_SKULL, WISP, STORM_BANSHEE (shadow row at y=15) | Concepts in ART §4.2 describe them as flying / floating |
| D-R03 | 2026-10-20 | Frame 2: grounded sprites squash with feet fixed; floating sprites bob 1 px; enemy hurt = 2 px recoil, eyes shut | Feet-row rule (ART §9.3) holds on every frame |
| D-R04 | 2026-10-20 | Consumable TOME_/SIGIL_ icons are composed from the base + `glyph8_<e>` read from disk | Approved bases and glyphs carry through without regenerating (ART §5.2) |
| D-R05 | 2026-10-20 | UI font = **Fusion Pixel** (8 px body, 12 px numbers), copied from Necwarband with its OFL licence; ART_SPEC §8 updated | Licence already verified (OFL 1.1), proven in a sibling project, replaces the unverified m5x7 / m6x11 candidates |
| D-A08 | 2026-10-20 | Stretch `viewport` + aspect **`keep`** + scale `integer`; the `Display` autoload sets `content_scale_size = (clamp(w / s, 480, 640), clamp(h / s, 270, 300))` with `s = max(1, min(w / 480, h / 270))` on every resize (`core/display_fit.gd`). ART_SPEC §2 updated | `expand` + `integer` is godotengine/godot#92055 (still open: jumps, one-direction expansion, stray bars). `keep` + `integer` is the stable built-in combo; choosing the canvas size ourselves keeps the expansion without a SubViewport (input, scene changes and Controls work unchanged). Verified with `scenes/dev/display_probe.tscn`: 960×540 → ×2 480×270; 1600×900 → ×3 533×300; 1280×800 → ×2 640×300 |
| D-A09 | 2026-10-20 | **Landscape 480×270** replaces portrait 270×480 (user decision). Same pixel density: sprites, dice, icons, 9-slices and touch targets keep their sizes; backgrounds become 640×300 centred; every ART_SPEC §6 layout redrawn as three columns (info / stage / controls) — layouts approved by the user 2026-10-20 | The spec's portrait orientation was a mistake. 480×270 is ×4 of 1080p and ×8 of 4K, and keeps every asset size of the art spec |
| D-A10 | 2026-10-20 | Primary target = **Web desktop on itch.io**; mobile landscape secondary. Export single-threaded (Thread Support off), Compatibility renderer, `index.html` at zip root, ≤ 1,000 files; embed 960×540 + fullscreen button + Click to play | itch.io serves without COOP/COEP headers; its SharedArrayBuffer option is experimental. Single-threaded export (Godot 4.3+) is the recommended path for itch.io; Click to play gives the user gesture browsers need for audio |
