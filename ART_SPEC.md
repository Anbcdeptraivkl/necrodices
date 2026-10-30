# ROLL THE BONES — Art Spec v2.0

> Companion to `GAME_SPEC.md`. IDs used here (units, relics, enemies…) are defined there and must not be renamed.
> Audience: artists, AI-image pipelines, and LLM coding agents integrating assets.
> Rule priority: **readability at 480×270 > consistency > detail**.

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
| Virtual resolution | **480 × 270** landscape (16:9) |
| Scaling | Integer only (×2 = 960×540, ×3 = 1440×810, ×4 = 1920×1080, ×8 = 3840×2160). Leftover space letterboxed in `N0`. |
| Aspect | The canvas grows on either axis to fill non-16:9 windows, up to **640×300** (21:9 / 16:10); the rest is letterboxed. Extra space goes to the centre column / battlefield (§6.1 flex rule). |
| Pixel grid | 1 virtual px = 1 art px. Sprites rendered at ×1 everywhere, except the **showcase exception**: icons may be shown at exactly ×2 in shop cards, tooltip headers and reward popups. Nothing else is upscaled. |
| Transient transforms | Scale punches / rotations allowed only during tweens ≤ 200 ms; resting state is always ×1, axis-aligned, pixel-snapped. |

Godot 4.6.3 project settings (agent must apply in M0):

```
display/window/size/viewport_width = 480
display/window/size/viewport_height = 270
display/window/size/window_width_override = 960
display/window/size/window_height_override = 540
display/window/stretch/mode = "viewport"
display/window/stretch/aspect = "keep"          # NOT "expand": expand + integer is buggy (godot#92055)
display/window/stretch/scale_mode = "integer"
display/window/handheld/orientation = "landscape"
rendering/textures/canvas_textures/default_texture_filter = Nearest
rendering/2d/snap/snap_2d_transforms_to_pixel = true
rendering/2d/snap/snap_2d_vertices_to_pixel = true
```
Non-16:9 windows: the `Display` autoload sets `Window.content_scale_size` to
`(clamp(window_w / scale, 480, 640), clamp(window_h / scale, 270, 300))` with
`scale = max(1, min(window_w / 480, window_h / 270))` on start and on every resize
(`core/display_fit.gd`, DECISIONS D-A08).
The built-in `keep` + `integer` stretch then renders that canvas at exactly `scale`.

Texture import preset (all PNGs): Filter Nearest, Mipmaps off, Compress Lossless, Repeat off.
Font import (`[importer_defaults] font_data_dynamic`): antialiasing off, hinting none, subpixel positioning off, system fallback off.
Web export (itch.io first, D-A10): Thread Support **off** (single-threaded: no COOP/COEP headers or SharedArrayBuffer), canvas resize policy Adaptive, background colour `#0d0a14`, VRAM compression For Desktop. itch.io embed: "Embed in page" 960×540 (= ×2) with the fullscreen button, Click to play on (unlocks audio).

---

## 3. Palette — "Hallow32"

All opaque pixels in final art must come from this list (exceptions: §4.3 mask files, VFX tint at runtime). Export as `assets/palette/hallow32.gpl`, `hallow32.hex` and `hallow32.png` (33×1 px strip; 32 colours + `K0`, file names kept). Source of truth: `tools/palette.py`.

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
| K0 | `#000000` | Pure black — the designer's deepest sky and void (added 2026-10-22, D-R14) |

Semantic mapping:

| Use | Colours |
|---|---|
| Element ramps | BONE `B0-B2`, FIRE `F0-F2`, ICE `I0-I2`, LEAF `L0-L2`, VOLT `V0-V2`, METAL `M0-M2` |
| Power box / numbers | `I1` fill, `I0` shadow, `N7` text |
| Count box / numbers | `R1` fill, `R0` shadow, `N7` text |
| Money | `G1` / `G0` |
| Rarity stripe | Common `I1`, Uncommon `L1`, Rare `R1` |
| Group bind colours (cycle) | 1 `I2`, 2 `L2`, 3 `F2`, 4 `N7` (`G1` is the selection ring only, D-R06) |
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
- Ritual, Elite and Parade units (GAME_SPEC §6.2, single bodies) may use the full 16×16; Elites carry a
  `G1` crown or horn mark.
- Legends (Quintet) are **32×32** (§4.2b).

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
| CLOCKWORK_KRAKEN | Brass / steel clockwork octopus, ice-blue eye, fire boiler glow (ritual) | Metal / Ice / Fire |
| HELLHOUND | Black-red hound with a flaming mane, `G1` horns (elite) | Fire |
| FROST_WRAITH | Floating hooded wraith, `G1` crown (elite, floating) | Ice |
| MANDRAKE_BRUTE | Hulking root creature, leaf crown, `S0` roots (elite) | Leaf |
| THUNDER_GHOUL | Hunched ghoul crackling with sparks (elite) | Volt |
| GARGOYLE | Stone / iron gargoyle with folded wings (elite) | Metal |
| PHANTOM_PARADE | Candle-lit procession of 3 tiny ghosts in element colours (rainbow, floating) | mixed |

### 4.2b Legends — 32×32 (Quintet)
- Sheet `64×32`, 2 frames (idle + breathing squash), lowest opaque row `y = 31`, max 12 colours,
  same outline / light rules. They must read grander than any 16×16 unit.
- BONE_DRAGON (skeletal dragon, `R1` eyes) · EMBER_COLOSSUS (molten rock giant) · FROST_WYRM
  (serpentine ice dragon) · ELDER_HOLLOW (walking dead tree, glowing face) · STORM_TITAN (giant
  gripping a bolt) · IRON_JUGGERNAUT (armoured war machine, `R1` eye slit).
- Source: `tools/art/legends.py`.

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
- Only horde units (T1, hybrids, Wisp) have minis: the `mini` field of their data row. Single units and legends
  are always drawn full size.
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
| `dice/die_body.png` | 20×20 | Rounded square (2 px stepped corners), `N0` outline, flat face area top 16 px in `B2` with an `N7` top-left light (no right shade column, designer repaint 2026-10-29), a `B1` band row, bottom 3 px "side" in `B0` (2.5D) |
| `dice/die_roll.png` | 80×20 | 4-frame tumble (blank faces), played 50 ms/frame before landing |
| `dice/glyph_<element>.png` ×6 + `glyph_wild.png` | 12×12 | Face glyph, drawn centred on face area at offset `(4, 3)`. Element ramp colours + `N0` outline |
| `dice/glyph8_<element>.png` ×6 + `glyph8_wild.png` | 8×8 | Small glyph for icons, essence pips, recipe book |
| `dice/pip_<element>.png` ×6 | 6×6 | Essence pip (simplified glyph in a dot) |
| `dice/die_body_<rune>.png` ×8 | 20×20 | The die's **material** while a rune face is up (§4.6b); same silhouette and side as `die_body`. GLASS shine streaks may be pure white `#ffffff` (D-A16) |
| `dice/num_1..9.png` | 7×9 | Points badge: `N0` rounded badge, `N7` digit; drawn at `(13, 11)` on the die |
| `dice/die_select.png` | 22×22 | 1 px `G1` outline ring (drawn at die −1,−1). A picked die is also raised 3 px |
| `dice/die_bound.png` | 22×22 | (unused in v2) 1 px white ring, tintable |
| `dice/die_shackle.png` | 20×20 | Chain overlay `M0/M1`; die dimmed via `N0` 50% checker pattern (no alpha) |
| `dice/face_tile.png`, `face_tile_<rune>.png` ×8 | 16×16 | Face square for the Dice Inspector / market dice / Codex runes: glyph8 at (4, 4), points digit bottom-right. Follows the die body: flat face, `N7` top-left light, the body's band colour on the bottom row, the rune material in the same corners / edges |

Glyph shapes (must differ in silhouette):

| Element | Glyph |
|---|---|
| BONE | Skull with slanted eyes and two teeth (8 px: upright eyes) |
| FIRE | Teardrop flame |
| ICE | 6-arm snowflake |
| LEAF | Single leaf with vein, tilted |
| VOLT | Zig-zag bolt |
| METAL | Round nut: `M2` rim, `M1` ring, `N0` hole (8 px: square nut) |
| WILD | Open eye with star pupil, `G1` + `N7` |

### 4.6b Runes (GAME_SPEC §4.6) — the die body changes material
A rune lives on one face; while that face is up the whole die body shows its material, like a
Balatro enhancement changes the card background. Rune details stay where the glyph and the points
badge leave the body visible. Source: `tools/art/dice_runes.py`.

| Rune | Material |
|---|---|
| SHARP | bone die with blood-red `R1` serrated / notched edges |
| SWARM | bone die speckled with green `L1` moss spots |
| WILD | prismatic diagonal bands of element colours |
| GLASS | pale `I2` glass, `I1` shade, `N7` highlight streak and one crack |
| IRON | `M1` steel plate, `M0` corner rivets, `M2` highlight |
| TOMB | `N5`/`N4` stone slab with a carved cross — no glyph, no points drawn |
| GILDED | `G1` gold, `G0` shade, `F2`/`N7` shine |
| LUCKY | `L2` green, `L1` shade, tiny four-leaf clover in a corner |

*(stretch)* Die finishes (Ivory / Spectral / Cursed) would be a rim on the body; marks a stamp in a corner.

---

## 5. Icons — 16×16

- 1 px transparent margin (live area 14×14), `N0` outline, max 6 colours (trinket / relic icons 7), centred, top-left light.
- One readable idea per icon; no text inside icons.
- Each item kind has one family look (designer request 2026-10-23): **trinkets** = small charms and
  curios, **potions** = bottles, **gems** = cut gems, **gear** = equipment / tools, **coffers** = small
  coffins. Sources: `tools/art/icons.py` (trinkets, gear) and `tools/art/items.py` (potions, gems,
  coffers).

### 5.1 Trinkets (30) — `icons/relics/<id_lowercase>.png`
The v1 relic concepts stay for the kept ids (RATTLE_DRUM … ELEMENTAL_CONVERGENCE). New:
TRIO_TOTEM (carved three-face totem), MOON_CHARM (crescent on a cord), LOADED_BONE (knucklebone
with a lead weight), GILDED_TOOTH (gold tooth), LAST_RITES (candle on a skull), BLOOD_MOON (red
moon, replaces FULL_MOON).

### 5.2 Potions (17) and gems (8) — `icons/consumables/<id_lowercase>.png`
- Potions: ELIXIR_<E> share one round flask with the element ramp as liquid; every other potion
  has its own bottle shape (tall vial, whetstone oil, bubbling swarm brew, rainbow wild spirits,
  cracked glass draught, metal flask, dust vial, liquid gold, clover, mirror, dark hermit bottle).
- Gems: a different cut each — OPAL milky, GARNET red, AMBER gold, PRISM rainbow, MOONSTONE pale
  blue, OBSIDIAN black glass, EMERALD green square, BLOODSTONE spotted red.

### 5.2b Coffers (12) — `icons/coffers/<id_lowercase>.png`
Upright coffins with an emblem of their content (bottle / gem / charm / die). Normal = small,
JUMBO = bigger with dark lid bands, MEGA = biggest with `G1` trim.

### 5.3 Gear (13) — `icons/equipment/<id_lowercase>.png`
GRAVE_BELL / DEATH_KNELL, LOADED_CUP / SECOND_CUP, RELIQUARY / OSSUARY, HAGGLER_LANTERN /
BLACK_MARKET, OVERSTOCK / OVERFLOWING_CRYPT, GRAVE_GOODS / DRAGON_HOARD, POCKET_CRYPT. A tier-2 icon
is visibly the upgraded twin of its tier 1 (bigger, darker or gold-trimmed).

### 5.4 Stat icons — 8×8 (`icons/stats/`)
`coin, power (sword, I1), count (skull, R1), reroll (circular arrows), summon (candle), hp (heart R1), lock, info (i), book (recipe book)`.

---

## 6. UI layout (virtual px, origin top-left, landscape)

> Status: **approved 2026-10-20** (D-A09). Wireframes:
> `docs/mockups/*.png`, generated from these tables by `python tools/layout_mockup.py`.

### 6.1 Global
- Base canvas 480×270. Every screen has three columns: **left 4..124** (information),
  **centre 128..w−128** (the stage: enemy, battlefield, dice, cards), **right w−124..w−4**
  (player controls). Rects below are for the base canvas.
- **Flex rule** (canvas up to 640×300, §2): side columns anchor left / right, the top bar
  anchors top, the dice tray and action buttons anchor bottom. Extra **width** widens the
  centre column, extra **height** goes to the battlefield (Encounter), the info panel and the
  card area. Backgrounds are 640×300, centred (§11).
- Safe margins: 4 px on every side. Min touch / click target: 20×20 virtual.
- Primary input is the mouse (Web desktop, D-A10). No docked info panel and no hint text
  (D-R16): buttons say what they do, and **items** (trinkets, potions, gems, gear, coffers,
  market cards, rune faces, squads, Codex rows) explain themselves in a hover tooltip. Hunters,
  rule panels and plain numbers have no tooltip. Clicking an owned item opens its small action
  menu (USE / SELL), which is also the touch path.
- **Top bar loadout** (Balatro): a trinket block (drag to reorder) and, after a divider, the
  potion / gem block, centred in the top bar on every run screen.
- Spacing grid: multiples of 2 px; default gap 4 px.
- Modal overlays: dim layer = `N0` at 70% alpha (the only alpha-blended UI layer allowed).

### 6.2 Battle screen (v2)

```
y   0 ┌──────────────┬──────────────────────────────────────┬────────────────────┐
      │ NIGHT 3·BOSS │        [T1][T2][T3][T4][T5]          │          $12  📖 ⚙ │ Top bar (24)
y  28 ├──────────────┼──────────────────────────────────────┼────────────────────┤
      │ BOSS RULE    │            ▓▓ hunter ▓▓              │ [SUMMON 2][REROLL 2]│
      │ Holy Water…  │           THE EXORCIST               ├────────────────────┤
      │[⚔73]×[💀2]   │    ██████████████░░░░  1,200 HP      │  Duo Pact  Lv1     │
      │ = 146        │        COMBO BANNER / SLAM           │ [d][d][d][d][d]    │ Pick tray
      │ ARMY 210/1.2K│                                      │  73 × 2 = 146      │
      │●1 ●2 ●0 …    │           BATTLEFIELD (army)         ├────────────────────┤
      │[P1][P2]      │      squads in centred columns       │ GROUPS             │
      │ INFO PANEL   │                                      │ [icon Rabble   64] │
      │              │   [d][d][d][d][d][d][d][d]           │ hint               │
      │              │                                      │ [REROLL][ROLL/SUMMON]│
y 270 └──────────────┴──────────────────────────────────────┴────────────────────┘
```

| Element | Rect | Notes |
|---|---|---|
| Top bar | 0, 0, 480, 24 | As v1: label, trinket bar (drag to reorder), money, Codex + Settings |
| Rule panel | 4, 28, 120, auto | Role (muted), one line per rule (`F2`; "No special rule" muted), "Bounty $n" (`G1`) on its own line |
| Score panel | 4, 72, 120, ~50 | The squad being picked / scored: Power box `I1` × Count box `R1`, `= strength`; line ARMY `a / HP` (gold while a preview, `L2` once ≥ HP). Boxes bounce when their number changes |
| Element pips | under the score panel | Scored dice per element this battle (+ the preview) |
| Loadout | left column, rest of the height | GEAR (owned gear icons) and DICE (one face tile per die: its rune face, else its best non-BONE face; click → Dice Inspector) |
| Hunter | centre: name y 1, HP bar y 12 (160×7), HP text y 20; the 32×32 hunter stands **on the ground** below them (feet at stage y 80, a 24×2 `N0` shadow), never on the village roofline | HP bar shows army + preview as the `G1` segment |
| Banner / slam | centred, just above the army (stage y ~88) | Combo banner "TRIO Lv2" (`G1`), strength slam "P × C = S", result banners |
| Battlefield | centre, between HP text and tray | Squads in columns, centred when they do not fill it; horde squads = soldiers, single / legend = one body + aura |
| Dice tray | bottom of the centre column, dice 20×23, gap 8 (room for the ×1.4 scoring punch: 8 dice = 216 px) | All dice (5–8). Picked dice raised with the `G1` ring; shackled dice dimmed |
| Counters | 356, 28 | SUMMON n / REROLL n chips |
| Pick tray | 356, ~52, 120 | Header "CURRENT DICE" (muted, left, like "GROUPS"), the picked dice in pick order, combo + level and the preview `P × C = S` (`G1`) once a combo forms; no hint text |
| Squads | below, flexible | A grid of 22×22 unit icons, one per summoned squad; combo, P × C and strength in the tooltip |
| Pick actions | bottom right, stacked | REROLL (secondary, 120×26) over SUMMON (`BigButton`: primary, 12 px text, 120×36) |
| Big actions | centre of the stage, between summons | ROLL (`BigButton` with a tumbling die icon) and ATTACK! (`DangerButton`: the blood-red button, sword-slash icon) at 96×36; ATTACK! breathes gold once the army beats the HP; only ATTACK! when the summons are spent |

### 6.3 Shop screen (Balatro layout, D-R16)
The screen is dark (`N0`); only the right column is decorated (D-R12). The shop itself is **one
frame** (`panel_dark`, x 4–352, y 28–266) holding a 2×2 grid with 4 px gaps; trays are
`TrayPanel` (flat `N0`, 1 px `N2` border). No captions, no names: every item is the same card and
explains itself in its tooltip.

```
┌──────────┬──────────────────────────────┐
│  NEXT    │   [card] [card] ( … up to 4) │  row 1: buttons 84 wide | cards tray
│  BATTLE  │                              │
├──────────┤                              │
│ REROLL $5│                              │
├──────────┼──────────────────────────────┤
│ [gear]   │   [coffer] [coffer]          │  row 2 (108 tall): gear tray | coffers tray
└──────────┴──────────────────────────────┘
```

| Element | Notes |
|---|---|
| Top bar | Trinket block + potion / gem block (click an owned item → USE / SELL $n), money, Dice, Codex, Settings |
| NEXT BATTLE / REROLL $n | Two tall buttons filling the left half of row 1 (primary / secondary) |
| Market card (`ShopCard`, 56 wide, fixed height) | Price tag `G1`, 2 px rarity stripe (trinkets only, space kept on all), art 32×32 ×2 (a die: its six face tiles), BUY, then a second row that is BUY+USE for potions / gems and empty otherwise — so every card lines up. Sold = 45% alpha, "Sold out" |
| Cards tray | Row 1 right: market cards centred |
| Gear tray | Row 2 left: the night's gear as the same card (BUY) |
| Coffers tray | Row 2 right: coffers as the same card (price, coffin, OPEN); the Coffer overlay shows choices as the same card with TAKE |
| Decor | Column C: `shop_decor.png` alcove anchored bottom, the shopkeeper in front, "CRYPT MARKET" near the top |

### 6.4 Night Map
- Background: a plain ordered-dither fade, light at the top (`N3`) to dark at the bottom
  (`N0`), no scenery (D-R12): the cards carry the information.
- Top bar as Encounter (Night label "NIGHT 3 / 8", relics, money, Codex, Settings).
- 3 encounter cards side by side: x 8 / 164 / 320, y 32, 152×192 (`panel_card`): enemy sprite ×1
  on pedestal at the top centre, name, role, HP, "Bounty $n" on its own line, rule chip (boss);
  no tooltip (the card already shows everything).
  Current card has `G1` 1 px border; defeated cards stamped "DEFEATED" (`R1`, pre-drawn stamp).
- FIGHT button: centred, y 236, 160×24 primary.

### 6.4b Hover, press and tooltips (all screens, D-R13)
- Buttons: hover = lighter 9-slice + label lifted 1 px; press = 120 ms squash (1 → 0.92 → 1).
- Custom controls (slots, dice, chips, face tiles): hover highlight drawn by the control (`N5`
  ring, 1 px lift, bright chip border) and the same press squash.
- Tooltips: one pixel panel above everything, beside the pointer (flips at the canvas edges,
  never under the pointer). Opens after 0.25 s at rest; moving to another target switches it
  at once; leaving keeps it 0.15 s (gaps between slots never blink); hidden while dragging,
  holding a button, and after a click until the pointer reaches another target.

### 6.5 Title
- `bg_title` centred; logo 160×48 centred at y 40.
- Buttons 140×24 centred (x 170 at base), gap 4: Continue y 104, New Run y 132, How to Play
  y 160, Settings y 188.
- Footer y 258: version + seed of last run (`N5`). Everything anchors to the canvas centre.

### 6.6 Overlays (centred on the canvas)
| Overlay | Panel size | Content |
|---|---|---|
| Tooltip (floating) | max w 140, padding 4 | Only over overlays, where the info panel is covered. Header (icon ×2 + name), kind line in its colour, price (`G1`), body `N6` — one idea per line, never joined with "·" |
| Dice Inspector | 300 × 232 | One row per die: index + 6 face tiles 16×16 (rune material, glyph8, points); pick up to N faces in order (`G1` ring + order number); Confirm / Cancel |
| Spoils | 200 × 160 | Lines (label left, `$` right `G1`), total, CONTINUE |
| Codex | 464 × 252 | Tabs: COMBOS (illustrated combos with level and P × C, the 4 rituals) · MONSTERS · HUNTERS · RUNES · TRINKETS · POTIONS · GEMS · GEAR — a grid of 34×34 cells (art at integer scale, kind-coloured ring) and a detail pane: art, name, kind line in its colour, price, effect, a short description (one idea per line) |
| Coffer | 300 × 170 | The opened coffer's choices as market cards with TAKE, "Choose n", SKIP |
| Game Over / Victory | full canvas | Title text large, stats list, buttons |
| Settings | 220 × 200 | Toggles / sliders built from button 9-slices |
| Confirm | 200 × 80 | Message + two buttons |

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
| `btn_{primary,secondary}_hover.png` | 24×24 | 6 | The normal button one ramp step lighter (`F1→F2`, `F2→V2` / `N4→N5`, `N5→N6`), derived by `tools/art/ui_buttons.py` (D-R09) |
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
| Dice roll (v2) | Every die tumbles; each lands at its own random time 0.35–0.9 s, one die always last; a small hop and a click per landing |
| Number pop (v2) | Each scored die / rune / trinket step pops its label (`+5 Power` `I1`, `+3 Count` `R1`) above the die or trinket: punch ×1.6 → 1, rising 10 px and fading |
| Scoring dice (v2) | During a summon the summoned dice stay raised: scoring ones with the lit ring, unscored ones at 45 % alpha. The die being scored punches ×1.4 → 1 (never touching its neighbours), flashes white and shakes ±1 px; the trinket whose turn it is wobbles ±2 px. Rest look is exact again when playback ends or is skipped |
| Aura tiers (v2) | Single units and legends: Count ≥ 10 → `vfx/aura` ring tinted with the element light colour; ≥ 40 → + `vfx/flame` crown; ≥ 160 → flame ×2 |
| Charge (v2) | One squad at a time flies at the hunter (3 waves), impact flash + shake, the HP bar drains by that squad's share, `-damage` pops |
| Result (v2) | Win: dissolve, `$` burst, banner "THE HUNTER FALLS!"; loss: the hunter laughs (fast idle), the army drifts and fades, banner "THE HUNTERS PREVAIL" |

VFX sprites (`vfx/`):

| File | Size / frames | Notes |
|---|---|---|
| `spark.png` | 4×4 ×1 | White, tinted per element at runtime (allowed exception) |
| `puff.png` | 32×8 (4 × 8×8) | `N6/N7` smoke |
| `slash.png` | 48×16 (3 × 16×16) | Hit slash |
| `coin.png` | 24×6 (4 × 6×6) | Spinning coin |
| `soul.png` | 12×6 (2 × 6×6) | Soul wisp for SUMMON counters |
| `impact_ring.png` | 48×16 (3 × 16×16) | Impact ring |
| `aura.png` | 160×40 (4 × 40×40) | Enraged boss aura, `R1/R0`; also the tinted unit aura |
| `flame.png` | 128×32 (4 × 32×32) | Flame crown in `N7/N6/N5`, tinted per element at runtime |

---

## 11. Asset manifest

| Category | Path pattern | Size (sheet) | Frames | Count |
|---|---|---|---|---|
| Units | `assets/sprites/units/<unit_id>.png` (WISP → `wisp_mask.png`) | 32×16 | 2 | 26 |
| Legends | `assets/sprites/units/<unit_id>.png` | 64×32 | 2 | 6 |
| Legion banner | `assets/sprites/units/legion_banner.png` | 16×16 | 1 | 1 |
| Crowd minis | `assets/sprites/minis/mini_<element>.png`, `mini_wisp_mask.png` | 16×8 | 2 | 7 |
| Enemies | `assets/sprites/enemies/<enemy_id>.png` | 96×32 | 3 | 9 |
| Shopkeeper | `assets/sprites/enemies/shopkeeper_undertaker.png` | 64×32 | 2 | 1 |
| Die body / roll | `assets/sprites/dice/die_body.png`, `die_roll.png` | 20×20 / 80×20 | 1 / 4 | 2 |
| Glyphs 12 | `assets/sprites/dice/glyph_<element|wild>.png` | 12×12 | 1 | 7 |
| Glyphs 8 | `assets/sprites/dice/glyph8_<element|wild>.png` | 8×8 | 1 | 7 |
| Essence pips | `assets/sprites/dice/pip_<element>.png` | 6×6 | 1 | 6 |
| Rune bodies | `assets/sprites/dice/die_body_<rune>.png` | 20×20 | 1 | 8 |
| Points badges | `assets/sprites/dice/num_<1..9>.png` | 7×9 | 1 | 9 |
| Dice overlays | `die_select`, `die_bound`, `die_shackle`, `face_tile`, `face_tile_<rune>` ×8 | 22/22/20/16 | 1 | 12 |
| Trinket icons | `assets/icons/relics/<relic_id>.png` | 16×16 | 1 | 30 |
| Potion / gem icons | `assets/icons/consumables/<id>.png` | 16×16 | 1 | 25 |
| Coffer icons | `assets/icons/coffers/<coffer_id>.png` | 16×16 | 1 | 12 |
| Gear icons | `assets/icons/equipment/<equipment_id>.png` | 16×16 | 1 | 13 |
| Stat icons | `assets/icons/stats/<name>.png` | 8×8 | 1 | 9 |
| UI 9-slices & parts | `assets/ui/*.png` (§7) | various | 1 | 22 |
| Backgrounds | `assets/bg/bg_title.png`, `bg_map.png`, `bg_battle.png` | 640×300 (largest canvas), drawn centred; the 480×270 centre at (80, 15) is the safe area | 1 | 3 |
| Shop decor | `assets/bg/shop_decor.png` | 120×182 (shop column C1) | 1 | 1 |
| VFX | `assets/vfx/*.png` (§10) | various | various | 8 |
| Logo | `assets/ui/logo.png` | 160×48 | 1 | 1 |
| App icon | `assets/icon/app_icon_32.png` → exported ×16 to 512×512 | 32×32 | 1 | 1 |
| Palette | `assets/palette/hallow32.gpl`, `hallow32.png` | 32×1 | – | 2 |
| How-to-play images | `assets/ui/howto_1..4.png` (captured from game in M6) | 200×120 | 1 | 4 |

All filenames lowercase snake_case of the GAME_SPEC ID (e.g. `skeleton_warrior.png`, `crown_of_the_lich.png`).

Background rules (style reference: the designer's hand-drawn `bg_title` and `bg_battle`, 2026-10-22):
- **Style:** big flat silhouettes in `N0`–`N2`; the sky fades from the darkest value in
  row-alternating ordered dither; single-pixel `N7` stars; one bright focal point (moon, white
  dead trees); a few `F2` warm dots. Low detail, no texture patterns, no extra shading. Every
  element states what the screen is for.
- `bg_title`, `bg_battle`: **hand-drawn by the designer — no generator owns them; never edit
  without the designer's permission.** The battlefield area (bg x 128–512, y 98–268) stays
  plain so the army reads.
- `bg_map` (`tools/art/backgrounds.py`): a plain light-to-dark fade (`N3` → `N0`), no scenery.
- `shop_decor` (`tools/art/backgrounds.py`): the shop's only decoration, 120×182 in column C —
  an arched alcove with the undertaker's shelf (skulls, one tall candle, a pile of coins); the
  shopkeeper sprite stands in front of it. The rest of the shop screen is plain `N0`.
- Max 16 colours per background, ordered dithering in the sky / glow only.

---

## 12. IP & licensing checklist

- Do not copy Balatro's UI layouts, card frames, fonts, shaders (e.g. CRT/vortex background) or colour scheme; mechanics inspiration only.
- No recognisable film characters: no Jack Skellington-like pumpkin-king figure, no Universal-style Frankenstein (flat head, neck bolts), no Disney Evil Queen silhouette. Headless Horseman is public-domain folklore — use an original design.
- No real-world religious symbols on enemies (use invented sun/eye/bell emblems).
- No real brand marks (e.g. on the spirit board).
- If an AI image tool is used: confirm its terms allow commercial use and that outputs can be owned/licensed by the studio; keep prompts and raw outputs in `art_source/` for provenance. Designer source files (`.aseprite`, layered PNGs) also live in `art_source/` (it has a `.gdignore`, so Godot never imports or ships it).
- Fonts: confirm licence (§8); keep licence files in `assets/fonts/LICENSES/`.
