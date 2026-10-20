# RATTLE & ROLL — Art Spec v1.0

> Companion to `GAME_SPEC.md`. IDs used here (units, relics, enemies…) are defined there and must not be renamed.
> Audience: artists, AI-image pipelines, and LLM coding agents integrating assets.
> Rule priority: **readability at 270×480 > consistency > detail**.

---

## 1. Style pillars

| Pillar | Meaning |
|---|---|
| Spooky-cute | Halloween monsters as lovable underdogs; enemies are human monster-hunters. No gore, no blood splatter (HP red is UI only). |
| Pure pixel | No anti-aliasing, no sub-pixel, no non-integer scaling at rest, no blur, binary alpha. |
| Elements read first | Every die face and unit is identifiable by **shape and colour** (colour-blind safe: glyph shapes differ). |
| Dark stage, bright actors | Backgrounds live in the darkest 4 neutrals; units/enemies/UI use the bright ramps so a 240-sprite horde stays readable. |
| One light source | Top-left, everywhere (sprites, icons, UI bevels). |

---

## 2. Resolution & project settings

| Item | Value |
|---|---|
| Virtual resolution | **270 × 480** portrait |
| Scaling | Integer only (×2 = 540×960, ×3 = 810×1440, ×4 = 1080×1920). Leftover space letterboxed in `N0`. |
| Aspect | Expand vertically on tall phones: extra height goes to the Battlefield (§6.2), up to 640 virtual px tall; any remainder is letterboxed. Top and bottom bars are anchored. Width is always 270 (sides letterboxed on wide screens). |
| Pixel grid | 1 virtual px = 1 art px. Sprites rendered at ×1 everywhere, except the **showcase exception**: icons may be shown at exactly ×2 in shop cards, tooltip headers and reward popups. Nothing else is upscaled. |
| Transient transforms | Scale punches / rotations allowed only during tweens ≤ 200 ms; resting state is always ×1, axis-aligned, pixel-snapped. |

Godot 4.6.3 project settings (agent must apply in M0):

```
display/window/size/viewport_width = 270
display/window/size/viewport_height = 480
display/window/size/window_width_override = 540
display/window/size/window_height_override = 960
display/window/stretch/mode = "viewport"
display/window/stretch/aspect = "keep"          # NOT "expand": expand + integer is buggy (godot#92055)
display/window/stretch/scale_mode = "integer"
display/window/handheld/orientation = "portrait"
rendering/textures/canvas_textures/default_texture_filter = Nearest
rendering/2d/snap/snap_2d_transforms_to_pixel = true
rendering/2d/snap/snap_2d_vertices_to_pixel = true
```
Tall screens: the `Display` autoload sets `Window.content_scale_size` to `(270, clamp(window_h / scale, 480, 640))` with
`scale = max(1, min(window_w / 270, window_h / 480))` on start and on every resize (`core/display_fit.gd`, DECISIONS D-A08).
The built-in `keep` + `integer` stretch then renders that canvas at exactly `scale`.

Texture import preset (all PNGs): Filter Nearest, Mipmaps off, Compress Lossless, Repeat off.
Font import (`[importer_defaults] font_data_dynamic`): antialiasing off, hinting none, subpixel positioning off, system fallback off.
Web export: canvas resize policy Adaptive; background colour `#0d0a14`.

---

## 3. Palette — "Hallow32"

All opaque pixels in final art must come from this list (exceptions: §4.3 mask files, VFX tint at runtime). Export as `assets/palette/hallow32.gpl` and `hallow32.png` (32×1 px strip).

| Key | Hex | Role |
|---|---|---|
| N0 | `#0d0a14` | Void — outlines, deepest shadow, letterbox |
| N1 | `#1a1326` | Night — background base, panel fill |
| N2 | `#281d3b` | Dusk shadow — card fill, disabled button |
| N3 | `#3b2c55` | Dusk — inner borders, chips |
| N4 | `#574577` | Twilight — secondary button fill |
| N5 | `#8577a3` | Mist — secondary text, borders |
| N6 | `#c4bad8` | Fog — body text on dark |
| N7 | `#f4efe4` | Moonlight — highlights, primary text |
| B0 | `#7b6a52` | Bone dark |
| B1 | `#bba783` | Bone mid |
| B2 | `#e9ddbf` | Bone light |
| F0 | `#b33a10` | Fire dark |
| F1 | `#f2781c` | Fire mid — primary CTA |
| F2 | `#ffc85a` | Fire light |
| I0 | `#23589c` | Ice dark |
| I1 | `#4fb6ea` | Ice mid — **Power** colour |
| I2 | `#c6f1ff` | Ice light |
| L0 | `#1f6136` | Leaf dark |
| L1 | `#49b23f` | Leaf mid |
| L2 | `#b4ec6a` | Leaf light |
| V0 | `#7d7a12` | Volt dark |
| V1 | `#e3df34` | Volt mid |
| V2 | `#fbfaa6` | Volt light |
| M0 | `#4f5b66` | Metal dark |
| M1 | `#93a3ae` | Metal mid |
| M2 | `#dfe8ec` | Metal light |
| R0 | `#8c1c34` | Red dark |
| R1 | `#e0344a` | Red — **Count** colour, HP, danger |
| G0 | `#c98a17` | Gold dark |
| G1 | `#ffe066` | Gold — money, selection |
| S0 | `#a8643c` | Skin dark (enemies) |
| S1 | `#f0b896` | Skin light (enemies) |

Semantic mapping:

| Use | Colours |
|---|---|
| Element ramps | BONE `B0-B2`, FIRE `F0-F2`, ICE `I0-I2`, LEAF `L0-L2`, VOLT `V0-V2`, METAL `M0-M2` |
| Power box / numbers | `I1` fill, `I0` shadow, `N7` text |
| Count box / numbers | `R1` fill, `R0` shadow, `N7` text |
| Money | `G1` / `G0` |
| Rarity stripe | Common `I1`, Uncommon `L1`, Rare `R1` |
| Group bind colours (cycle) | 1 `G1`, 2 `I2`, 3 `L2`, 4 `F2` |
| HP bar | fill `R1` (bottom row `R0`), projected-damage preview segment `G1` |

---

## 4. Sprites

### 4.1 General rules (all characters)
- PNG RGBA, binary alpha (0 or 255).
- 1 px outline in `N0` around the silhouette (exterior only; interior lines use ramp darks).
- Light from top-left: highlights on top/left edges, darks bottom/right.
- Front-facing 3/4 view toward the camera. Units lunge **upward** at enemies; enemies face **down** toward the army.
- Silhouette test: filling the sprite solid `N0` must still identify it among its category.
- At least 40% of a unit's opaque pixels must be from mid/light ramps (pops against the dark battlefield).
- Sprite sheets: frames laid out horizontally, no padding, frame size exact.

### 4.2 Units — 16×16
- Sheet: `32×16` = 2 idle frames. Idle at 3 fps (frame 2 = 1 px squash or flicker/blink).
- Pivot: bottom-centre `(8, 16)`; lowest opaque pixel on row `y = 15` (floating units: shadow pixel row at y=15 in `N0`, 4–6 px wide).
- Max 7 colours including outline. Single-element units: own ramp + `N0` + ≤ 2 accent colours (eyes/glow) covering ≤ 10% of pixels. Hybrids: primary element ramp ~60% of pixels, secondary ~30%.
- T3 units: may use the full 16×16 and must have a tier mark (crown, halo or aura pixels in `G1`).

| ID | Concept | Ramps |
|---|---|---|
| SKELETON_WARRIOR | Small skeleton raising a chipped short sword; ribcage visible | Bone (+M2 blade accent) |
| FIRE_IMP | Tiny horned imp with flame tail, mischievous grin | Fire |
| FROST_BAT | Round bat with icicle-shard wings | Ice |
| PUMPKINLING | Small unlit pumpkin sprout walking on vine legs, cute face | Leaf (+F1 body accent ≤ 30%) |
| VOLT_GHOST | Sheet ghost with zigzag tail and spark pixels | Volt (+N7) |
| HAUNTED_ARMOR | Empty knight helm + breastplate, glowing eyes in visor slit | Metal (+V2 eye glow) |
| FLAME_SKULL | Floating skull wreathed in flames | Bone 60 / Fire 30 |
| SCARECROW | Straw scarecrow, skull face, stitched hat | Bone 60 / Leaf 30 |
| SHIELD_SKELETON | Skeleton peeking over an iron tower shield | Bone 60 / Metal 30 |
| STEAM_SLIME | Slime, left half orange / right half icy blue, steam puff on top | Fire 50 / Ice 50 |
| JACK_O_LANTERN | Big **lit** carved pumpkin head (fire inside), vine body, menacing grin — must not read as Pumpkinling | Fire 60 / Leaf 30 |
| BOG_WITCH | Hunched witch with mossy hat and frosted staff | Ice 60 / Leaf 30 |
| STORM_BANSHEE | Wailing spirit, ice-blue body, hair streaming as lightning | Ice 60 / Volt 30 |
| TESLA_SPIDER | Clockwork spider with glowing coil on its back | Metal 60 / Volt 30 |
| WISP | Floating flame orb with a smaller orbiting spark — **mask file**, see §4.3 | Mask |
| LICH | Robed skeleton mage, crown, staff with skull | Bone + `N4` robe + `G1` crown |
| HEADLESS_HORSEMAN | Headless rider on a tiny skeletal horse, holding a flaming pumpkin | Bone / Fire / Leaf |
| STITCHED_GOLEM | Hulking patchwork golem with metal plates and lightning in its stitches. **No flat-top head, no neck bolts** (IP, §12) | Metal / Volt / Bone |
| WITCH_QUEEN | Tall witch queen, crown of thorny vines, frost gown, lightning orb in hand | Ice / Leaf / Volt |

### 4.3 Mask sprites (runtime palette swap)
`units/wisp_mask.png` (32×16, 2 frames) uses key colours only:

| Key | Hex | Replaced by |
|---|---|---|
| A0 / A1 / A2 | `#ff0000` / `#ff6060` / `#ffc0c0` | Primary element ramp (first element of the recipe key) dark/mid/light |
| C0 / C1 / C2 | `#0000ff` / `#6060ff` / `#c0c0ff` | Secondary element ramp |
| Outline | `#0d0a14` | unchanged |

A palette-swap shader (`fx/palette_swap.gdshader`) receives 6 target colours. Same shader + mini mask is used for the Wisp crowd mini (§4.4).

### 4.4 Crowd minis — 8×8
Used when the army exceeds 60 visible sprites (GAME_SPEC §11.2).
- Sheet `16×8`, 2 frames, pivot `(4, 8)`, max 4 colours.
- One per element + Wisp mask: `mini_bone` (tiny skull), `mini_fire` (flame imp), `mini_ice` (snow bat), `mini_leaf` (pumpkin), `mini_volt` (spark ghost), `mini_metal` (helmet), `mini_wisp_mask`.
- A unit uses the mini of the **first element of its recipe key** (e.g. SHIELD_SKELETON → `mini_bone`, TESLA_SPIDER → `mini_volt`).
- LEGION banner (> 240): `units/legion_banner.png` 16×16, a tattered flag on a bone pole, `N3`/`N5` cloth; the unit icon is drawn on it at runtime.

### 4.5 Enemies — 32×32
- Sheet `96×32` = `idle0, idle1, hurt`. Idle at 2 fps (1 px breathing). Hurt = recoil pose, eyes shut.
- Pivot bottom-centre `(16, 32)`, lowest opaque row `y = 31`.
- Max 12 colours. Humans use `S0/S1` skin + neutrals + **one signature accent**.
- Bosses fill ≥ 28×28 of the canvas, have a unique accessory and a 2-tone signature accent.
- Use **invented** holy/order symbols (sun disc, open eye, bell) — no real religious iconography (store-safety).

| ID | Concept | Accent |
|---|---|---|
| MOB_TORCH_VILLAGER | Peasant in patched tunic holding a torch high | Fire |
| MOB_PITCHFORK_FARMER | Straw hat, overalls, pitchfork | Metal |
| MOB_LANTERN_WATCHMAN | Hooded night watchman with lantern and rattle | Gold |
| CHAMP_GUARD_CAPTAIN | Helmet with red plume, halberd, small shield | Metal + R1 |
| CHAMP_MONSTER_HUNTER | Long coat, crossbow, wooden stakes on belt | B0 leather + R1 |
| BOSS_EXORCIST | White-robed priest, sun-disc pendant, holy-water flask splashing | I2 + G1 |
| BOSS_WITCH_HUNTER | Wide-brimmed hat, net over shoulder, silver dagger, red sash | R1 + M2 |
| BOSS_BELL_RINGER | Hunched figure dragging a huge bronze bell | G0 + G1 |
| BOSS_INQUISITOR | Tall red hat with open-eye emblem, red robes, long scroll | R0 + R1 |
| SHOPKEEPER_UNDERTAKER | Skeletal merchant in top hat behind a coffin counter (2 frames, 64×32 sheet) | N4 + G1 |

**Enraged** (Night 8): no new sprite. Runtime: modulate toward `R1` 35%, 1 px `R1` outline shader, `vfx/aura` loop behind.

### 4.6 Dice & faces

| Asset | Size | Spec |
|---|---|---|
| `dice/die_body.png` | 20×20 | Rounded square (2 px stepped corners), `N0` outline, face area top 17 px in `B2` with `B1` shading, bottom 3 px "side" in `B0` (2.5D) |
| `dice/die_roll.png` | 80×20 | 4-frame tumble (blank faces), played 50 ms/frame before landing |
| `dice/glyph_<element>.png` ×6 + `glyph_wild.png` | 12×12 | Face glyph, drawn centred on face area at offset `(4, 3)`. Element ramp colours + `N0` outline |
| `dice/glyph8_<element>.png` ×6 + `glyph8_wild.png` | 8×8 | Small glyph for icons, essence pips, recipe book |
| `dice/pip_<element>.png` ×6 | 6×6 | Essence pip (simplified glyph in a dot) |
| `dice/mod_<sharp|swarm|hex|gold>.png` | 5×5 | Modifier badge, top-right of die at `(14, 1)` |
| `dice/die_select.png` | 22×22 | 1 px `G1` outline ring (drawn at die −1,−1). Selected die is also raised 3 px |
| `dice/die_bound.png` | 22×22 | 1 px white ring, tinted at runtime with group colour (§3) |
| `dice/die_shackle.png` | 20×20 | Chain overlay `M0/M1`; die dimmed via `N0` 50% checker pattern (no alpha) |
| `dice/face_tile.png` | 16×16 | Face square for Dice Inspector; glyph8 drawn centred |

Glyph shapes (must differ in silhouette):

| Element | Glyph |
|---|---|
| BONE | Crossed bones (X) |
| FIRE | Teardrop flame |
| ICE | 6-arm snowflake |
| LEAF | Single leaf with vein, tilted |
| VOLT | Zig-zag bolt |
| METAL | Hex nut (hexagon with hole) |
| WILD | Open eye with star pupil, `G1` + `N7` |

Modifier badges: SHARP = tiny blade `R1`; SWARM = 3 dots `L2`; HEX = spiral `N5/N7`; GOLD = coin `G1`.

---

## 5. Icons — 16×16

- 1 px transparent margin (live area 14×14), `N0` outline, max 6 colours, centred, top-left light.
- One readable idea per icon; no text inside icons.
- Consumables are **composed** by the placeholder/assembly script from bases + glyph8 (artist draws bases once).

### 5.1 Relics (25) — `icons/relics/<id_lowercase>.png`

| ID | Icon concept |
|---|---|
| RATTLE_DRUM | Drum with bone sticks |
| EMBER_JAR | Glass jar with embers |
| FROST_LANTERN | Lantern with blue flame |
| MOSS_CHARM | Mossy stone amulet |
| LIGHTNING_ROD | Iron rod with spark |
| IRON_NAIL | Big bent nail |
| GRAVEDIGGER_LAMP | Oil lamp, warm glow |
| WISP_JAR | Jar with tiny wisp inside |
| GRAVE_ROBBER | Sack with coin spilling |
| BONE_SAW | Saw with bone handle |
| DEEP_FREEZE | Ice cube with skull inside |
| COLD_HEARTH | Extinguished fireplace with snow |
| BONE_PILE | Small heap of bones |
| GRAND_PROCESSION | Tiny banner with marching dots |
| THRIFTY_GHOST | Ghost holding a coin |
| HYBRID_VIGOR | Two-coloured potion |
| COPYCAT_COFFIN | Two identical coffins |
| OVERGROWTH | Vine sprouting from skull |
| SPIRIT_BOARD | Wooden board with planchette (no real brand marks) |
| PIGGY_COFFIN | Piggy bank shaped like a coffin |
| TACTICIAN_SKULL | Skull with war helmet |
| CROWN_OF_THE_LICH | Spiked crown, gold |
| FULL_MOON | Full moon with face |
| BLACK_GRIMOIRE | Black book with eye clasp |
| ELEMENTAL_CONVERGENCE | Ring of 6 coloured dots |

### 5.2 Consumables (18) — `icons/consumables/<id_lowercase>.png`
| Base (artist-drawn) | Composition |
|---|---|
| `icons/bases/tome_base.png` (closed book, `N3` cover) | TOME_<E> = base + `glyph8_<e>` on cover at (4,4) |
| `icons/bases/sigil_base.png` (rune stone, `N4`) | SIGIL_<E> = base + `glyph8_<e>` centre |
| Unique: INK_WILD (ink bottle + eye), INK_SHARP (whetstone), INK_SWARM (seed pouch), INK_HEX (voodoo doll), INK_GOLD (gold leaf), SPARE_DIE (die with + sign) | drawn directly |

### 5.3 Equipment (8) — `icons/equipment/<id_lowercase>.png`
BONE_POUCH (small pouch), BONE_SATCHEL (bigger bag), GRAVE_BELL (bell), LOADED_CUP (dice cup), SECOND_CUP (two cups), RELIQUARY (ornate box), POCKET_CRYPT (tiny crypt), HAGGLER_LANTERN (lantern with price tag).

### 5.4 Stat icons — 8×8 (`icons/stats/`)
`coin, power (sword, I1), count (skull, R1), reroll (circular arrows), summon (candle), hp (heart R1), lock, info (i), book (recipe book)`.

---

## 6. UI layout (virtual px, origin top-left)

### 6.1 Global
- Safe margins: 4 px sides. Bottom 12 px kept free of buttons (home-indicator area).
- Min touch target: 20×20 virtual (80 physical px at ×4).
- Spacing grid: multiples of 2 px; default gap 4 px.
- Modal overlays: dim layer = `N0` at 70% alpha (the only alpha-blended UI layer allowed).

### 6.2 Encounter screen

```
y   0 ┌──────────────────────────────────────┐
      │ NIGHT 3 · BOSS              $12  ⚙   │ Top bar (16)
y  16 ├──────────────────────────────────────┤
      │   [R1][R2][R3][R4][R5]               │ Relic bar (22)
y  40 ├──────────────────────────────────────┤
      │              ▓▓ enemy ▓▓             │
      │              ▀▀pedestal▀▀            │ Enemy zone (88)
      │            THE EXORCIST              │
      │      [ Holy Water: BONE ½ Power ]    │
      │      ██████████████░░░░  1,200 HP    │
y 128 ├──────────────────────────────────────┤
      │                                      │
      │   BATTLEFIELD (army)                 │ 270 × 190
      │   expands with extra screen height   │
y 318 ├──────────────────────────────────────┤
      │ [⚔ 70] × [💀 36] = 2,520 / 1,200     │ Score panel (28)
      │  ●5  ●1  ●1  ●0  ●0  ●0  (essence)   │
y 346 ├──────────────────────────────────────┤
      │   [d][d][d][d]                       │ Dice tray (64)
      │   (1 Skeleton Warrior)(2 Wisp)       │ pending group chips
y 410 ├──────────────────────────────────────┤
      │ [C1][C2] [📖]   Summons 2 · Rerolls 1│ Status row
      │ [REROLL 1][ BIND ][SUMMON][ATTACK!]  │ Action buttons
y 480 └──────────────────────────────────────┘
```

| Element | Rect (x, y, w, h) | Notes |
|---|---|---|
| Top bar | 0, 0, 270, 16 | Left: Night + encounter label. Right: coin icon + money (`G1`), settings 16×16 at x 250 |
| Relic bar | centred, y 18, slots 20×20, gap 4 | 5 slots = 116 px wide (6 with Reliquary). Drag to reorder. Disabled relic: `N0` checker dim |
| Enemy sprite | 119, 44, 32, 32 | Pedestal 48×6 at 111, 74 (`N3`/`N4` stone), drawn behind the sprite's feet |
| Enemy name | centre, y 82, h 9 | `N7` |
| Rule chip | centre, y 93, h 12, max w 240 | chip 9-slice, `F2` text for boss rule; hidden for Mob/Champion |
| HP bar | 55, 108, 160, 7 | Projected damage shown as `G1` segment from the right end |
| HP text | centre, y 117, h 9 | `1,200 HP` |
| Battlefield | 0, 128, 270, 190 (+ extra height) | Groups in columns left→right; badge with Count above each cluster |
| Score panel | 4, 320, 262, 14 | Power box 48×14 (`I1`), `×`, Count box 48×14 (`R1`), `=`, projected `/` HP text. Projected ≥ HP → text `L2` |
| Essence row | centre, y 336, pips 6×6 + 1-digit count, gap 8 | Zero essence pips dimmed |
| Dice row | centred, y 352, dice 20×20, gap 6 | Up to 8 dice = 202 px |
| Pending chips | from x 8, y 380, h 20 | Chip: group colour number + unit icon 16×16 + short name; tap = unbind |
| Status row | y 414, h 20 | Consumable slots 20×20 at x 8, 32 (56 with Pocket Crypt); recipe book 20×20 at x 84; text right-aligned at x 266 |
| Action buttons | y 442, h 24, w 62, gap 4, x 5 | Reroll & Bind = secondary; Summon & Attack = primary. Disabled state when not allowed |

### 6.3 Shop screen
| Element | Rect | Notes |
|---|---|---|
| Top bar + relic bar | as Encounter | Tap relic → tooltip with SELL ($x) |
| Header | y 44, h 32 | Shopkeeper 32×32 at x 8; title "CRYPT MARKET" `F2` |
| Item cards ×3 | x 7, y 82, each 82×110, gap 5 | `panel_card`; rarity stripe 4 px top; icon ×2 (32×32) centred at card y+10; name 2 lines; price tag `G1`; BUY button 70×18 at bottom; consumables also show USE (buy & use) |
| Equipment card | 7, 198, 256, 48 | Icon ×2 left, name + effect text, price, BUY |
| Held consumables | 8, 254, slots 20×20 | |
| Reroll shop button | 170, 252, 92, 24 | "REROLL $4" secondary |
| Your dice strip | 8, 286, 254, 24 | Current dice faces (tap → Dice Inspector) |
| Continue | 5, 442, 260, 24 | primary "NEXT FIGHT" |

### 6.4 Night Map
- Header y 8: "NIGHT 3 / 8" + money.
- 3 encounter cards stacked: x 15, y 40 / 150 / 260, size 240×100 (`panel_card`): enemy sprite ×1 at left on pedestal, name, HP, reward, rule chip (boss). Current card has `G1` 1 px border; defeated cards stamped "DEFEATED" (`R1`, rotated stamp is pre-drawn, not runtime-rotated).
- FIGHT button: 5, 442, 260, 24 primary.

### 6.5 Title
- `bg_title`; logo 160×48 at x 55, y 72.
- Buttons 140×24 at x 65: Continue y 200, New Run y 230, How to Play y 260, Settings y 290.
- Footer text y 466: version + seed of last run (`N5`).

### 6.6 Overlays
| Overlay | Panel size | Content |
|---|---|---|
| Tooltip | max w 140, padding 4 | Header (icon ×2 + name), rarity/kind line, body text `N6` |
| Dice Inspector | 250 × 300 centred | One row per die: index + 6 `face_tile` 16×16 with glyph8 + badge; select up to N faces (`G1` ring); Confirm / Cancel |
| Cash-out | 200 × 160 centred | Lines (label left, `$` right `G1`), total, CONTINUE |
| Run Info / Recipe book | 260 × 420 | 6×6 pair matrix with unit icons 16×16 (cell 20×20 + header glyph8 row/col) + triple list + level table |
| Game Over / Victory | full screen panel | Title text large, stats list, buttons |
| Settings | 220 × 260 | Toggles/sliders built from button 9-slices |

---

## 7. UI components — construction rules

| Rule | Spec |
|---|---|
| Construction | Everything is 9-slice (`NinePatchRect`) or tiled; no full-size baked panels |
| Outline | 1 px `N0` outer outline on every panel/button |
| Bevel | 1 px highlight on top edge (lighter ramp step), 1 px shadow on bottom edge (darker step) |
| Corners | 1 px notched (cut) corners on all 9-slices |
| Fills | Flat colours only, no gradients, no dithering inside UI |
| Pressed button | Shift content down 1 px, swap highlight/shadow |
| Disabled | Fill `N2`, text `N4`, no bevel |
| Text colours | Primary `N7`, secondary `N6`, muted `N5`; on primary (`F1`) buttons text `N0` |

9-slice assets (`ui/`):

| File | Size | Margins | Fill / border |
|---|---|---|---|
| `panel_dark.png` | 24×24 | 6 | `N1` fill, `N3` inner border, `N0` outline |
| `panel_card.png` | 24×24 | 6 | `N2` fill, `N4` top highlight |
| `panel_tooltip.png` | 16×16 | 4 | `N0` fill, `N5` border |
| `chip.png` | 16×12 | 4 | `N3` fill, `N5` border |
| `btn_primary_{normal,pressed,disabled}.png` | 24×24 | 6 | `F1` fill, `F2` highlight, `F0` shadow |
| `btn_secondary_{normal,pressed,disabled}.png` | 24×24 | 6 | `N4` fill, `N5` highlight, `N2` shadow |
| `slot.png`, `slot_selected.png` | 20×20 | – | Empty slot `N2` with `N3` dashed inner border; selected `G1` ring |
| `hp_frame.png` | 16×7 | 3 | `N0` outline, `N2` inner |
| `hp_fill.png` | 1×5 | tile | `R1` rows 0–3, `R0` row 4 |
| `hp_preview.png` | 1×5 | tile | `G1` |
| `power_box.png`, `count_box.png` | 16×14 | 4 | `I1`/`I0` and `R1`/`R0` |
| `rarity_stripe_{common,uncommon,rare}.png` | 4×4 | tile | `I1` / `L1` / `R1` |
| `stamp_defeated.png` | 64×20 | – | `R1` stamp, pre-rotated |
| `divider.png` | 8×1 | tile | `N3` |

---

## 8. Typography & number formatting

| Use | Font | Size |
|---|---|---|
| Body / labels | **Fusion Pixel 8 px** (`assets/fonts/fusion_pixel/fusion_pixel_8px.otf`) | 8 px |
| Numbers (score, damage, HP) | **Fusion Pixel 12 px** (`fusion_pixel_12px.otf`) | 12 px |
| Damage slam / title | Numbers font drawn ×2 (showcase exception) | 24 px |

- Fusion Pixel (TakWolf) is SIL OFL 1.1: commercial use and bundling allowed; ship `OFL.txt` with it (`assets/fonts/LICENSES/README.md`). Latin subset (Basic Latin, Latin-1, Latin Extended-A, punctuation) — Vietnamese diacritics need a re-subset (§15 localization).
- Fonts rendered at their native pixel size only (no fractional sizes); disable font anti-aliasing and hinting.

Number formatting (`ui/number_label.gd`):

| Range | Format | Example |
|---|---|---|
| < 10,000 | Full with commas | `2,520` |
| 10,000 – < 1e15 | 3 significant digits + suffix K/M/B/T | `12.3K`, `4.56M` |
| ≥ 1e15 | Scientific | `1.23e15` |
| Setting "Full" | Always commas up to 1e15 | `12,345,678` |

Counters tick by interpolating displayed value over the step duration (GAME_SPEC §11.4).

---

## 9. Pipeline

### 9.1 Placeholders first (`tools/gen_placeholders.py`, Python + Pillow)
- Reads `assets/manifest.json` (generated from §11) and writes every PNG with the exact path, size and frame count.
- Placeholder look: solid shape in the category colour (units: element mid; enemies: `S1` body + accent; icons: `N4` square), `N0` outline, 2–3 letter tag in a 3×5 mini font, frame 2 offset by 1 px so animation is visible.
- Placeholder output must already pass the validator (§9.3), so final art can replace files 1:1 without code changes.

### 9.2 Final art — AI-assisted generation rules
1. **Lock anchors first** (human approval required): `skeleton_warrior`, `mob_torch_villager`, `glyph_fire` + `die_body`, `btn_primary_normal`. All later assets reference these.
2. Generate one category at a time, always passing anchors as style references.
3. Prompt template:
   ```
   pixel art sprite, {W}x{H} pixels, {subject concept from §4/§5},
   front-facing 3/4 view, spooky-cute Halloween style, limited palette,
   1-pixel dark outline, light from top-left, flat shading with 3-tone ramps,
   transparent background, no anti-aliasing, no text, no gradients,
   centered, readable silhouette
   ```
4. Post-process (`tools/pixelize.py`): downscale with nearest-neighbour by an exact integer factor (if the output is not grid-aligned, detect the pixel grid first) → quantise to Hallow32 in OKLab without dithering → alpha threshold 128 → re-outline with `N0` → trim to canvas with pivot rule.
5. **Manual cleanup pass is mandatory** for units, enemies, glyphs and logo (Aseprite / LibreSprite): fix stray pixels, symmetry, readability at ×1.
6. Review on device at ×1 against `bg_battle`, both alone and in a 60-sprite crowd test scene (`scenes/dev/horde_test.tscn`).

### 9.3 Validator (`tools/validate_art.py`) — must pass in CI / before each build
- File exists for every manifest entry; no unexpected files.
- Exact pixel size; frames = width / frame_width is an integer.
- Mode RGBA, alpha ∈ {0, 255}.
- Every opaque pixel ∈ Hallow32 (skip files flagged `mask`, use key-colour list instead).
- Colour-count limits per category (units 7, minis 4, enemies 12, icons 6).
- Icons: 1 px transparent border. Units: lowest opaque pixel on row 15 (unless flagged `floating` with shadow row). Enemies: row 31.
- No fully transparent frames.

---

## 10. Animation & juice reference (procedural, no extra frames)

| Effect | Spec |
|---|---|
| Unit idle bob | ±1 px at 1.5 Hz, phase offset per sprite |
| Summon pop | Scale 0 → 1.25 → 1.0 over 120 ms (ease-out back), spawn `puff` |
| Clone burst (×Count) | Each visible sprite spawns copy at ±4 px random offset, both punch 1→1.25→1 in 120 ms; SFX pitch rising |
| Group step highlight | Group chip and badge flash `G1` 2 frames |
| Lunge | Sprite tweens toward enemy (ease-in, 180 ms), returns (ease-out, 220 ms); 4 waves 100 ms apart |
| Hit flash | Enemy white via shader for 2 frames (≈ 33 ms) + 2 px shake for 150 ms |
| Enemy defeat | Flash, then pixel-dissolve shader (random pixel order) 500 ms, `puff` ×4 |
| Damage slam | Numbers font ×2, drop 8 px with bounce, colour `N7` with `R1` shadow |
| Screen shake | Max 3 px, 200 ms, disabled by setting |
| Reduce motion | No clone burst beyond 1 per group, no shake, no flashes; tween durations ×0.5 |

VFX sprites (`vfx/`):

| File | Size / frames | Notes |
|---|---|---|
| `spark.png` | 4×4 ×1 | White, tinted per element at runtime (allowed exception) |
| `puff.png` | 32×8 (4 × 8×8) | `N6/N7` smoke |
| `slash.png` | 48×16 (3 × 16×16) | Hit slash |
| `coin.png` | 24×6 (4 × 6×6) | Spinning coin |
| `soul.png` | 12×6 (2 × 6×6) | Soul wisp for SUMMON counters |
| `impact_ring.png` | 48×16 (3 × 16×16) | Impact ring |
| `aura.png` | 160×40 (4 × 40×40) | Enraged boss aura, `R1/R0` |

---

## 11. Asset manifest

| Category | Path pattern | Size (sheet) | Frames | Count |
|---|---|---|---|---|
| Units | `assets/sprites/units/<unit_id>.png` (WISP → `wisp_mask.png`) | 32×16 | 2 | 19 |
| Legion banner | `assets/sprites/units/legion_banner.png` | 16×16 | 1 | 1 |
| Crowd minis | `assets/sprites/minis/mini_<element>.png`, `mini_wisp_mask.png` | 16×8 | 2 | 7 |
| Enemies | `assets/sprites/enemies/<enemy_id>.png` | 96×32 | 3 | 9 |
| Shopkeeper | `assets/sprites/enemies/shopkeeper_undertaker.png` | 64×32 | 2 | 1 |
| Die body / roll | `assets/sprites/dice/die_body.png`, `die_roll.png` | 20×20 / 80×20 | 1 / 4 | 2 |
| Glyphs 12 | `assets/sprites/dice/glyph_<element|wild>.png` | 12×12 | 1 | 7 |
| Glyphs 8 | `assets/sprites/dice/glyph8_<element|wild>.png` | 8×8 | 1 | 7 |
| Essence pips | `assets/sprites/dice/pip_<element>.png` | 6×6 | 1 | 6 |
| Modifier badges | `assets/sprites/dice/mod_<sharp|swarm|hex|gold>.png` | 5×5 | 1 | 4 |
| Dice overlays | `die_select`, `die_bound`, `die_shackle`, `face_tile` | 22/22/20/16 | 1 | 4 |
| Relic icons | `assets/icons/relics/<relic_id>.png` | 16×16 | 1 | 25 |
| Consumable bases | `assets/icons/bases/tome_base.png`, `sigil_base.png` | 16×16 | 1 | 2 |
| Consumable icons | `assets/icons/consumables/<consumable_id>.png` (12 composed + 6 drawn) | 16×16 | 1 | 18 |
| Equipment icons | `assets/icons/equipment/<equipment_id>.png` | 16×16 | 1 | 8 |
| Stat icons | `assets/icons/stats/<name>.png` | 8×8 | 1 | 9 |
| UI 9-slices & parts | `assets/ui/*.png` (§7) | various | 1 | 22 |
| Backgrounds | `assets/bg/bg_title.png`, `bg_map.png`, `bg_battle.png`, `bg_shop.png` | 270×480 (+ 270×96 extension strip `bg_battle_ext.png` tiled for tall screens) | 1 | 5 |
| VFX | `assets/vfx/*.png` (§10) | various | various | 7 |
| Logo | `assets/ui/logo.png` | 160×48 | 1 | 1 |
| App icon | `assets/icon/app_icon_32.png` → exported ×16 to 512×512 | 32×32 | 1 | 1 |
| Palette | `assets/palette/hallow32.gpl`, `hallow32.png` | 32×1 | – | 2 |
| How-to-play images | `assets/ui/howto_1..4.png` (captured from game in M6) | 200×120 | 1 | 4 |

All filenames lowercase snake_case of the GAME_SPEC ID (e.g. `skeleton_warrior.png`, `crown_of_the_lich.png`).

Background rules:
- `bg_battle`: graveyard at night, crooked fence, distant village with tiny `F2` windows, moon top-right. Battlefield band (y 128–318) uses only `N1`/`N2` with very low detail.
- `bg_shop`: crypt interior, candles (`F1/F2` 1–2 px flames), shelves silhouettes.
- `bg_map`: winding village road with 3 lantern posts (cards sit on top).
- `bg_title`: big moon, castle silhouette, bats.
- Max 16 colours per background, ordered dithering allowed in sky only.

---

## 12. IP & licensing checklist

- Do not copy Balatro's UI layouts, card frames, fonts, shaders (e.g. CRT/vortex background) or colour scheme; mechanics inspiration only.
- No recognisable film characters: no Jack Skellington-like pumpkin-king figure, no Universal-style Frankenstein (flat head, neck bolts), no Disney Evil Queen silhouette. Headless Horseman is public-domain folklore — use an original design.
- No real-world religious symbols on enemies (use invented sun/eye/bell emblems).
- No real brand marks (e.g. on the spirit board).
- If an AI image tool is used: confirm its terms allow commercial use and that outputs can be owned/licensed by the studio; keep prompts and raw outputs in `art_source/` for provenance.
- Fonts: confirm licence (§8); keep licence files in `assets/fonts/LICENSES/`.
