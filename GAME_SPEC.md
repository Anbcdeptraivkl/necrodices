# RATTLE & ROLL — Game Loop Spec v1.0

> Working title. Halloween 2026 dice-summoning roguelike (Balatro-style scoring, no poker).
> Companion document: `ART_SPEC.md` (resolution, palette, sprites, UI layout, asset manifest).
> Audience: human developers **and** LLM coding agents. Every rule here is normative unless marked *(tunable)* or *(stretch)*.

---

## 0. How to use this document (for coding agents)

1. Read §1 (locked decisions) and §2 (glossary) first. Never rename IDs defined in §6.
2. Build in the milestone order of §13. Each milestone has acceptance criteria; do not start the next milestone until the current one passes.
3. All game content lives in JSON under `res://data/` (§9). Code must not hard-code unit stats, relic numbers, HP values or prices.
4. Game logic (`res://core/`) is pure GDScript (`RefCounted`, no `Node`, no scene access) so it can be unit-tested headless. Presentation reads state and plays back a **ScoreTrace** (§5.4); it never computes rules itself.
5. Art may not exist yet. Run `tools/gen_placeholders.py` (see ART_SPEC §9) to generate every PNG in the manifest with correct names and sizes, so the game is always playable.
6. When the spec is ambiguous, choose the option closest to Balatro's behaviour and log the decision in `DECISIONS.md`.

---

## 1. Locked decisions

| ID | Decision | Value |
|---|---|---|
| D-01 | Engine | Godot 4.3+ (GDScript). 2D only. |
| D-02 | Primary target | Web (HTML5) export, portrait. Secondary: Android/iOS (same build). |
| D-03 | Virtual resolution | 270 × 480 portrait, integer scaling, nearest filtering (see ART_SPEC §2). |
| D-04 | Dice | 6 faces, faces are **elements**, not numbers. Start with **4** dice. |
| D-05 | Elements | `BONE, FIRE, ICE, LEAF, VOLT, METAL` (canonical order, index 0–5). |
| D-06 | Group size | A group = 2 or 3 dice. Every 2-dice combination is valid (fallback unit). 3-dice groups are valid only for the 4 T3 recipes. |
| D-07 | Per encounter | 3 Summons, 2 Rerolls (shared across the encounter). |
| D-08 | Reroll | Player chooses which dice (and how many) to reroll. |
| D-09 | Leftover dice | Dice not bound into a group when Summon is pressed are wasted (no compensation). |
| D-10 | Scoring | Balatro order: groups resolve in summon order; per-group relics left→right; then final relics left→right. `Damage = floor(Power × Count)`. |
| D-11 | Additive vs multiplicative | Effects are `+Power`, `+Count`, `×Count`, `×Power` (rare). Order matters. |
| D-12 | Win/Lose | One combat per encounter. `Damage ≥ Enemy HP` → win. Otherwise the run is lost. |
| D-13 | Run length | 8 Nights × 3 encounters (Mob, Champion, Boss) = 24 encounters. |
| D-14 | Bosses | 4 boss types with special rules + Night 8 "Enraged" variant (2 rules). |
| D-15 | Determinism | Seeded run; all randomness from named RNG streams (§10). Scoring itself has no randomness. |

---

## 2. Glossary

| Term | Meaning |
|---|---|
| **Die** | Object with 6 **Faces**. Each face has an element and optional **Face Modifier**. |
| **Roll** | Randomly sets each die's top face (uniform over its 6 faces). |
| **Reroll** | Re-roll only the selected dice. Consumes 1 Reroll regardless of how many dice are selected. |
| **Bind** | Player selects 2–3 rolled dice and binds them into a **Pending Group** if they form a valid recipe. |
| **Summon (turn)** | Commits all pending groups to the **Army**. Consumes 1 Summon. Unbound dice are wasted. |
| **Group** | One summoned unit stack: `{unit_id, dice_faces[], summon_index}`. |
| **Unit** | Monster type (19 types, §6.2). Has base **Power**, base **Count**, growth per level, tier. |
| **Power (P)** | Chips equivalent. Running total during scoring. |
| **Count (C)** | Mult equivalent, shown as number of monsters. Running total during scoring. Always an integer. |
| **Essence** | Element points on the board: each die in each group adds 1 essence of its (resolved) element. Used by relic conditions. |
| **Army** | Ordered list of groups summoned this encounter. |
| **Combat** | Scoring + playback after the last Summon (or **Attack Now**). |
| **Night** | Equivalent of a Balatro Ante. 3 encounters: Mob → Champion → Boss. |
| **Relic** | Joker equivalent. Max 5 equipped (order matters, drag to reorder). |
| **Consumable** | Tome (level units), Sigil (change face element), Ink (add face modifier), Spare Die. Max 2 held. |
| **Equipment** | Voucher equivalent. Permanent run upgrade. One offered per Night. |
| **$** | Money ("Soul Coins"). |

---

## 3. Core loop

```
TITLE → NEW RUN (seed) → NIGHT MAP
  └─ ENCOUNTER (Mob | Champion | Boss)
       ├─ SUMMON TURN × up to 3:
       │     ROLL all dice → [select dice → REROLL]* → [select 2–3 dice → BIND]* → SUMMON
       │     (ATTACK NOW available once Army ≥ 1 group)
       └─ COMBAT: score → playback → WIN | LOSE
            WIN  → CASH-OUT → SHOP → next encounter (after Boss: next Night)
            LOSE → GAME OVER
  Night 8 Boss defeated → VICTORY
```

---

## 4. Rules

### 4.1 Run setup
- Seed: 8-char uppercase alphanumeric string (random or player-entered *(stretch)*).
- Start: `$4`, 4 Standard Dice, 0 relics, 0 consumables, all unit levels = 1, relic slots 5, consumable slots 2.
- Standard Die faces: `[BONE, FIRE, ICE, LEAF, VOLT, METAL]`, no modifiers.
- Night 1 begins. Enemy picks and boss picks are generated per Night when the Night starts (§7.2).

### 4.2 Encounter setup
- `summons_left = 3 + equipment_bonus_summons` (Inquisitor: −1, min 1).
- `rerolls_left = 2 + equipment_bonus_rerolls`.
- `army = []`, `pending = []`.
- Show enemy, HP, boss rule (if any). Autosave (§12).
- Start Summon Turn 1.

### 4.3 Summon turn state machine

```
TURN_START → ROLLING (anim) → AWAIT_INPUT ⇄ (REROLLING) → COMMIT → TURN_END
```

1. **TURN_START**: all dice return to tray, unbound, unselected. Roll all dice (Roll Stream).
   - Bell Ringer: after every roll/reroll, 1 random non-bound die becomes **Shackled** for the rest of this turn (Boss Stream).
2. **AWAIT_INPUT** — the player can, in any order:
   - **Tap die** → toggle `selected` (shackled dice cannot be selected; bound dice cannot be selected).
   - **REROLL** button: enabled if `rerolls_left > 0` and `selected.size ≥ 1`. Rerolls selected dice, `rerolls_left -= 1`, clears selection. Bell Ringer re-applies shackle (previous shackle is released first).
   - **BIND** button: enabled if `selected.size ∈ {2,3}` and `resolve_recipe(selected)` is valid (§5.1). Creates a Pending Group in tray order; those dice become `bound`. Clears selection.
   - **Tap pending group chip** → unbind (dice return to unbound).
   - **Use consumable** (§4.8) — allowed during AWAIT_INPUT.
   - **SUMMON** button: always enabled during AWAIT_INPUT. If `pending` is empty, show confirm "Summon nothing? This turn will be wasted." Then COMMIT.
   - **ATTACK NOW** button: enabled if `army.size + pending.size ≥ 1`. Commits pending groups as a normal Summon (consumes 1 Summon) and then goes straight to Combat. Remaining summons are counted as unused.
3. **COMMIT**: append pending groups to army in pending order with `summon_index`. Fire `SUMMON` events (relic counters, GOLD face money). `summons_left -= 1`. Unbound dice are discarded for this turn.
4. **TURN_END**: if `summons_left == 0` → Combat. Else → TURN_START.

**Projected damage** is always visible during AWAIT_INPUT: run the scorer on `army + pending` (pending appended as if summoned now; SUMMON-event counters are not incremented in previews).

### 4.4 Combat
1. `result = Scorer.score(army, run_state, encounter_state)` → `{damage, power, count, trace}`.
2. Presentation plays back `trace` (§11).
3. `win = result.damage >= enemy.hp`.
4. Win → enemy defeat anim → Cash-out. Lose → enemy survives anim → Game Over.

### 4.5 Cash-out (on win)
| Line | Amount |
|---|---|
| Enemy reward | Mob `$3`, Champion `$4`, Boss `$5` *(tunable)* |
| Unused summons | `$1` each |
| Interest | `$1` per `$5` held **before** cash-out, max `$5` *(tunable)* |
| FIGHT_END relics | per relic (e.g. Grave Robber `+$2`) |

After a Boss win: `bosses_defeated += 1`, Night advances, equipment slot restocks.

### 4.6 Shop
Opens after every won encounter.
- **3 item slots**: each rolls a category by weight, then an item (Shop Stream):

  | Category | Weight |
  |---|---|
  | Relic | 40 |
  | Tome | 25 |
  | Sigil | 20 |
  | Ink | 10 |
  | Spare Die | 5 |

  Relic rarity weights: Common 70 / Uncommon 25 / Rare 5. A relic already owned or already in the shop is not offered (re-roll the pick).
- **1 equipment slot**: one equipment per Night (restocks after Boss win and at run start). Respect prerequisites. If bought, slot shows "Sold out" until next Night.
- **Reroll shop**: `$4`, +`$1` per reroll within the same shop visit (Haggler's Lantern: −`$2`, min `$0`). Rerolls the 3 item slots only.
- **Buy**: requires money ≥ price and a free slot (relic slots / consumable slots). Consumables can also be **Buy & Use** immediately (no slot needed).
- **Sell**: relic → `floor(price / 2)`; consumable → `$1`.
- **Continue** → next encounter screen (Night Map).

### 4.7 Unit levels (Tomes)
- Every unit starts at level 1.
- `Tome of <E>`: +1 level to **every unit whose recipe contains element E** (once per unit, even if E appears twice), and +1 level to WISP.
- Stats at level L: `P = base_p + grow_p × (L−1)`, `C = base_c + grow_c × (L−1)`.

### 4.8 Consumables usage
- Usable in SHOP and during ENCOUNTER AWAIT_INPUT.
- **Tome**: no target. Apply immediately.
- **Sigil of E**: target up to 2 faces (any dice, via Dice Inspector overlay). Each target face's element → E (modifier kept).
- **Ink**: target exactly 1 face. Sets the face modifier (replaces existing). `INK_WILD` sets modifier WILD.
- **Spare Die**: adds 1 Standard Die (max 8 dice total). If used mid-encounter, the new die joins from the next TURN_START.
- If a modified face is currently showing on a rolled die, the tray updates immediately.

### 4.9 Face modifiers
One modifier per face, max.

| ID | Effect | When |
|---|---|---|
| `SHARP` | `+10 Power` | During the group's resolution |
| `SWARM` | `+2 Count` | During the group's resolution |
| `HEX` | `×1.5 Count` | During the group's resolution |
| `GOLD` | `+$2` | At COMMIT (summon) |
| `WILD` | Face element = any element | At recipe resolution (§5.2) |

---

## 5. Algorithms

### 5.1 Recipe resolution

```
func resolve_recipe(faces: Array[Face]) -> UnitId | null:
    # faces.size() is 2 or 3; WILD faces resolved first (§5.2)
    var elems = faces.map(f -> f.resolved_element)
    elems.sort_by(canonical_index)        # BONE<FIRE<ICE<LEAF<VOLT<METAL
    var key = "+".join(elems)              # e.g. "BONE+METAL", "BONE+FIRE+LEAF"
    if RECIPES.has(key): return RECIPES[key]
    if faces.size() == 2: return "WISP"    # fallback, every pair is valid
    return null                            # invalid triple
```

`RECIPES` is built from `units.json` at load. Startup assertion: 6 same-pairs + 8 hybrid pairs + 4 triples present, all 21 pair keys resolve to non-null.

### 5.2 WILD resolution
- For each WILD face in the candidate group, try all 6 elements (cartesian product, max 6³ = 216 combos).
- Pick the assignment whose resulting unit maximises `(tier_rank, P_at_level × C_at_level)`; tie → lower unit table index. `tier_rank`: T3=3, T2=2, T1=1, WISP=0.
- Store the resolved element on the group (essence uses it).
- *(stretch)* Tap a WILD die inside a pending group to cycle through valid alternatives.

### 5.3 Scorer

```
func score(army, run, enc) -> ScoreResult:
    var P := 0.0, C := 0.0, trace := []
    var essence := count_essence(army)           # whole army, before resolution
    var relics := run.relics.duplicate()
    if enc.has_rule("WITCH_HUNTER") and relics.size() > 0:
        relics[0].disabled_this_encounter = true # leftmost
    var ctx := Ctx.new(essence, army.size(), run.money, enc.rerolls_left,
                       enc.summons_left, run.bosses_defeated)

    for g in army:                                # summon order
        var u := UNITS[g.unit_id]; var L := run.levels[g.unit_id]
        var bp := u.base_p + u.grow_p * (L - 1)
        var bc := u.base_c + u.grow_c * (L - 1)
        if enc.has_rule("EXORCIST") and g.has_element("BONE"):
            bp = floor(bp * 0.5)
        P += bp; C += bc;            trace.push(GroupBase(g, bp, bc, P, C))
        for f in g.faces:                         # tray order
            match f.modifier:
                SHARP: P += 10;                   trace.push(FaceMod(...))
                SWARM: C += 2;                    trace.push(FaceMod(...))
                HEX:   C = round_half_up(C * 1.5);trace.push(FaceMod(...))
        for r in relics:                          # left → right
            if r.enabled and r.trigger == GROUP and r.cond(g, ctx):
                apply(r.effects, ctx);            trace.push(RelicFx(r, ...))

    for r in relics:
        if r.enabled and r.trigger == FINAL and r.cond(null, ctx):
            apply(r.effects, ctx);                trace.push(RelicFx(r, ...))

    var damage := floor(P * C)
    trace.push(Total(P, C, damage))
    return ScoreResult(damage, P, C, trace)
```

Rules:
- All `×` operations round half up to an integer immediately (`P` and `C` are always integers in value).
- Use `float` (64-bit) for P, C, damage. Display formatting in ART_SPEC §8.
- `apply` modifies the running `P`/`C` held in `ctx`.

### 5.4 ScoreTrace (contract between logic and presentation)

```
TraceStep {
  kind: "group_base" | "face_mod" | "relic" | "boss" | "total",
  group_index: int (or -1),
  source_id: String,            # unit / modifier / relic / rule id
  op: "add_p"|"add_c"|"mul_p"|"mul_c"|"none",
  value: float,
  p_after: float, c_after: float,
  label: String                 # e.g. "+2 Count", "×1.5 Count"
}
```
Presentation must render the trace exactly; it never re-evaluates conditions.

### 5.5 Worked example (must be a unit-test fixture)

Setup: levels all 1, no boss. Army in order:
1. `SKELETON_WARRIOR` (faces: BONE+SHARP, BONE)
2. `STEAM_SLIME` (FIRE, ICE)
3. `LICH` (BONE, BONE, BONE)

Relics left→right: `RATTLE_DRUM`, `CROWN_OF_THE_LICH`, `GRAVEDIGGER_LAMP`, `BONE_PILE`.
Essence: BONE 5, FIRE 1, ICE 1.

| Step | P | C |
|---|---|---|
| G1 base +10 / +2 | 10 | 2 |
| G1 SHARP +10 P | 20 | 2 |
| G1 Rattle Drum +2 C | 20 | 4 |
| G2 base +10 / +4 | 30 | 8 |
| G3 base +40 / +8 | 70 | 16 |
| G3 Rattle Drum +2 C | 70 | 18 |
| G3 Crown of the Lich ×1.5 C | 70 | 27 |
| Final: Gravedigger's Lamp +4 C | 70 | 31 |
| Final: Bone Pile +5 C (BONE essence 5) | 70 | 36 |
| **Damage** | | **2520** |

Order-sensitivity fixture: swap relics 1 and 2 (`CROWN_OF_THE_LICH`, `RATTLE_DRUM`, …) → G3: 16 ×1.5 = 24, +2 = 26 → final 26+4+5 = 35 → **Damage 2450**.

Boss fixture: same army + relics, rule `EXORCIST` → G1 base P 5, G3 base P 20 → P = 5+10+10+20 = 45, C unchanged 36 → **Damage 1620**.

### 5.6 Baseline statistical regression (recipe + scorer sanity)
Bot: 4 Standard Dice, 3 summons, 0 rerolls, no relics, levels 1. Each turn, enumerate every set of disjoint valid groups from the roll and pick the one maximising cumulative `P × C`. 20,000 trials.

| Metric | Expected (±5%) |
|---|---|
| Mean damage | ~1,590 |
| Median | ~1,530 |
| p10 / p90 | ~930 / ~2,350 |
| Mean groups per encounter | ~5.2 |

Reference implementation: Appendix A.

---

## 6. Content tables

### 6.1 Elements

| Index | ID | Name | Glyph (ART_SPEC) |
|---|---|---|---|
| 0 | BONE | Bone | crossed bones |
| 1 | FIRE | Fire | flame |
| 2 | ICE | Ice | snowflake |
| 3 | LEAF | Leaf | leaf |
| 4 | VOLT | Volt | lightning bolt |
| 5 | METAL | Metal | hex nut |

### 6.2 Units (19)

| # | ID | Name | Tier | Recipe key | Base P | Base C | +P/lvl | +C/lvl |
|---|---|---|---|---|---|---|---|---|
| 1 | SKELETON_WARRIOR | Skeleton Warrior | T1 | BONE+BONE | 10 | 2 | 8 | 1 |
| 2 | FIRE_IMP | Fire Imp | T1 | FIRE+FIRE | 6 | 3 | 6 | 1 |
| 3 | FROST_BAT | Frost Bat | T1 | ICE+ICE | 14 | 1 | 10 | 1 |
| 4 | PUMPKINLING | Pumpkinling | T1 | LEAF+LEAF | 8 | 2 | 8 | 1 |
| 5 | VOLT_GHOST | Volt Ghost | T1 | VOLT+VOLT | 12 | 2 | 8 | 1 |
| 6 | HAUNTED_ARMOR | Haunted Armor | T1 | METAL+METAL | 18 | 1 | 12 | 1 |
| 7 | FLAME_SKULL | Flame Skull | T2 | BONE+FIRE | 15 | 3 | 10 | 1 |
| 8 | SCARECROW | Scarecrow | T2 | BONE+LEAF | 16 | 3 | 10 | 1 |
| 9 | SHIELD_SKELETON | Shield Skeleton | T2 | BONE+METAL | 20 | 2 | 10 | 1 |
| 10 | STEAM_SLIME | Steam Slime | T2 | FIRE+ICE | 10 | 4 | 8 | 1 |
| 11 | JACK_O_LANTERN | Jack-o'-Lantern | T2 | FIRE+LEAF | 12 | 4 | 8 | 1 |
| 12 | BOG_WITCH | Bog Witch | T2 | ICE+LEAF | 12 | 3 | 10 | 1 |
| 13 | STORM_BANSHEE | Storm Banshee | T2 | ICE+VOLT | 22 | 2 | 12 | 1 |
| 14 | TESLA_SPIDER | Tesla Spider | T2 | VOLT+METAL | 14 | 3 | 10 | 1 |
| 15 | WISP | Wisp | WISP | *(fallback, 7 keys)* | 5 | 1 | 3 | 1 |
| 16 | LICH | Lich | T3 | BONE+BONE+BONE | 40 | 8 | 20 | 2 |
| 17 | HEADLESS_HORSEMAN | Headless Horseman | T3 | BONE+FIRE+LEAF | 60 | 6 | 20 | 2 |
| 18 | STITCHED_GOLEM | Stitched Golem | T3 | BONE+VOLT+METAL | 80 | 4 | 25 | 2 |
| 19 | WITCH_QUEEN | Witch Queen | T3 | ICE+LEAF+VOLT | 45 | 7 | 20 | 2 |

*(All stat numbers tunable.)*

### 6.3 Full pair recipe matrix (21 combinations)

|  | BONE | FIRE | ICE | LEAF | VOLT | METAL |
|---|---|---|---|---|---|---|
| **BONE** | Skeleton Warrior | Flame Skull | *Wisp* | Scarecrow | *Wisp* | Shield Skeleton |
| **FIRE** | | Fire Imp | Steam Slime | Jack-o'-Lantern | *Wisp* | *Wisp* |
| **ICE** | | | Frost Bat | Bog Witch | Storm Banshee | *Wisp* |
| **LEAF** | | | | Pumpkinling | *Wisp* | *Wisp* |
| **VOLT** | | | | | Volt Ghost | Tesla Spider |
| **METAL** | | | | | | Haunted Armor |

Wisp keys (7): `BONE+ICE, BONE+VOLT, FIRE+VOLT, FIRE+METAL, ICE+METAL, LEAF+VOLT, LEAF+METAL`.
Wisp essence = 1 of each of its two elements. Wisp is tinted with both element colours (ART_SPEC §4.3).

### 6.4 Triple recipes
Valid (4): `BONE+BONE+BONE` → Lich, `BONE+FIRE+LEAF` → Headless Horseman, `BONE+VOLT+METAL` → Stitched Golem, `ICE+LEAF+VOLT` → Witch Queen.
All other 52 triple keys are **invalid** (BIND disabled, tooltip "No recipe for these 3").

Raw probability per encounter turn is low by design; Sigils/WILD make triples a build goal.

### 6.5 Relics (25)

Triggers: `GROUP` (per group, during resolution), `FINAL` (after all groups), `SUMMON` (at commit, per group; used for counters/economy), `FIGHT_END` (after a won combat, at cash-out).

| ID | Name | Rarity | $ | Trigger | Condition | Effect |
|---|---|---|---|---|---|---|
| RATTLE_DRUM | Rattle Drum | Common | 4 | GROUP | group has BONE | +2 Count |
| EMBER_JAR | Ember Jar | Common | 4 | GROUP | group has FIRE | +12 Power |
| FROST_LANTERN | Frost Lantern | Common | 4 | GROUP | group has ICE | +15 Power |
| MOSS_CHARM | Moss Charm | Common | 4 | GROUP | group has LEAF | +2 Count |
| LIGHTNING_ROD | Lightning Rod | Common | 4 | GROUP | group has VOLT | +8 Power, +1 Count |
| IRON_NAIL | Iron Nail | Common | 4 | GROUP | group has METAL | +15 Power |
| GRAVEDIGGER_LAMP | Gravedigger's Lamp | Common | 4 | FINAL | always | +4 Count |
| WISP_JAR | Wisp Jar | Common | 4 | GROUP | unit is WISP | +3 Count |
| GRAVE_ROBBER | Grave Robber | Common | 4 | FIGHT_END | always | +$2 |
| BONE_SAW | Bone Saw | Common | 4 | GROUP | tier T1 | +10 Power |
| DEEP_FREEZE | Deep Freeze | Uncommon | 6 | FINAL | ICE essence ≥ 3 | ×1.5 Count |
| COLD_HEARTH | Cold Hearth | Uncommon | 6 | FINAL | FIRE essence = 0 | ×2 Count |
| BONE_PILE | Bone Pile | Uncommon | 6 | FINAL | always | +1 Count per BONE essence |
| GRAND_PROCESSION | Grand Procession | Uncommon | 6 | FINAL | always | +8 Power per group in army |
| THRIFTY_GHOST | Thrifty Ghost | Uncommon | 6 | FINAL | always | +4 Count per unused reroll |
| HYBRID_VIGOR | Hybrid Vigor | Uncommon | 6 | GROUP | tier T2 | +3 Count |
| COPYCAT_COFFIN | Copycat Coffin | Uncommon | 6 | GROUP | same unit already resolved earlier this combat | +4 Count |
| OVERGROWTH | Overgrowth | Uncommon | 6 | SUMMON + FINAL | SUMMON: group has LEAF → counter +1 (permanent) | FINAL: +1 Count per counter |
| SPIRIT_BOARD | Spirit Board | Uncommon | 6 | FINAL | ≥ 5 distinct elements with essence > 0 | ×2 Count |
| PIGGY_COFFIN | Piggy Coffin | Uncommon | 6 | FINAL | always | +2 Power per $1 held |
| TACTICIAN_SKULL | Tactician's Skull | Rare | 8 | GROUP | first group of the army | ×3 Power |
| CROWN_OF_THE_LICH | Crown of the Lich | Rare | 8 | GROUP | tier T3 | ×1.5 Count |
| FULL_MOON | Full Moon | Rare | 8 | FINAL | army has ≥ 7 groups | ×2 Count |
| BLACK_GRIMOIRE | Black Grimoire | Rare | 8 | FINAL | always | ×(1 + 0.25 × bosses defeated) Count |
| ELEMENTAL_CONVERGENCE | Elemental Convergence | Rare | 8 | FINAL | all 6 elements have essence > 0 | ×3 Count |

Notes:
- Black Grimoire at 0 bosses = ×1 → still emits a trace step with label "×1 Count" (shows it is "charging").
- Disabled relics (Witch Hunter) render greyed and are skipped entirely.

### 6.6 Consumables (18)

| ID | Name | Kind | $ | Target | Effect |
|---|---|---|---|---|---|
| TOME_BONE | Tome of Bone | TOME | 3 | – | +1 level: units with BONE, and WISP |
| TOME_FIRE | Tome of Fire | TOME | 3 | – | +1 level: units with FIRE, and WISP |
| TOME_ICE | Tome of Ice | TOME | 3 | – | +1 level: units with ICE, and WISP |
| TOME_LEAF | Tome of Leaf | TOME | 3 | – | +1 level: units with LEAF, and WISP |
| TOME_VOLT | Tome of Volt | TOME | 3 | – | +1 level: units with VOLT, and WISP |
| TOME_METAL | Tome of Metal | TOME | 3 | – | +1 level: units with METAL, and WISP |
| SIGIL_BONE | Sigil of Bone | SIGIL | 3 | ≤2 faces | faces → BONE |
| SIGIL_FIRE | Sigil of Fire | SIGIL | 3 | ≤2 faces | faces → FIRE |
| SIGIL_ICE | Sigil of Ice | SIGIL | 3 | ≤2 faces | faces → ICE |
| SIGIL_LEAF | Sigil of Leaf | SIGIL | 3 | ≤2 faces | faces → LEAF |
| SIGIL_VOLT | Sigil of Volt | SIGIL | 3 | ≤2 faces | faces → VOLT |
| SIGIL_METAL | Sigil of Metal | SIGIL | 3 | ≤2 faces | faces → METAL |
| INK_WILD | Wild Ink | INK | 4 | 1 face | modifier WILD |
| INK_SHARP | Whetstone | INK | 4 | 1 face | modifier SHARP |
| INK_SWARM | Swarm Seed | INK | 4 | 1 face | modifier SWARM |
| INK_HEX | Hex Doll | INK | 4 | 1 face | modifier HEX |
| INK_GOLD | Gilded Leaf | INK | 4 | 1 face | modifier GOLD |
| SPARE_DIE | Spare Bone Die | DIE | 5 | – | +1 Standard Die (max 8) |

### 6.7 Equipment (8) — `$10` each *(tunable)*

| ID | Name | Requires | Effect |
|---|---|---|---|
| BONE_POUCH | Bone Pouch | – | +1 Standard Die |
| BONE_SATCHEL | Bone Satchel | BONE_POUCH | +1 Standard Die |
| GRAVE_BELL | Grave Bell | – | +1 Summon per encounter |
| LOADED_CUP | Loaded Cup | – | +1 Reroll per encounter |
| SECOND_CUP | Second Cup | LOADED_CUP | +1 Reroll per encounter |
| RELIQUARY | Reliquary | – | +1 Relic slot |
| POCKET_CRYPT | Pocket Crypt | – | +1 Consumable slot |
| HAGGLER_LANTERN | Haggler's Lantern | – | Shop rerolls −$2 |

### 6.8 Enemies

| ID | Name | Role | Pool |
|---|---|---|---|
| MOB_TORCH_VILLAGER | Torch Villager | Mob | Mob |
| MOB_PITCHFORK_FARMER | Pitchfork Farmer | Mob | Mob |
| MOB_LANTERN_WATCHMAN | Lantern Watchman | Mob | Mob |
| CHAMP_GUARD_CAPTAIN | Guard Captain | Champion | Champion |
| CHAMP_MONSTER_HUNTER | Monster Hunter | Champion | Champion |
| BOSS_EXORCIST | The Exorcist | Boss | Boss |
| BOSS_WITCH_HUNTER | The Witch Hunter | Boss | Boss |
| BOSS_BELL_RINGER | The Bell Ringer | Boss | Boss |
| BOSS_INQUISITOR | The Inquisitor | Boss | Boss |

Theme: on Halloween night the monsters strike back at the village's monster hunters.

### 6.9 Boss rules

| Rule ID | Boss | Rule text (UI) | HP mult |
|---|---|---|---|
| EXORCIST | The Exorcist | "Holy Water: BONE groups add only half their base Power." | ×2 |
| WITCH_HUNTER | The Witch Hunter | "Confiscation: your leftmost relic is disabled." | ×2 |
| BELL_RINGER | The Bell Ringer | "Toll: after every roll, 1 random die is shackled." | ×2 |
| INQUISITOR | The Inquisitor | "Interrogation: −1 Summon this fight." | ×1.5 |
| ENRAGED | Night 8 boss | "Enraged: two rules at once." Pick 2 distinct rules from the 4 above (Boss Stream). Sprite = random boss, red palette + aura. | ×2 |

Boss selection: Nights 1–7 pick from the 4 bosses, never the same boss two Nights in a row; Night 1 picks only EXORCIST or BELL_RINGER.

### 6.10 HP curve *(tunable)*

| Night | Mob (×1) | Champion (×1.5) | Boss (×2) |
|---|---|---|---|
| 1 | 600 | 900 | 1,200 |
| 2 | 1,500 | 2,250 | 3,000 |
| 3 | 3,500 | 5,250 | 7,000 |
| 4 | 8,000 | 12,000 | 16,000 |
| 5 | 16,000 | 24,000 | 32,000 |
| 6 | 30,000 | 45,000 | 60,000 |
| 7 | 55,000 | 82,500 | 110,000 |
| 8 | 90,000 | 135,000 | 180,000 |

Inquisitor uses ×1.5 instead of ×2. Store only the Night base and multipliers in data.

Rationale: baseline untouched army ≈ 1,590 mean (§5.6). Upgrades scale roughly: +1 die ≈ ×1.8, +2 dice ≈ ×3, +1 summon ≈ ×1.8, 6 dice + 4 summons ≈ ×5.3; Tomes and ×Count relics must provide the remaining ×20–30 for Night 8.

### 6.11 Economy constants *(tunable)*

| Key | Value |
|---|---|
| start_money | 4 |
| reward_mob / champion / boss | 3 / 4 / 5 |
| unused_summon_bonus | 1 |
| interest_per | 5 |
| interest_cap | 5 |
| shop_reroll_base / step | 4 / 1 |
| relic_slots / consumable_slots | 5 / 2 |
| max_dice | 8 |
| base_summons / base_rerolls | 3 / 2 |

---

## 7. Run structure details

### 7.1 Night Map screen
Shows the 3 encounter cards of the current Night: enemy portrait, name, HP, reward, and (Boss) rule text. Completed cards are stamped "DEFEATED". Single button: **FIGHT** (next encounter). No skipping in v1.

### 7.2 Night generation (on Night start)
- Mob: random from Mob pool (Enemy Stream).
- Champion: random from Champion pool.
- Boss: per §6.9.
- Equipment offer: random from eligible equipment not owned (Shop Stream). If none eligible, slot empty.

### 7.3 End states
- **Game Over**: show Night reached, encounter, best damage this run, most-summoned unit, seed, buttons [New Run] [Title].
- **Victory** (Night 8 boss defeated): same stats + "The village falls silent." Buttons [New Run] [Title]. *(stretch: Endless mode)*

---

## 8. Screens & flows

All layouts, sizes and coordinates: ART_SPEC §6.

| Screen | Purpose | Key actions |
|---|---|---|
| Boot | Load data, validate content (assertions §5.1), load settings | auto → Title |
| Title | Logo, menu | Continue (if save), New Run, How to Play, Settings |
| Night Map | Show Night's 3 encounters | Fight, open Run Info, Settings |
| Encounter | Summon turns + combat | Select die, Reroll, Bind, Unbind, Summon, Attack Now, use consumable, inspect relic/die (long-press or tap info) |
| Dice Inspector (overlay) | View all dice faces; target faces for Sigil/Ink | Select faces, Confirm, Cancel |
| Cash-out (overlay) | Money breakdown | Continue → Shop |
| Shop | Buy/sell/reroll | Buy, Buy & Use, Sell, Reroll, Continue |
| Run Info (overlay) | Unit levels table, recipe matrix (§6.3), current dice | Close |
| Game Over / Victory | Run summary | New Run, Title |
| Settings (overlay) | See §12.2 | Close |
| How to Play (overlay) | 4 pages | Next/Prev/Close |

**Relic reordering**: drag relic slots horizontally on Encounter and Shop screens (not during combat playback).

**Tooltips**: tap (mobile) / hover (web) on relic, consumable, unit chip, enemy rule, die → tooltip panel with name + text. Must be readable without hover on touch.

**Run Info recipe matrix** is mandatory: players need to learn recipes. Discovered recipes shown with sprite; undiscovered with "?" but element pair still shown *(discovery tracking is stretch; v1 may show all)*.

---

## 9. Data files (`res://data/`)

| File | Content |
|---|---|
| `elements.json` | §6.1 |
| `units.json` | §6.2 incl. `recipe: ["BONE","METAL"]`, `tier`, stats; WISP has `"fallback": true` |
| `relics.json` | §6.5 in DSL below |
| `consumables.json` | §6.6 |
| `equipment.json` | §6.7 |
| `enemies.json` | §6.8 + boss rule id |
| `curve.json` | Night bases + multipliers §6.10 |
| `economy.json` | §6.11 |
| `strings_en.json` | All UI strings (no literal UI text in code) |

### 9.1 Relic DSL

```json
{
  "id": "BONE_PILE", "name": "Bone Pile", "rarity": "UNCOMMON", "price": 6,
  "trigger": "FINAL",
  "cond": { "type": "always" },
  "effects": [ { "op": "add_count", "value": { "base": 0, "per": "essence:BONE", "step": 1 } } ],
  "text": "+1 Count per BONE essence"
}
```

- `value`: number, or `{ "base": n, "per": <source>, "step": n }` → `base + step × source`.
- Sources: `essence:<E>`, `money`, `rerolls_left`, `summons_left`, `groups`, `bosses_defeated`, `counter` (relic's own counter).
- Ops: `add_power`, `add_count`, `mul_power`, `mul_count`, `add_money`.
- Conditions: `always`, `group_has_element{element}`, `group_tier{tier}`, `group_unit{unit}`, `group_is_first`, `group_unit_repeated`, `essence_gte{element,n}`, `essence_eq{element,n}`, `distinct_elements_gte{n}`, `all_elements_present`, `groups_gte{n}`.
- Counter (optional): `"counter": { "on": "SUMMON", "cond": {...}, "inc": 1 }` — persists for the run, stored on the relic instance, sold relic loses it.
- A relic can have multiple trigger blocks: use `"blocks": [ {trigger, cond, effects}, ... ]` (Overgrowth). Simple relics may use the flat form.

### 9.2 Example rows

```json
{ "id": "OVERGROWTH", "name": "Overgrowth", "rarity": "UNCOMMON", "price": 6,
  "counter": { "on": "SUMMON", "cond": { "type": "group_has_element", "element": "LEAF" }, "inc": 1 },
  "blocks": [ { "trigger": "FINAL", "cond": { "type": "always" },
                "effects": [ { "op": "add_count", "value": { "base": 0, "per": "counter", "step": 1 } } ] } ],
  "text": "Gains +1 Count each time you summon a LEAF group (currently +{counter})" }

{ "id": "BLACK_GRIMOIRE", "name": "Black Grimoire", "rarity": "RARE", "price": 8,
  "trigger": "FINAL", "cond": { "type": "always" },
  "effects": [ { "op": "mul_count", "value": { "base": 1, "per": "bosses_defeated", "step": 0.25 } } ],
  "text": "×Count = 1 + 0.25 per boss defeated (currently ×{value})" }
```

---

## 10. Architecture (Godot)

```
res://
  core/            # pure logic, RefCounted, no Node; unit-tested
    db.gd               # loads/validates data JSON
    rng_streams.gd      # named seeded RNG streams
    die.gd, face.gd
    recipes.gd          # resolve_recipe, wild resolution
    scorer.gd           # §5.3, returns ScoreResult + trace
    relic_eval.gd       # DSL interpreter
    encounter_state.gd  # summon-turn state machine §4.3
    run_state.gd        # money, dice, relics, consumables, levels, night, counters
    shop.gd             # stock generation, buy/sell/reroll
    save.gd             # serialize/deserialize RunState
  autoload/
    Game.gd             # owns RunState, scene transitions
    Events.gd           # signal bus
    Settings.gd, Audio.gd
  scenes/              # title, night_map, encounter, shop, game_over, victory, overlays/
  ui/                  # die_view, group_chip, relic_slot, consumable_slot, tooltip, pixel_button, number_label
  fx/
    horde_renderer.gd   # §11
    combat_player.gd    # plays ScoreTrace
  data/
  assets/              # per ART_SPEC manifest
  tools/
    gen_placeholders.py, validate_art.py
    balance_sim.gd      # headless: godot --headless --script res://tools/balance_sim.gd
  tests/               # GUT or gdUnit4
```

### 10.1 RNG streams
`RunSeed` → derive per-stream seeds with `hash(seed + ":" + stream_name)`. Streams: `ROLL`, `SHOP`, `ENEMY`, `BOSS`. Each stream is a `RandomNumberGenerator` whose `state` is saved. Same seed + same inputs ⇒ identical run.

### 10.2 Events (signal bus, minimum)
`dice_rolled, die_selected, group_bound, group_unbound, summoned, combat_started, trace_step, combat_finished(win), money_changed, relics_changed, consumables_changed, shop_opened, night_started, run_ended(victory)`.

---

## 11. Combat playback & horde rendering

### 11.1 Visible sprite mapping (per group)
`visible(c) = c` if `c ≤ 12`, else `min(12 + floor(6 × log2(c / 12)), 40)`.
Badge on each group always shows the true Count (formatted).

### 11.2 Render tiers (whole army)
| Total visible | Sprite tier |
|---|---|
| ≤ 60 | Full 16×16 unit sprites |
| 61–240 | 8×8 crowd minis (ART_SPEC §4.4) |
| > 240 | Cap at 240 minis; add "LEGION" banner per group |

Implementation: object pool of `Sprite2D` (pre-allocate 260). Switch to `MultiMeshInstance2D` only if profiling on target devices shows < 55 fps.

### 11.3 Placement
Battlefield rect (ART_SPEC §6.2). Groups occupy columns left→right in summon order (wrap to new row band when full); sprites inside a group are placed on a jittered grid (±1 px, seeded by group index — not by the ROLL stream).

### 11.4 Playback timeline (speed ×1)
| Phase | Duration | What happens |
|---|---|---|
| Group steps | 0.25 s per trace step | Group chip highlights; P/C counters tick; sprite count tweens to `visible(C_group_contrib)`; `×` steps play the **clone burst** (each sprite pops a copy, scale punch 1→1.25→1, 120 ms) |
| Final relic steps | 0.3 s each | Relic icon shakes; counters update; ×C triggers a full-army clone burst |
| Total | 0.6 s | "P × C = DAMAGE" slam text, screen shake (respect setting) |
| Charge | 0.8 s | Sprites lunge to enemy in 4 staggered waves; enemy hit-flash; HP bar drains to `max(0, HP − damage)` |
| Result | 0.8 s | Win: enemy defeat (flash + pixel dissolve). Lose: enemy shrugs, army scatters/fades |

- If total phase time > 6 s at ×1, compress step durations uniformly so that it equals 6 s.
- Speed setting ×1/×2/×4 multiplies all durations. Tap anywhere during playback → jump to Result.
- Counter tick SFX pitch rises +1 semitone per step (cap +12).

---

## 12. Persistence & settings

### 12.1 Save
- `user://run.json`: full RunState (+ RNG stream states). Written at **encounter start** and **shop entry**. Deleted on Game Over / Victory.
- Quitting mid-encounter → Continue restarts that encounter from its start (same RNG state).
- `user://profile.json`: best Night reached, runs won, settings, tutorial flags.

### 12.2 Settings
Game speed (×1/×2/×4), Music volume, SFX volume, Screen shake (on/off), Reduce motion (disables clone bursts beyond 1 per group, shake, flashes), Number format (Short `12.3K` / Full).

### 12.3 Tutorial
First run only, dismissable coach marks:
1. First roll: "Tap 2–3 dice, then BIND to form a monster."
2. First bind: "Check the recipe book (ⓘ) to see all combinations."
3. Before first Summon: "Unbound dice are lost when you SUMMON."
4. First combat: "Damage = Power × Count. Beat the enemy's HP."
5. First shop: "Relics trigger left to right. Drag to reorder."

How to Play overlay: 4 pages mirroring the above with diagrams (static images from ART_SPEC manifest).

---

## 13. Milestones (11-day plan)

| M | Day | Scope | Acceptance criteria |
|---|---|---|---|
| M0 | 1 | Project scaffold, project settings (ART_SPEC §2), autoloads, placeholder generator, data JSON stubs | Game boots to a Title placeholder at 270×480 with integer scaling; `gen_placeholders.py` creates every manifest file |
| M1 | 1–2 | `core/`: db, recipes, scorer, relic DSL, encounter state machine, RNG, tests, balance sim | All §5.5 fixtures pass; §5.6 regression within ±5%; all 21 pair keys + 4 triples resolve; same seed ⇒ identical 100-turn bot log |
| M2 | 3–4 | Encounter screen playable with placeholders: roll/reroll/bind/unbind/summon/attack now, projected damage, basic combat result | A full encounter can be played and won/lost on Web; projected damage equals final damage every time |
| M3 | 5 | Run loop: Night map, cash-out, shop (buy/sell/reroll/equipment), consumables + Dice Inspector, Game Over/Victory | A full 24-encounter run is completable via debug HP override; money math matches §4.5 |
| M4 | 6 | All content data complete (§6) + relic reorder + boss rules | Every relic/consumable/equipment/boss has a test or scripted scenario proving its effect |
| M5 | 7–8 | Horde renderer, combat playback, juice, final art integration, audio | Night 6+ army with C ≥ 10,000 renders ≤ 240 sprites at ≥ 55 fps on a mid-range Android browser; playback ≤ 6 s at ×1 |
| M6 | 9 | Save/continue, settings, tutorial, How to Play, Run Info recipe book | Kill tab mid-shop → Continue restores identical state |
| M7 | 10 | Balance pass via sim, QA, Web export, itch.io page build | Sim bot (Appendix B policy) reaches Night 4 in ≥ 50% and wins ≤ 15% of 1,000 runs; no console errors |
| — | 11 | Buffer / launch | — |

---

## 14. Test plan (minimum)

- **Recipes**: matrix §6.3 exact; 52 invalid triples rejected; WILD resolution picks T3 when possible.
- **Scorer**: §5.5 fixtures (3 cases); each relic has one isolated fixture; HEX rounding (C=3 → ×1.5 → 5).
- **Encounter SM**: cannot reroll with 0 rerolls; cannot bind invalid triple; shackled die unselectable; Attack Now consumes 1 summon and pays unused summons at cash-out.
- **Shop**: no duplicate relic offers; prerequisites respected; sell prices; reroll cost increments and resets per visit.
- **Determinism**: same seed + scripted inputs ⇒ identical RunState hash after 3 Nights.
- **Save**: round-trip RunState equality.

---

## 15. Out of scope for v1 (stretch)
Encounter skipping/tags, alternate starting loadouts (e.g. "Ossuary": 2 Bone-heavy dice), discovery-gated recipe book, Endless mode, collection/compendium, localization (Vietnamese needs a font with diacritics), online leaderboards, achievements, daily seed.

---

## Appendix A — Baseline reference simulation (Python)

```python
import random, itertools, statistics as st
E = ['BONE','FIRE','ICE','LEAF','VOLT','METAL']
U = {}
def add(i, rec, p, c): U[tuple(sorted(rec, key=E.index))] = (i, p, c)
add('SKELETON_WARRIOR',['BONE','BONE'],10,2);  add('FIRE_IMP',['FIRE','FIRE'],6,3)
add('FROST_BAT',['ICE','ICE'],14,1);           add('PUMPKINLING',['LEAF','LEAF'],8,2)
add('VOLT_GHOST',['VOLT','VOLT'],12,2);        add('HAUNTED_ARMOR',['METAL','METAL'],18,1)
add('FLAME_SKULL',['BONE','FIRE'],15,3);       add('SCARECROW',['BONE','LEAF'],16,3)
add('SHIELD_SKELETON',['BONE','METAL'],20,2);  add('STEAM_SLIME',['FIRE','ICE'],10,4)
add('JACK_O_LANTERN',['FIRE','LEAF'],12,4);    add('BOG_WITCH',['ICE','LEAF'],12,3)
add('STORM_BANSHEE',['ICE','VOLT'],22,2);      add('TESLA_SPIDER',['VOLT','METAL'],14,3)
add('LICH',['BONE']*3,40,8);                   add('HEADLESS_HORSEMAN',['BONE','FIRE','LEAF'],60,6)
add('STITCHED_GOLEM',['BONE','VOLT','METAL'],80,4); add('WITCH_QUEEN',['ICE','LEAF','VOLT'],45,7)

def unit(rec):
    k = tuple(sorted(rec, key=E.index))
    if k in U: return U[k]
    return ('WISP', 5, 1) if len(rec) == 2 else None

def partitions(dice):
    out = []
    def rec(avail, cur):
        out.append(list(cur))
        if len(avail) < 2: return
        f = avail[0]
        for size in (2, 3):
            for comb in itertools.combinations(avail[1:], size - 1):
                g = (f,) + comb
                u = unit([dice[i] for i in g])
                if u: rec([a for a in avail if a not in g], cur + [u])
        rec(avail[1:], cur)
    rec(list(range(len(dice))), [])
    return out

def encounter(n_dice=4, n_summons=3):
    P = C = 0
    for _ in range(n_summons):
        roll = [random.choice(E) for _ in range(n_dice)]
        best = max(partitions(roll), key=lambda o: (P + sum(u[1] for u in o)) * (C + sum(u[2] for u in o)))
        P += sum(u[1] for u in best); C += sum(u[2] for u in best)
    return P * C

d = sorted(encounter() for _ in range(20000))
print(int(st.mean(d)), d[10000], d[2000], d[18000])   # ≈ 1590, 1530, 930, 2350
```

## Appendix B — Balance-sim bot policy (for M7)
- Summon turns: greedy partition as Appendix A; reroll the dice not used by the best partition if `rerolls_left > 0` and that partition has < `floor(n_dice/2)` groups.
- Shop: buy the highest-rarity affordable relic if a slot is free; else Tome matching the element with most essence last encounter; keep ≥ $5 for interest when Night ≥ 2; buy equipment if affordable after that.
- Attack Now if projected damage ≥ 1.1 × HP.
