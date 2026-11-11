# Art rework plan — matching the designer's repaints

Status (2026-11-11): batch 0 (tooling) and the **UI kit are done and in `assets/ui`**. The
pilot review cut the generated units: the designer draws units, legends, the shopkeeper and the
banner by hand (§7). The logo "Necrodicer" and the rename are done; the VFX proposal was rejected
and nothing of it was kept (§7.2). Left to do: batches 6b, 7b, 8.
Owner of the style: the designer.
Scope: redo the sprites and UI art the designer has not touched, so they sit with the repainted
ones. Files the designer edited are never written (§3, §6.1).

Normative sources stay GAME_SPEC / ART_SPEC / DECISIONS. Once a batch is approved, its rules move
into ART_SPEC and this file only tracks progress.

---------------------------------------------------------------------------------------
## 1. How "edited" was decided

Every manifest file was compared, pixel by pixel, with what its generator recipe in
`tools/art/*.py` draws today (visible pixels only).

- **Differs from the recipe → designer-edited → keep.** 130 files.
- **Equal to the recipe → untouched → candidate.** 83 files.
- **No recipe** → 21 UI files (scaffold placeholders from `tools/gen_placeholders.py`), candidates;
  and `bg_title` / `bg_battle`, off-limits whatever their state.

130 + 83 + 23 = the 236 files of the manifest.

Two kinds of "equal" files are not really untouched: `face_tile*`, `glyph8_{bone,fire,volt,metal}`
and `pip_bone` were re-derived from the designer's dice in `16f0f38`, and `howto_*` are composed
from other sprites. They are *derived* art: rebuilt from the source, not redesigned.

The comparison is re-run before every batch, so a file the designer picks up in the meantime
drops out of the candidate list by itself.

---------------------------------------------------------------------------------------
## 2. Before / after study — what the designer changes

Measured on frame 0 of each pair (generator recipe → designer file):

| Category | Files | Colours | What changed |
|---|---|---|---|
| Units 16×16 | 6 | 6.0 → 5.0 | Faces, silhouettes, accents (below) |
| Legends 32×32 | 4 | 8.0 → 6.8 | 380–780 px each: faces, limbs removed, bolder interior lines |
| Hunters 32×32 | 9 | 11.7 → 9.2 | Full repaint (ART_SPEC §4.5a); opaque area 51 % → 45 % |
| Trinket icons | 30 | 5.6 → 5.1 | One object per icon, bigger, flatter |
| Potions / gems | 25 | 5.5 → 4.7 | Specular dots and facet noise removed |
| Coffers | 12 | 6.0 → 4.8 | Side shading removed, band + emblem only |
| Gear icons | 11 | 5.5 → 4.8 | Secondary objects removed |
| Stat icons 8×8 | 10 | 4.1 → 3.2 | Redrawn as one bold symbol |
| Glyphs | 7 | 3.7 → 3.0 | Fill 58 % → 66 % of the canvas |
| Die bodies | 8 | 5.4 → 5.4 | Chamfered slab with a bottom lip (§4.3 below) |
| Minis 8×8 | 7 | 4.0 → 3.3 | One blob + face per element |

Canvas fill and the share of outline pixels barely move. The designer does not make things
bigger or thicker in general; the work goes into **fewer tones, simpler faces, calmer shapes**.

### 2.1 The seven habits

1. **One tone less.** A material is a flat fill plus one shade, not a three-step ramp. The
   mid-tone "pillow" band next to the outline goes first (Flame Skull 7 → 4 colours: the jaw
   gradient and the second flame tone are gone).
2. **The face is the character, and it is two marks.** Three face types cover everything:
   - *angry sockets*: two slanted 2–3 px eyes in `N0` (Fire Imp, Flame Skull, the bone glyph,
     the app icon, Tactician Skull);
   - *dark band*: a 1–2 row `N0`/`N1` slit with two light dash eyes (Frost Wraith, Ember
     Colossus, Bell Ringer, Haunted-style visors);
   - *dot face*: two 1 px dots and at most a 2 px mouth, for cute things (Thrifty Ghost,
     Elder Hollow's sleepy eyes, Piggy Coffin, the volt mini).
   Noses, teeth rows, pupils and open mouths are removed.
3. **Chunky silhouette that widens to the ground.** Thin limbs and loose appendages go:
   Elder Hollow lost its arm branches and root legs and became one trunk; Frost Wraith lost its
   arms and became a bell; the hunters are trapezoids.
4. **One accent, one place.** Scattered rivets, sparks and second props are deleted
   (Clockwork Kraken: orange rivets gone, one porthole eye left; Thrifty Ghost: the coin bag
   shrank to 2 px). The remaining accent marks the focal point.
5. **Interior lines are `N0`, not a darker ramp step.** Bone Dragon's ribs and the legends'
   joints are separated with outline-colour lines; it reads at ×1 where mid-tone lines blur.
6. **Objects stand on something.** Die bodies, coffers, jars and the app icon have a darker
   2–3 px base band (a "lip") instead of side shading. Light is a 1–2 px glint in one corner.
7. **Icons are one object, centred, filling the canvas.** Lucky Clover is only the clover;
   Iron Draught is only the block; Summon is only the flame.

What the designer keeps from the generator: canvas sizes, pivots, the `N0` 1 px outline, the
Hallow32 palette, the 2-frame idle (frame 1 = the same drawing 1 px higher or squashed), the
`N0` shadow dash under floating units.

---------------------------------------------------------------------------------------
## 3. Inventory

### 3.1 Keep — never written (130 files + 2 backgrounds)

| Group | Files |
|---|---|
| Units | `fire_imp`, `frost_bat`, `flame_skull`, `bog_witch`, `clockwork_kraken`, `frost_wraith` |
| Legends | `bone_dragon`, `ember_colossus`, `frost_wyrm`, `elder_hollow` |
| Hunters | all 9 (`mob_*`, `champ_*`, `boss_*`) |
| Minis | all 7 |
| Dice | 8 die bodies (all but `die_body_wild`), 7 glyphs |
| Icons | 30 trinkets, 25 potions / gems, 12 coffers, 11 gear, 10 stat icons, `app_icon_32` |
| Backgrounds | `bg_title`, `bg_battle` (off-limits by standing order) |

### 3.2 Redo — 83 candidates + 21 placeholders

| Group | Files | Kind of work |
|---|---|---|
| Units | 20 (list in §4.1) | Redesign |
| Legends | `storm_titan`, `iron_juggernaut` | Redesign |
| Characters | `shopkeeper_undertaker`, `legion_banner` | Redesign |
| UI kit | 27 files in `assets/ui` (buttons, panels, chip, slots, HP, Power / Count boxes, stripes, divider, stamp) | Redesign (§4.3) |
| Dice extras | `die_body_wild`, `die_roll`, `die_select`, `die_bound`, `die_shackle` | Align with the slab |
| Small glyphs | `glyph8_{ice,leaf,wild}`, `pip_{fire,ice,leaf,volt,metal}`, `num_1..9` | Re-derive from the big glyphs |
| Gear icons | `grave_bell`, `death_knell` | Redesign (2) |
| VFX | 8 sheets | Light pass: tone count only |
| Derived | `face_tile*`, `howto_1..4`, `docs/art_sheets/*` | Rebuild after their sources change |
| Logo | `logo` | Redesign with the new name **Necrodicer** (§4.6) |
| Backgrounds | `bg_map`, `shop_decor` | Redesign, each for its role (§4.6) |

---------------------------------------------------------------------------------------
## 4. Design

### 4.1 Units — 16×16, 20 files — CUT (the designer draws them)

The pilot units (`skeleton_warrior`, `haunted_armor`, `jack_o_lantern`) were rejected in review on
2026-11-11; their recipes were restored and nothing was written. The notes below stay as a record
of what differs from the designer's style, not as a to-do list.

Rules: ≤ 5 colours for single-element units, ≤ 6 for hybrids and elites (today 5–7); one of the
three face types; no limb thinner than 2 px unless it is the prop; one accent; interior lines in
`N0`. Frame 1 is frame 0 moved or squashed 1 px, never a redraw. Each unit must still pass the
existing silhouette and "≥ 40 % mid / light pixels" rules.

The designer's minis are the brief for the T1 units: the unit is the mini with a body.

| Unit | Problem today | Direction |
|---|---|---|
| `skeleton_warrior` | Square sockets, 1 px arms, thin sword | Bone-glyph skull (angry sockets) as a big head, stub body, sword gripped in a fist |
| `pumpkinling` | Sprout bigger than the body, 1 px vine legs; no longer matches `mini_leaf` | **A leaf creature** (designer decision): the `mini_leaf` leaf as the body, with eyes and a mouth, on 2 px feet. The display name stays until the designer renames it |
| `volt_ghost` | Diamond with a spiky outline, weak face | Round spark blob with the dot face of `mini_volt`, one zigzag tail |
| `haunted_armor` | Three metal tones, dithered plates | Helmet + breastplate in two tones, dark-band visor with two `V2` dashes |
| `scarecrow` | Thin cross shape, face lost under the hat | Sack head with angry sockets, wide hat, body as one poncho block on a pole |
| `shield_skeleton` | Shield has a dithered emblem and two tones | Flat tower shield with one `N0` emblem, skull peeking with angry sockets |
| `steam_slime` | Fine, but shaded on both halves | Two flat halves, dot face, one steam puff |
| `jack_o_lantern` | Ribbed shading, checker teeth | Flat pumpkin, carved angry sockets and a zigzag mouth lit `F2`, short vine body |
| `storm_banshee` | Dithered hair, open-mouth face | Solid `V1` hair spikes, dark-band face on an `I1` body |
| `tesla_spider` | Eight 1 px legs | Four 2 px legs, dome body, one glowing coil as the accent |
| `wisp_mask` | Fine | Tone pass only; must keep both mask ramps (`A*` body, `C*` spark) |
| `headless_horseman` | Too many parts at 16 px | Horse as one block, rider as a cloak block, pumpkin head is the only accent |
| `stitched_golem` | Scattered lightning stitches | Two-tone bulk, one stitch line, crown kept |
| `witch_queen` | Soft gown gradient | Gown as a trapezoid, dark-band or dot face, orb as the accent |
| `lich` | Close already | Bone-glyph skull, flat robe, staff gripped |
| `hellhound` | Flame mane in three tones over a thin body | Stocky body, flat mane, angry eye |
| `mandrake_brute` | Skin-tone root dots everywhere | Trunk-like body (cf. Elder Hollow), leaf crown, dot or angry face |
| `thunder_ghoul` | Long arms, striped shading | Hunched block, dark-band face, sparks removed except one |
| `gargoyle` | Wing detail, three metal tones | Folded wings as flat plates, dark-band eyes in `G1` |
| `phantom_parade` | Three ghosts with different shapes | Three copies of one dot-face ghost in three element colours, one candle |

### 4.2 Legends, shopkeeper, banner — CUT (the designer draws them)

- `storm_titan`: flat `V1` body with `N0` muscle lines (as Bone Dragon's ribs), dark-band face
  like Ember Colossus, one bolt gripped as the accent; the purple beard and kilt reduce to one
  `N4` block. Target ≤ 7 colours (9 today).
- `iron_juggernaut`: already close to the die-body look. Remove the plate highlights, keep the
  `R1` eye slit as the only accent, make the legs one base block. Target ≤ 7 colours (9 today).
- `shopkeeper_undertaker`: top hat + bone-glyph skull + coat as one trapezoid behind a counter
  drawn as a slab (§4.3); the checker collar goes. Target ≤ 8 colours (10 today).
- `legion_banner`: flat cloth, pole with a bone-glyph skull finial.

### 4.3 UI kit — the die body as the pattern — DONE (as built: ART_SPEC §7, D-A19)

The designer's die body is the only "UI-like" object they have drawn, and the kit should be made
of the same thing. Measured on `die_body.png` (20×20):

- 1 px `N0` outline with **2 px chamfered corners** (the outline starts at x = 2 on the first
  row and x = 1 on the second);
- a **flat face** in one tone, no top highlight row and no side shading;
- a **2 px glint** in the top-left corner, one step lighter;
- a **3-row lip** at the bottom: 1 row of the mid tone, 2 rows of the dark tone;
- inset variant (`die_body_iron`): a 1 px lighter ring inside the outline with dark corner rivets.

Today's kit is the scaffold placeholder: square boxes, 1 px notched corners, a full-width
highlight row on top and a shadow row at the bottom.

| Component | Today | Proposal |
|---|---|---|
| Buttons, normal | Flat box, top highlight row | Slab: chamfered outline, flat face (`F1` / `N4` / `R1`), corner glint, 2-row lip (`F0` / `N2` / `R0`) |
| Buttons, hover | Face one step lighter | Same slab, face one step lighter, lip unchanged |
| Buttons, pressed | Highlight and shadow swapped | The slab sinks: the lip disappears, the face moves down 2 px, text follows (content margin) |
| Buttons, disabled | `N2` box | `N2` slab with an `N1` lip, no glint |
| `panel_dark` | Box with an inner border | Sunken tray: chamfered outline, `N1` floor, 1 dark row under the top edge instead of a lip |
| `panel_card` | Box with a top highlight | Raised slab: `N2` face, `N1` lip; rarity and selection frames use the inset ring |
| `panel_tooltip`, `chip` | Bordered boxes | Small slabs (1-row lip) so they do not eat text rows |
| `slot`, `slot_selected` | Dashed square, yellow square ring | Socket (sunken, chamfered) and the same `G1` ring shape as `die_select` |
| `power_box`, `count_box` | Flat boxes | Slabs in `I1` / `I0` and `R1` / `R0`: they read as two big dice being multiplied |
| `hp_frame`, `hp_fill` | Square frame | Chamfered frame; fill unchanged |
| Stripes, divider | Flat | Unchanged (already flat) |
| `stamp_defeated` | Thin outline letters | Bolder letters, same size and rotation |

Things to settle while building it, by measuring the running scenes rather than by eye:

- **9-slice margins.** A 2 px chamfer plus a 2-row lip fits the current 6 px margins, so the
  theme keeps its numbers; only bottom content margins grow by 1 px. The smallest buttons in
  the game (top-bar icons, `SUMMON 3` / `REROLL 2` counters) decide whether small controls get a
  1-row lip variant.
- **Frames not in the kit.** Shop cards, Codex cells and encounter cards get their coloured
  1 px borders, dashes and pedestals from code or scene rectangles (`item_slot.gd`,
  `codex_cell.gd`, `encounter_card.tscn` among them; batch 5 starts with a full inventory).
  They become 9-slice frames with the chamfer, which adds a few files to the manifest and to
  ART_SPEC §7.
- **Pressed offset.** The press feedback already shifts content 1 px; the slab needs 2 px. The
  press punch wired in `autoload/ui_fx.gd` stays as it is.

No layout rect in ART_SPEC §6 changes. Fonts, text colours and number formatting stay.

### 4.4 Dice extras and small glyphs

- `die_body_wild`: rebuilt on the designer's slab (it is the only body still on the old shape).
- `die_roll`: tumbling frames redrawn from the new body (chamfer and lip visible while turning).
- `die_select` / `die_bound` / `die_shackle`: overlay rings follow the chamfered outline.
- `glyph8_{ice,leaf,wild}`, element pips, `num_1..9`: re-derived from the designer's 12×12
  glyphs, as was done for bone / fire / volt / metal.

### 4.5 Icons and VFX

- `grave_bell`, `death_knell`: one object each on a lip, in the manner of the designer's gear.
- VFX: drop the third tone where a sheet has one; shapes and timing stay (playback depends on
  frame counts).

### 4.6 Logo and the two generator backgrounds

**Logo — "Necrodicer".** The game is renamed (designer decision, §7). The logo keeps its
160×48 canvas and its place on the title screen. It is built from the designer's skull die: the
app icon's face (angry sockets, flat bone face, lip) drawn as a die and used as a letter of the
word or as its emblem, with bone-coloured block letters on a lip. The rename also touches the
project name, the window and page title, the export file name and the how-to text; those go in
the same batch, with a DECISIONS entry.

**`bg_map` — the Night Map backdrop.** Role: sit behind the three encounter cards and the FIGHT
button, on a screen that is mostly text. Today it is a plain fade (`N3` → `N0`). It must stay in
the four darkest neutrals and carry no detail behind the cards; scenery belongs to the edges and
the band under the cards (a road of graves toward the village of `bg_battle`, the same moon as
`bg_title`), so the three screens read as one place. The 480×270 centre is the safe area; the
640×300 canvas only shows on wider windows.

**`shop_decor` — the Crypt Trader's alcove.** Role: the only decoration of the shop, 120×182 in
the right column, anchored to the bottom, with the shopkeeper sprite drawn in front of it and the
shop title above. It must leave the shopkeeper's standing spot and the title area clear and must
not compete with the item cards on its left. Redrawn in the slab language: an arch of stacked
slabs with a lip, a shelf with a few of the designer's own icons (skull, candle, coins) at their
real size, flat tones.

---------------------------------------------------------------------------------------
## 5. Batches

Each batch ends with a review by the designer. A batch does not start before the previous one
is accepted, edited or cut. If the designer edits a proposal, the difference is measured the same
way as §2 and the rules above are corrected before the next batch.

| # | Content | Files | State |
|---|---|---|---|
| 0 | Safety and tooling (§6), ART_SPEC §4.1a and §9.4 | 0 | **Done** |
| 1 | Pilot: 3 units + primary / danger buttons, `panel_card`, `slot` | 12 | Reviewed: **UI accepted, units rejected** |
| 2–4 | Units, legends, shopkeeper, banner | 24 | **Cut** — the designer draws them by hand |
| 5 | UI kit: all buttons, panels, chip, tooltip, slots, Power / Count boxes, HP frame, two new frames, rings drawn in code, theme | 22 written (2 new) | **Done**, in `assets/ui` |
| 6a | VFX | 8 | **Cut** — the proposal (a rebuilt aura ring and flame crown, two-tone particles) was rejected as worse than the hand-placed frames; the recipes were restored unchanged (§7.2) |
| 6b | Dice extras (`die_body_wild`, `die_roll`, select / bound / shackle rings), small glyphs and pips, `grave_bell`, `death_knell` | ~22 | Not started |
| 7a | Logo "Necrodicer" (stacked: NECRO over DICER, the O is the skull die) and the rename (project name, Web zip, doc titles, D-A20) | 1 + text | **Done** |
| 7b | `bg_map`; `shop_decor` | 2 | Not started |
| 8 | Derived art: how-to pages, art sheets | ~6 | After 6 and 7 |

Not redrawn in batch 5, on purpose: `rarity_stripe_*`, `divider`, `hp_fill`, `hp_preview` (already
flat), and `stamp_defeated` (it is lettering; it goes with the logo in batch 7).

---------------------------------------------------------------------------------------
## 6. Process and safety

### 6.1 Designer files cannot be overwritten (built in batch 0)

Before, a hand-edited file was protected only by convention: a plain run kept it, but
`--only <id>` or `--all` replaced it. Now a tool overwrites only what a tool wrote:

- `assets/generated.json` holds, per id, a hash of the pixels a generator last wrote
  (`tools/art_lock.py`). It was seeded with the 104 files of §1 that equal their recipe or are
  untouched scaffold placeholders;
- `pixelgrid.run` and `gen_placeholders.py` refuse every other file, whatever the flag, and print
  `LOCKED`. Checked: `units.py --only fire_imp`, `enemies_dice.py --all` and
  `gen_placeholders.py --only bg_battle` write nothing;
- nothing has to be declared: a file the designer edits stops matching its hash and is locked
  from that moment, including a file with a proposal pending;
- `python tools/art/classify.py` reports the state of every file (`designer` 132, `generator`,
  `pending` = recipe ahead of the file, `no-recipe`), and `--dump <id>` prints a file as a
  palette-key grid for style study.

### 6.2 Proposals live outside the game (built in batch 0)

- `--only <ids> --propose art_source/proposals/<batch>` writes the files under that folder at
  their path below `assets/`. `art_source/` has a `.gdignore`; the game cannot load it.
- `tools\screenshot.cmd <preset> <out.png> 960x540 --art=art_source/proposals/<batch>` runs the
  game with those files loaded over `assets/` for that run only (units, theme style boxes, slots),
  so a proposal is judged on the real screens.
- Approval is the only thing that writes into `assets/`: the same generator command with
  `--only <approved ids>` and no `--propose`.

### 6.3 Method

- Sprites stay hand-placed row grids in `tools/art/*.py` (`pixelgrid`), not primitives.
- The grids can express the style. Checked on the six designer units: removing the exterior
  outline and re-adding it with `pixelgrid.outline` gives Fire Imp back exactly; the others
  differ by 2–7 px, which are the shadow dash under floating units and a few hand-placed `N0`
  pixels (both available as explicit `#` in a grid).
- Each new sprite is iterated in a throwaway preview next to designer units (×10, ×2, ×1) before
  its grid goes into the generator.
- UI: build from ART_SPEC §6 rects, then print rects and overflow from the running scenes at the
  base size and at a wide aspect.

### 6.4 Gates per batch

`python tools/check_data.py`, `python tools/validate_art.py`, `tools\test.cmd`,
`tools\ui_test.cmd`; `godot --headless --import` from PowerShell; the captures listed in §5,
judged at ×1 and with nearest-neighbour zoom. A unit batch also checks idle frame 1 against
frame 0 (only the intended rows move) and the lowest opaque row.

No commit or push without a request, as always.

---------------------------------------------------------------------------------------
## 7. Decisions and open points

Decided by the designer on 2026-11-11:

| # | Question | Decision |
|---|---|---|
| 1 | Units the designer wants to draw | Superseded by row 6: all of them |
| 2 | Pumpkinling vs `mini_leaf` | The unit becomes a leaf with eyes and a mouth (a note for the designer's own repaint) |
| 3 | How far the UI goes | Shapes only; colours stay |
| 4 | `bg_map`, `shop_decor` | Redo both, each for its role in the game (§4.6) |
| 5 | Logo | Redo it; the game is renamed **Necrodicer**; use the designer's skull die |
| 6 | Pilot verdict (same day) | Buttons fit; the generated units do not. Finish the whole UI; the designer draws the units by hand |

### 7.1 UI kit — what changed and how to check it

- 22 files written in `assets/ui` (20 redrawn, `panel_tray` and `frame_select` new); every one is
  generator-owned, so the designer can repaint any of them and it locks itself (§6.1).
- Theme: pressed buttons sink 2 px; `TrayPanel` and `CurrentBorder` are 9-slices instead of flat
  rectangles. Code: `Art.draw_ring` / `Art.draw_box` follow the chamfer (shop cards, slots, Codex
  cells, face tiles); `hp_bar.gd` redraws the frame's cut corners over the fill.
- No layout rect changed; every button state has the same minimum size (test
  `project.test_button_states_keep_their_size`).
- Captures: any preset shows the kit; `title_hover` and `title_press` show the button states;
  `shop`, `shop_tip`, `codex_trinkets`, `night_map`, `summon_relics`, `result` cover cards, trays,
  tooltip, chips, the selection frame, the HUD boxes and the HP bar.

### 7.2 What the two rejected proposals have in common

The generated units (pilot) and the VFX (batch 6a) were both rejected; the UI kit and the logo
were accepted. The difference is not the subject but the method:

- **Accepted:** geometric art (boxes, block letters) built from a construction the designer had
  drawn themselves (the die body, the skull die). The reference existed; the work was applying it.
- **Rejected:** organic art (characters, fire) for which the designer had drawn no sample of that
  kind, produced from written rules. For the VFX the rules of §2.1 (fewer tones, chunky shapes,
  no loose pixels) were measured on solid objects and do not hold for fire and glow, which need
  thin irregular tips, loose sparks and a soft third tone; and hand-placed frames were replaced
  by a ring plus triangles, which is the "primitives" failure the art skill warns about.

Rule kept from this: redo by generator only where the designer has drawn the construction to
copy; characters and effects wait for a designer sample or stay as they are.

