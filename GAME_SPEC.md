# ROLL THE BONES — Game Loop Spec v2.0

> Halloween 2026 dice-summoning roguelike: roll bone dice, pick a combo, summon a squad,
> send the army at a human monster-hunter. Balatro-shaped scoring with battle / necromancy
> words — no poker terms anywhere in the game.
> v2.0 (2026-10-23) replaces v1.0 after the first designer playtest (DECISIONS D-G06…D-G12).
> Companion: `ART_SPEC.md`. Every rule is normative unless marked *(tunable)* or *(stretch)*.

---

## 0. How to use this document (for coding agents)

1. Read §1 and §2 first. IDs in §6 are the contract between data, code and art.
2. Content lives in `res://data/*.json` (§9). Code never hard-codes stats, prices, HP or odds.
3. `res://core/` is pure GDScript (`RefCounted`, no `Node`), unit-tested headless. Presentation
   replays a **trace** (§5.5); it never computes rules.
4. Ambiguity → the option closest to Balatro's behaviour, logged in `DECISIONS.md`.
5. **Words:** the UI never says hand, discard, chips, mult, joker, tarot, planet, voucher,
   booster pack, blind, ante, deck or cash out. Use the glossary (§2).

---

## 1. Locked decisions

| ID | Decision | Value |
|---|---|---|
| D-01 | Engine / target | Godot 4.6.3, GDScript, 2D. Web desktop (itch.io) first, mobile landscape second |
| D-02 | Resolution | 480 × 270 landscape, integer scale (ART_SPEC §2) |
| D-03 | Dice | 6 faces; a face = **element + points + optional rune**. Start with **5** dice, max **8** |
| D-04 | Points | BONE faces are always **6**. The other five elements carry **1–5**, in a different order on every die |
| D-05 | Elements | `BONE, FIRE, ICE, LEAF, VOLT, METAL` (canonical order) |
| D-06 | Rolling | Every roll rolls **all** your dice. No bag, no draw pile. Dice are added, never discarded |
| D-07 | Per battle | **3 Summons**, **2 Rerolls** (shared). A summon = roll → pick → confirm one squad |
| D-08 | Squad | Pick **3–5** dice in order; they form one **combo** (§4.3). Score = `floor(Power × Count)` |
| D-09 | Order | Squad: combo base → scored dice left→right (points, rune) → held-dice runes → trinkets left→right |
| D-10 | Battle end | The player presses **ATTACK!** between summons (or when the summons run out): the army's damage (Σ squads, then RESOLVE trinkets) hits the hunter; ≥ HP wins. Every summon left unused pays $1 (D-G14) |
| D-11 | Run | 8 Nights × (Mob, Champion, Boss) = 24 battles |
| D-12 | Determinism | Seeded run; all randomness from named RNG streams (§10.1). The scorer has no RNG: luck is rolled before scoring |

---

## 2. Glossary

| Term (UI) | Balatro analog | Meaning |
|---|---|---|
| **Die / Dice** | card / deck | 6 faces; your whole set is rolled every summon |
| **Face** | card rank + suit | element + points (BONE = 6) + optional **rune** |
| **Rune** | enhancement | a mark on one face that changes how it scores (§4.6) |
| **Roll** | draw | all dice tumble and land on a random face |
| **Reroll** | discard | re-roll the selected dice; 1 reroll however many dice |
| **Pick** | select | choose 3–5 dice in order; they fly into the **Pick Tray** |
| **Summon** | hand | confirm the pick: the squad scores and joins the army |
| **Combo** | poker hand | the pattern of the picked dice (§4.3) |
| **Squad** | played hand | one summoned combo: unit, Power, Count, strength |
| **Power / Count** | chips / mult | running totals; Count is also the number of soldiers |
| **Strength** | hand score | `floor(Power × Count)` of one squad |
| **Army** | round score | all squads of this battle; damage = Σ strength, then RESOLVE trinkets |
| **Held dice** | cards held in hand | dice showing but not picked when you summon |
| **Battle** | blind | one fight against one hunter |
| **Hunter** | blind | Mob, Champion or Boss; Boss has a rule |
| **Night** | ante | 3 battles |
| **Spoils** | cash out | money after a won battle (§4.8) |
| **Crypt Market** | shop | buy between battles (§7) |
| **Trinket** | joker | passive item, max 5, order = trigger order |
| **Potion** | tarot | changes faces or money (§6.6) |
| **Gem** | planet | +1 level to one combo (§6.7) |
| **Gear** | voucher | permanent upgrade, one per Night (§6.8) |
| **Coffer** | booster pack | open, choose 1–2 of several items (§6.9) |
| **Soul Coins ($)** | money | — |

Code keeps the v1 names `relic` (trinket), `consumable` (potion / gem), `equipment` (gear)
for files and classes (DECISIONS D-G12). Players never see those words.

---

## 3. Core loop

```
NIGHT MAP → BATTLE ─win→ SPOILS → CRYPT MARKET → NIGHT MAP → … (Night 8 boss → VICTORY)
                   └lose→ GAME OVER

BATTLE:  [ROLL] → PICK ⇄ REROLL → [SUMMON] → squad scores (playback) → between summons:
            ▲                                                              │ [ATTACK!] → RESOLVE
            └──────────────── [ROLL] while summons are left ───────────────┘ (win / lose; unused summons pay)
```

---

## 4. Rules

### 4.1 Run setup
Seed (8 chars) → RNG streams. Money `start_money`. `start_dice` dice from `Die.random` (DICE
stream), no runes. Combo levels all 1. Night 1, battle 0.

### 4.2 Battle setup
`summons_left = base_summons + gear − Inquisitor`, min `min_summons`; `rerolls_left =
base_rerolls + gear`. Hunter HP from §6.12. Witch Hunter disables the leftmost trinket for
this battle. Phase = `AWAIT_ROLL`. The run is saved **before** the first roll.

### 4.3 Combos

Combos are read from the **elements** of the picked dice (WILD rune = any element, TOMB rune
= no element). The highest-ranked pattern present wins; ties by rank are impossible.

| Rank | Combo | Pattern (n = picked dice, 3–5) | Scored dice |
|---|---|---|---|
| 8 | Quintet | 5 of one element | all 5 |
| 7 | Quartet | 4 of one element | those 4 |
| 6 | Ritual | a ritual's 3 elements with its **core** twice (4 dice) | those 4 |
| 5 | Full Moon | 3 of one element + 2 of another | all 5 |
| 4 | Rainbow | 5 different elements | all 5 |
| 3 | Trio | 3 of one element | those 3 |
| 2 | Duo Pact | 2 of one + 2 of another | those 4 |
| 1 | Rabble | anything else | the single highest-points die |

- TOMB faces are never part of a pattern but **always score** (Stone card).
- WILD faces resolve to the assignment giving the highest rank, then the most scored points;
  ties → lowest element index. Resolution is part of the rules module and stored on the squad.
- "Those dice" = the first matching dice in pick order.

Rituals (core in bold): Headless Horseman **BONE**·FIRE·LEAF, Stitched Golem BONE·**VOLT**·METAL,
Witch Queen **ICE**·LEAF·VOLT, Clockwork Kraken FIRE·ICE·**METAL**.

Combo odds with 5 uniform dice (200k trials, `docs/design/combo_odds.md`): Rabble 37%, Duo Pact
20%, Trio 14%, Ritual 13%, Rainbow 9%, Full Moon 4%, Quartet 2%, Quintet 0.1% — rerolling
toward one element moves the mass to Trio / Quartet. A 3-distinct-element ritual was rejected:
it appeared in 45% of rolls.

### 4.4 Unit of a squad (cosmetic + trinket conditions)

| Combo | Unit |
|---|---|
| Rabble | Wisp, tinted by the two most common picked elements |
| Duo Pact X+Y | the hybrid of X+Y (§6.2), else Wisp(X, Y) |
| Trio X | the T1 unit of X |
| Full Moon 3X+2Y | the hybrid of X+Y, else the T1 unit of X |
| Rainbow | Phantom Parade |
| Ritual | that ritual's unit |
| Quartet X | the Elite of X |
| Quintet X | the Legend of X |

Units carry no stats in v2; combos do. **Horde** units (T1, hybrid, Wisp) show Count soldiers;
**single** units (Elite, Ritual, Parade) and **legends** show one big body whose aura grows
with Count (ART_SPEC §10).

### 4.5 Battle state machine

| Phase | Legal verbs | Notes |
|---|---|---|
| `AWAIT_ROLL` | ROLL (summons left), ATTACK (≥ 1 squad), USE_CONSUMABLE | between summons: the two big actions |
| `PICK` | SELECT, REROLL, SUMMON, USE_CONSUMABLE | |
| `DONE` | — | resolved; `win` set |

- **ROLL**: every die gets a random face (ROLL stream); ROLL trinkets fire; Bell Ringer
  shackles one die (BOSS stream). → `PICK`.
- **SELECT i**: toggles die i in the pick (order kept; max `pick_max`; shackled dice cannot).
- **REROLL**: `rerolls_left > 0`, ≥ 1 picked die. Re-rolls the picked dice, clears the pick,
  shackles again.
- **SUMMON**: `pick_min ≤ picked ≤ pick_max`. Luck is rolled (LUCK stream, §4.6), the squad
  is scored (§5), commit effects apply (SUMMON trinkets, counters, lucky money, glass
  breaks), the squad joins the army, `summons_left − 1` → `AWAIT_ROLL`.
- **ATTACK**: ≥ 1 squad, between summons. **RESOLVE** → `DONE`. Attacking with the army short
  of the HP while summons are left asks for confirmation (it ends the run).
- **USE_CONSUMABLE**: potions / gems mid-battle; faces showing update at once and the pick is
  re-read.
- Projected numbers: the pick panel shows the squad preview (§5.4); the hunter panel shows the
  army so far + preview.

### 4.6 Runes (face enhancements)

One rune per face. A rune changes the **die body** while that face is up (ART_SPEC §4.6).

| Rune | Balatro | Effect | When |
|---|---|---|---|
| SHARP | Bonus | +30 Power | scored |
| SWARM | Mult | +4 Count | scored |
| WILD | Wild | counts as every element | combo |
| GLASS | Glass | ×2 Count; 1 in 4 the rune shatters after the summon (face stays) | scored |
| IRON | Steel | ×1.5 Count | **held** (not picked) when the squad scores |
| TOMB | Stone | +50 Power, no element, no points; always scores | scored |
| GILDED | Gold | +$3 at Spoils | showing on a held die after the last summon |
| LUCKY | Lucky | 1 in 5: +10 Count; 1 in 15: +$20 | scored |

Odds and values are data (`economy.json.runes`). Luck and glass are rolled in the SUMMON
command before scoring; previews assume no luck and no break.

*(stretch, after playtest)* **Die finishes** (Balatro editions, one per die): Ivory +50 Power,
Spectral +10 Count, Cursed ×1.5 Count — a metallic / ghostly / blood rim on the die body.
**Marks** (seals): Gold mark +$3 when scored, Echo mark scores the face twice.

### 4.7 Combo levels (Gems)
Level L adds `(L − 1) × lvl_p` Power and `(L − 1) × lvl_c` Count to the combo base.

### 4.8 Spoils (won battle)
Lines, in order: hunter bounty (`reward_<role>`, Night 8 boss `reward_final`), unused summons
(`unused_summon_bonus` each), interest (on money **before** the payout: `interest_amount` per
`interest_per`, cap `interest_cap` + gear), Gilded faces held after the last summon, SPOILS
trinkets. The overlay shows exactly these lines (Balatro values: rerolls pay nothing).

---

## 5. Scoring

### 5.1 Squad scorer
```
P = combo.base_p + (L−1)·lvl_p ;  C = combo.base_c + (L−1)·lvl_c        COMBO step
for each scored die, pick order:
    P += points (Exorcist: BONE → 0)                                       DIE step
    rune: SHARP +P | SWARM +C | GLASS ×C | TOMB +P | LUCKY (+C if proc)    RUNE step
    DIE trinkets left→right whose cond matches this die                    TRINKET step
for each held die: IRON ×1.5 C                                             HELD step
SQUAD trinkets left→right                                                  TRINKET step
strength = floor(P × C)                                                    STRENGTH step
```
Every × rounds half up immediately (`floor(x + 0.5)`).

### 5.2 Resolve
`army = Σ strength`; RESOLVE trinkets left→right (`mul_damage`, `add_damage`, rounded half
up); `damage = army`; `win = damage ≥ HP`.

### 5.3 Commit effects (SUMMON command, never in the scorer)
SUMMON trinket money and counters, lucky money, glass breaks, stats. A preview applies them to
copies (D-G01).

### 5.4 Previews
`preview()` = the scorer on the current pick with no luck. `projected()` = resolve(army +
preview). The same functions drive the UI, the bot and tests.

### 5.5 Trace (contract with presentation)
`TraceStep {kind, die, source_id, op, value, p_after, c_after, label}` with kinds
`COMBO, DIE, RUNE, HELD, TRINKET, BOSS, STRENGTH` (squad) and `RESOLVE, TOTAL` (army). The
last squad step equals the squad's strength; the last resolve step equals the damage.

### 5.6 Worked example (test fixture)
Dice picked: FIRE-4, FIRE-2 (SHARP), FIRE-5, ICE-3; trinkets Ember Jar, Three-faced Totem; Trio L1.
COMBO 30 × 3 → DIE F4 34 → Ember 54 → DIE F2 56 → SHARP 86 → Ember 106 → DIE F5 111 → Ember 131
→ Three-faced Totem C 11 → strength **1,441**. ICE-3 is unscored.

---

## 6. Content tables (ids are the contract; numbers are in data)

### 6.1 Elements
BONE (bone), FIRE (orange), ICE (cyan), LEAF (green), VOLT (yellow), METAL (grey).

### 6.2 Units (32)
| Kind | Units |
|---|---|
| T1 (Trio) | SKELETON_WARRIOR (B), FIRE_IMP (F), FROST_BAT (I), PUMPKINLING (L), VOLT_GHOST (V), HAUNTED_ARMOR (M) |
| Hybrid (Duo Pact / Full Moon) | FLAME_SKULL B+F, SCARECROW B+L, SHIELD_SKELETON B+M, STEAM_SLIME F+I, JACK_O_LANTERN F+L, BOG_WITCH I+L, STORM_BANSHEE I+V, TESLA_SPIDER V+M |
| Ritual | HEADLESS_HORSEMAN, STITCHED_GOLEM, WITCH_QUEEN, CLOCKWORK_KRAKEN |
| Elite (Quartet, single) | LICH (B), HELLHOUND (F), FROST_WRAITH (I), MANDRAKE_BRUTE (L), THUNDER_GHOUL (V), GARGOYLE (M) |
| Legend (Quintet, 32×32) | BONE_DRAGON (B), EMBER_COLOSSUS (F), FROST_WYRM (I), ELDER_HOLLOW (L), STORM_TITAN (V), IRON_JUGGERNAUT (M) |
| Parade (Rainbow) | PHANTOM_PARADE |
| Rabble | WISP |

### 6.3 Combos (base level 1, per level) *(tunable)*
| Id | Base P × C | +P / +C per level |
|---|---|---|
| RABBLE | 10 × 1 | 10 / 1 |
| DUO_PACT | 20 × 2 | 20 / 1 |
| TRIO | 30 × 3 | 20 / 2 |
| RAINBOW | 35 × 4 | 30 / 3 |
| FULL_MOON | 40 × 4 | 25 / 2 |
| RITUAL | 50 × 5 | 30 / 3 |
| QUARTET | 60 × 7 | 30 / 3 |
| QUINTET | 120 × 12 | 35 / 3 |

### 6.4 Trinkets (30) — timing shown on the card
Timings: **ROLL** (after each roll), **DIE** (per scored die), **SQUAD** (once per squad),
**RESOLVE** (army total), **SUMMON** (commit: money / counters), **SPOILS** (money).

| Id | Timing | Effect | Rarity |
|---|---|---|---|
| RATTLE_DRUM | DIE | scored BONE die: +3 Count | C |
| EMBER_JAR | DIE | scored FIRE die: +20 Power | C |
| FROST_LANTERN | SQUAD | squad has ICE: +5 Power per scored die | C |
| MOSS_CHARM | DIE | scored LEAF die: +2 Count | C |
| LIGHTNING_ROD | DIE | scored VOLT die: +10 Power, +1 Count | C |
| IRON_NAIL | SQUAD | 2+ scored METAL dice: +30 Power | C |
| GRAVEDIGGER_LAMP | SQUAD | +4 Count | C |
| TRIO_TOTEM | SQUAD | Trio: +8 Count | C |
| MOON_CHARM | SQUAD | Full Moon: +10 Count | C |
| BONE_SAW | SQUAD | every scored die shows 4+ points: +40 Power | C |
| WISP_JAR | SQUAD | Rabble: ×3 Count | C |
| GRAVE_ROBBER | SPOILS | +$2 | C |
| DEEP_FREEZE | SQUAD | 3+ scored ICE dice: ×1.5 Count | C |
| LOADED_BONE | ROLL | after a roll with no BONE showing, one die turns to its BONE face | U |
| THRIFTY_GHOST | SQUAD | +3 Count per reroll left | U |
| HYBRID_VIGOR | SQUAD | Duo Pact or Full Moon: +6 Count | U |
| COPYCAT_COFFIN | SQUAD | unit already summoned this battle: +8 Count | U |
| OVERGROWTH | SQUAD | +1 Count per LEAF squad ever summoned (counter) | U |
| SPIRIT_BOARD | SQUAD | Rainbow: ×2 Count | U |
| PIGGY_COFFIN | SQUAD | +2 Power per $1 held | U |
| GILDED_TOOTH | SUMMON | +$1 per scored BONE die | U |
| BONE_PILE | SQUAD | +2 Count per held die showing BONE | U |
| COLD_HEARTH | DIE | scored die with 1–2 points: +15 Power | U |
| GRAND_PROCESSION | SQUAD | +15 Power per squad already summoned this battle | U |
| TACTICIAN_SKULL | SQUAD | first squad of the battle: ×2 Power | R |
| CROWN_OF_THE_LICH | SQUAD | Ritual, Quartet or Quintet: ×2 Count | R |
| LAST_RITES | SQUAD | no summons left after this one: ×3 Count | R |
| ELEMENTAL_CONVERGENCE | SQUAD | all 6 elements scored this battle: ×3 Count | R |
| BLOOD_MOON | RESOLVE | 3+ squads: ×1.5 damage | R |
| BLACK_GRIMOIRE | RESOLVE | ×(1 + 0.25 per boss defeated) damage | R |

### 6.5 Dice for sale
A market die = `Die.random` (points shuffled per die) with a rune on one random non-BONE face at
`die_rune_chance`. Price `die_price` (+`die_rune_price` with a rune). Adding a die is the
strongest single upgrade: more dice = more choices every roll.

### 6.6 Potions (17)
| Id | Targets | Effect |
|---|---|---|
| ELIXIR_<ELEMENT> ×6 | 1–2 faces | face becomes that element (BONE → 6 points; a former BONE face gets 3) |
| STRENGTH_TONIC | 1–2 non-BONE faces | +2 points (max 9) |
| WHETSTONE_OIL | 1–2 faces | SHARP rune |
| SWARM_BREW | 1–2 faces | SWARM rune |
| WILD_SPIRITS | 1 face | WILD rune |
| GLASS_DRAUGHT | 1 face | GLASS rune |
| IRON_DRAUGHT | 1 face | IRON rune |
| GRAVE_DUST | 1 face | TOMB rune |
| LIQUID_GOLD | 1 face | GILDED rune |
| LUCKY_CLOVER | 1–2 faces | LUCKY rune |
| MIRROR_DRAUGHT | exactly 2 faces | the second face becomes a copy of the first |
| HERMIT_BREW | none | double your money (max +$20) |

### 6.7 Gems (8)
OPAL Rabble · GARNET Duo Pact · AMBER Trio · PRISM Rainbow · MOONSTONE Full Moon · OBSIDIAN Ritual
· EMERALD Quartet · BLOODSTONE Quintet — +1 level each.

### 6.8 Gear (13) — one offered per Night, $10 *(tunable)*
GRAVE_BELL → DEATH_KNELL (+1 summon each) · LOADED_CUP → SECOND_CUP (+1 reroll each) ·
RELIQUARY → OSSUARY (+1 trinket slot each) · HAGGLER_LANTERN → BLACK_MARKET (market reroll −$2
each) · OVERSTOCK → OVERFLOWING_CRYPT (+1 market card slot each) · GRAVE_GOODS → DRAGON_HOARD
(+$5 interest cap each) · POCKET_CRYPT (+1 potion / gem slot). Tier 2 requires tier 1.

### 6.9 Coffers (12)
| Kind | Normal $4 | Jumbo $6 | Mega $8 | Contents |
|---|---|---|---|---|
| POTION | 1 of 3 | 1 of 5 | 2 of 5 | potions, used at once |
| GEM | 1 of 3 | 1 of 5 | 2 of 5 | gems, used at once |
| TRINKET | 1 of 2 | 1 of 4 | 2 of 4 | trinkets (need a free slot) |
| BONE | 1 of 3 | 1 of 5 | 2 of 5 | market dice (need dice < max) |

Ids `COFFER_<KIND>`, `COFFER_<KIND>_JUMBO`, `COFFER_<KIND>_MEGA`. Skip is always allowed.

### 6.10 Hunters
Mob: Torch Villager, Pitchfork Farmer, Lantern Watchman. Champion: Guard Captain, Monster
Hunter. Boss: The Exorcist, The Witch Hunter, The Bell Ringer, The Inquisitor.

### 6.11 Boss rules
| Rule | Effect |
|---|---|
| EXORCIST | Holy Water: BONE dice score 0 points |
| WITCH_HUNTER | Confiscation: your leftmost trinket is disabled |
| BELL_RINGER | Toll: after every roll and reroll, 1 random die is shackled |
| INQUISITOR | Interrogation: −1 summon |
| ENRAGED (Night 8) | two rules at once |

Boss HP multiplier = product of its rules' `hp_mult` (D-G02 method). Night 1 bosses come from
Exorcist / Witch Hunter only (Bell Ringer on five dice ended most runs, D-G13).

### 6.12 HP curve *(tunable)*
`HP = night_base[night] × role_mult[role]` (boss: product of rule multipliers). Balatro's blind
bases (300 / 800 / 2,000 …) were the starting point; the bot put them far too high for three
summons of five dice, so the tuned curve lives in `data/curve.json` (D-G13).

### 6.13 Economy *(tunable)*
`data/economy.json`: start money $4, 5 dice (max 8), pick 3–5, 3 summons, 2 rerolls, bounty
$3 / $4 / $5 (final boss $8), $1 per unused summon, interest $1 per $5 (cap $5), 5 trinket
slots, 2 potion / gem slots, sell = floor(price / 2) (potion / gem $1).

---

## 7. Crypt Market (Balatro shop)

| Row | Count | Restock |
|---|---|---|
| Cards | 2 (+ gear) | weights Trinket 20, Potion 4, Gem 4, Die 2; rerolled by REROLL |
| Coffers | 2 | per visit; kind weights Potion 4, Gem 4, Trinket 1.2, Bone 4; size Normal 4, Jumbo 2, Mega 0.5; the first visit of a run guarantees a Trinket coffer |
| Gear | 1 | per Night |

- Trinket rarity Common 70 / Uncommon 25 / Rare 5; owned or on-shelf trinkets are excluded.
- Reroll **$5 + $1 per reroll this visit**, minus gear (min $0).
- Buy & Use for potions / gems; a bought coffer opens at once (choices rolled on purchase,
  stored in the market state so Continue restores it).
- Sell trinkets for floor(price / 2), potions / gems for $1. Dice are never sold.

---

## 8. Screens & flows
Title → Night Map → Battle → Spoils → Crypt Market → Night Map … → Victory / Game Over.
Overlays: Codex (combos with levels, rituals, units), Settings, Dice Inspector (targets),
Coffer, Spoils, Confirm, How to Play.

---

## 9. Data files (`res://data/`)

| File | Content |
|---|---|
| `elements.json` | §6.1 |
| `combos.json` | §6.3 + rituals |
| `units.json` | §6.2: kind, elements, display, mini |
| `relics.json` | trinkets §6.4 in the DSL |
| `consumables.json` | potions §6.6 and gems §6.7 |
| `coffers.json` | §6.9 |
| `equipment.json` | gear §6.8 |
| `enemies.json` | §6.10–§6.11 |
| `curve.json`, `economy.json` | §6.12, §6.13, rune values, market weights |
| `text/ui/*.json`, `text/content/*.json` | every word the player reads: UI strings per screen; names, effects and lore per id (designer-edited, `data/text/README.md`) |

### 9.1 Trinket DSL
```json
{ "id": "EMBER_JAR", "rarity": "COMMON", "price": 4,
  "trigger": "DIE", "cond": { "type": "die_element", "element": "FIRE" },
  "effects": [ { "op": "add_power", "value": 20 } ] }
```
- Triggers: `ROLL, DIE, SQUAD, RESOLVE, SUMMON, SPOILS`.
- Ops: `add_power, add_count, mul_power, mul_count` (DIE / SQUAD), `mul_damage, add_damage`
  (RESOLVE), `add_money` (SUMMON / SPOILS), `ensure_face` (ROLL, `element`).
- Values: number or `{base, per, step}`; sources `money, rerolls_left, summons_left,
  squads_before, bosses_defeated, counter, scored_dice, scored:<E>, held:<E>`.
- Conditions: `always, die_element, die_points_lte, squad_combo, squad_combo_in,
  squad_has_element, squad_element_count_gte, squad_all_points_gte, squad_is_first,
  squad_is_last, squad_unit_repeated, battle_distinct_elements_gte, squads_gte`.
- Counter: `{"on": "SUMMON", "cond": {...}, "inc": 1}`; `blocks` for several triggers.

---

## 10. Architecture

| Layer | Owner |
|---|---|
| Run FSM | `core/run_state.gd` + `core/run_flow.gd` (phase saved) |
| Battle FSM | `core/encounter_state.gd` (`can(verb)`, commands) |
| Rules | `core/combos.gd`, `core/scorer.gd`, `core/relic_eval.gd`, `core/rules_registry.gd` |
| Run economy | `core/economy.gd`, `core/shop_state.gd`, `core/consumable_fx.gd`, `core/night_gen.gd` |
| Presentation | `fx/presentation_queue.gd`, `fx/battle_player.gd`, `fx/horde_renderer.gd` |

### 10.1 RNG streams
`ROLL` (faces, Loaded Bone), `LUCK` (lucky / glass), `DICE` (new dice), `SHOP`, `ENEMY`,
`BOSS`. Seed per stream = `hash(seed + ":" + name)`; states saved.

---

## 11. Playback (speed ×1; ×2 / ×4 divide; tap skips)

| Beat | Time | What plays |
|---|---|---|
| Roll | 0.35–0.9 s per die, random, last die slowest | dice tumble in the tray and land one by one with a bounce and a click |
| Combo | 0.35 s | combo banner slams; the squad's base soldiers pop onto the field |
| Die / rune / held | 0.16 s each | the die bounces, its number pops, Power / Count bounce; +Count adds soldiers, ×Count clone-bursts the squad |
| Trinket | 0.22 s each | the trinket shakes, the number bounces |
| Strength | 0.35 s | "P × C = strength" slam; the army total ticks up |
| Resolve trinkets | 0.3 s each | trinket shakes, army total × |
| Charge | 0.6 s per squad | the squad flies into the hunter: impact flash, shake, HP drains by that squad's share |
| Result | 1.0 s | win: hunter dissolves, coin burst, banner; loss: hunter laughs, army scatters and fades, banner |

A summon's playback is compressed to ≤ 4 s and the resolve to ≤ 5 s at ×1. Visible soldiers
per horde squad: `c` up to 12, then `12 + floor(6 log2(c / 12))`, cap 40; tiers by total
(≤ 60 full sprites, ≤ 240 minis, else LEGION banners). Single units: aura tier by Count
(≥ 10, ≥ 40, ≥ 160).

---

## 12. Balance targets (bot evidence only)
Bot policy: roll; reroll the dice outside its best pattern while the best squad is weaker than
a Trio; summon the strongest preview; market: best trinket, a die when affordable, gems for its
most-used combo, gear. Targets over 1,000 seeded runs: Night 1 Mob won ≥ 95%, reach Night 4 ≥
50%, win ≤ 15%. Human playtest decides fun.

---

## 13. Persistence & settings
Run save at battle start (before the roll) and after every market command; deleted at the end.
Settings: speed ×1 / ×2 / ×4, volumes, screen shake, reduce motion, number format.

---

## 14. Milestones (v2)

| M | Scope | Done when |
|---|---|---|
| V2-M1 | core: faces with points + runes, combos, squad scorer, resolve, battle FSM, economy, market, potions / gems / coffers / gear, data, tests, bot | all core tests + §5.6 fixture pass; bot plays 1,000 runs |
| V2-M2 | battle screen: roll button, pick tray, squads, resolve; Spoils; Codex | a battle is playable start → spoils with placeholder art |
| V2-M3 | Crypt Market v2: cards, coffers, gear, coffer overlay | a full run is playable |
| V2-M4 | art: 13 units, potion / gem / coffer / gear / trinket icons, rune bodies, point badges, aura flames | `ART OK` |
| V2-M5 | juice: staggered roll, per-die bounce, clone bursts, auras, charge waves, win / lose | captures at ×1 / reduce motion |
| V2-M6 | balance by bot, web export | §12 targets |

## 15. Tests (minimum)
Combo table incl. WILD / TOMB; worked example §5.6; each trinket isolated; rune fixtures
(glass break, iron held, lucky with forced luck); battle FSM guards; auto-resolve; spoils
lines; market weights, exclusion, reroll cost reset, coffer pick; determinism (same seed +
inputs ⇒ same run hash); save round-trip.
