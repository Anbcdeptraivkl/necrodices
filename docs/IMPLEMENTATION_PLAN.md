# Implementation Plan — Rattle & Roll (NecroDices)

Status: **2026-10-20 — M0 done (landscape 480×270)**; landscape layouts approved; M1 next.
Sources: [GAME_SPEC.md](../GAME_SPEC.md) (rules, normative), [ART_SPEC.md](../ART_SPEC.md)
(look and layout, normative), [DECISIONS.md](../DECISIONS.md) (deviations / resolved ambiguity).
This plan says **what gets built, in which order, by which class, and how we know it works**.
It never restates numbers that live in the specs or `data/`.

Calendar: GAME_SPEC §13 is an 11-day plan. Day 1 = **Tue 2026-10-20**, launch buffer =
**Fri 2026-10-30**, Halloween = Sat 2026-10-31. There is no slack: anything not on the
critical path (§8) is cut before a milestone slips.

---

## 1. Player promise and the one question per milestone

> The player rolls spooky dice, **binds them into monsters**, watches a horde of skeletons
> and pumpkins **multiply on screen** as relics fire left to right, and feels clever when an
> order swap turns 2,450 into 2,520 — then pushes one Night further.

| Milestone | The question it must answer (game-design-review rule 3) |
| --- | --- |
| M1 | Are the rules correct and is the baseline curve what the spec assumed? (engineering + sim) |
| M2 | Is one encounter readable and does rolling/binding feel like a decision? (first human play) |
| M3 | Does the shop create builds — do players buy differently on different runs? |
| M4 | Does every relic/boss do what its text says? (engineering) |
| M5 | Is the horde payoff satisfying and fast enough on a phone browser? |
| M6–M7 | Can a stranger learn it without us, and does the curve land (bot ≥ 50% reach Night 4, ≤ 15% win)? |

First human playtest happens at the end of M2, not after polish (game-design-review rule 5).

---

## 2. Architecture (where everything lives)

Layers (skill `godot-architecture`): lower layers never read upper ones; presentation never
mutates the model.

```
App FSM      (Game autoload)      BOOT → TITLE → RUN ⇄ OVERLAYS → GAME_OVER/VICTORY
Run FSM      (core/run_state.gd)  NIGHT_MAP → ENCOUNTER → CASH_OUT → SHOP → NIGHT_MAP … (phase saved)
Encounter FSM(core/encounter_state.gd) TURN_START → AWAIT_INPUT ⇄ REROLLING → COMMIT → TURN_END → COMBAT → RESULT
Interaction  (ui/overlay_stack.gd) pushdown: inspector target pick, tooltip, confirm, settings
Presentation (fx/presentation_queue.gd) queue of skippable states; plays ScoreTrace
```

### 2.1 `core/` — pure logic (RefCounted, no Node; all headless-tested)

| File / class | Owns | Spec |
| --- | --- | --- |
| `json_util.gd` `JsonUtil` | JSON load w/o error spam, float→int narrowing | — |
| `db.gd` `ContentDb` | Load + validate `data/*.json`; recipe table; strings | §9, §5.1 |
| `rules_registry.gd` `RulesRegistry` | Const lists of legal triggers/ops/conds/sources/modifiers/boss rules; validated against data | §9.1 |
| `rng_streams.gd` `RngStreams` | `ROLL/SHOP/ENEMY/BOSS` streams, state save/restore, weighted pick, seeded shuffle | §10.1 |
| `face.gd` `Face`, `die.gd` `Die` | Element + modifier per face; 6 faces; top face index | §2, §4.9 |
| `group.gd` `Group` | `unit_id`, faces (tray order), resolved elements, summon_index; `has_element`, essence | §2 |
| `recipes.gd` `Recipes` | `resolve(faces)`, WILD cartesian resolution w/ tie-break | §5.1, §5.2 |
| `relic_eval.gd` `RelicEval` | DSL interpreter: cond, value, apply; per-phase op legality | §9.1 |
| `score_ctx.gd` `ScoreCtx` | Essence, groups, money, rerolls/summons left, bosses defeated, running P/C, seen units | §5.3 |
| `scorer.gd` `Scorer` | `score(army, run, enc) -> ScoreResult{damage,p,c,trace}`; boss rules EXORCIST / WITCH_HUNTER | §5.3, §5.4 |
| `score_result.gd` `ScoreResult`, `TraceStep` | Trace contract | §5.4 |
| `encounter_state.gd` `EncounterState` | Summon-turn FSM + legality `can(verb)`; commands `toggle_select, reroll, bind, unbind, summon, attack_now, use_consumable`; Bell Ringer shackle; projected damage | §4.2–4.4 |
| `run_state.gd` `RunState` | Money, dice, relics (instances w/ counters, order), consumables, levels, night, encounter idx, equipment, bosses defeated, stats, run phase; `to_dict/from_dict` | §4.1, §7 |
| `night_gen.gd` `NightGen` | Mob/Champion/Boss picks, Enraged rules, equipment offer | §7.2, §6.9 |
| `economy.gd` `Economy` | HP per encounter, cash-out lines, interest, sell prices | §4.5, §6.10, §6.11 |
| `shop.gd` `ShopState` | Stock generation, buy / buy&use / sell / reroll, reroll cost per visit | §4.6 |
| `consumables.gd` `ConsumableFx` | Tome / Sigil / Ink / Spare Die application + targeting rules | §4.7, §4.8 |
| `save.gd` `SaveStore` | `user://run.json` (atomic write), `profile.json`, versioning, test dir redirect | §12.1 |
| `number_format.gd` `NumberFormat` | Short / full formatting | ART §8 |

### 2.2 Autoloads (few, dumb, preload-free)

`Display` (integer-scale canvas fit, D-A08), `Events` (signal bus §10.2), `Settings` (merged defaults), `Audio` (M5), `Game` (owns
`ContentDb`, current `RunState`, scene transitions, App FSM). Boot scene loads data after the
first drawn frame.

### 2.3 Scenes and UI (`scenes/`, `ui/`, `fx/`)

| Scene | Built from | Notes |
| --- | --- | --- |
| `boot/boot.tscn` | — | Preload-free; validates content; shows errors on screen |
| `title/title.tscn` | ART §6.5 | Continue (if save) / New Run / How to Play / Settings |
| `night_map/night_map.tscn` | ART §6.4 | 3 encounter cards, DEFEATED stamp, FIGHT |
| `encounter/encounter.tscn` | ART §6.2 | Top bar, relic bar, enemy zone, battlefield, score panel, essence row, dice tray, pending chips, status row, 4 action buttons |
| `shop/shop.tscn` | ART §6.3 | 3 item cards, equipment card, held consumables, reroll, dice strip, NEXT FIGHT |
| `end/game_over.tscn`, `end/victory.tscn` | §7.3 | Stats + New Run / Title |
| `overlays/*` | ART §6.6 | dice_inspector, cash_out, run_info (recipe book), settings, how_to_play, tooltip, confirm |
| `dev/sandbox.tscn` + `dev/presets.json` | — | Jump into any state (encounter with given dice/relics, shop with stock, big horde) |
| `dev/horde_test.tscn` | ART §9.2.6 | 60 / 240 sprite crowd test |

UI components (`ui/`): `pixel_button`, `die_view`, `group_chip`, `relic_slot` (drag reorder),
`consumable_slot`, `tooltip_panel`, `number_label`, `hp_bar`, `gesture.gd` (tap / long-press
/ drag thresholds), `overlay_stack.gd`. Theme: `ui/theme/pixel_theme.tres` from the 9-slices.

FX (`fx/`): `presentation_queue.gd` + `states/*.gd` (skippable, no `await`),
`combat_player.gd` (trace → timeline, compression to 6 s, speed ×1/×2/×4, tap-to-skip),
`horde_renderer.gd` (pool of 260 Sprite2D, visible-count curve, tiers, LEGION), shaders
`palette_swap.gdshader`, `flash.gdshader`, `dissolve.gdshader`, `outline.gdshader`.

### 2.4 Tools

| Tool | Purpose | Status |
| --- | --- | --- |
| `tools/check_data.py` | Validates data vs spec tables | ✅ |
| `tools/build_manifest.py`, `gen_placeholders.py`, `validate_art.py`, `palette.py` | ART §9 pipeline | ✅ (M0) |
| `tools/test.cmd` → `tests/_run.gd` | Headless suites, `--changed`, case filters | ✅ |
| `tools/run.cmd` | Run the game windowed | ✅ |
| `scenes/dev/display_probe.tscn` | Print scale / canvas for a `--resolution` | ✅ |
| `tools/balance_sim.gd` (+ `.cmd`) | Appendix A baseline (M1) and Appendix B run bot (M7) | M1 / M7 |
| `tools/screenshot.cmd` + `dev/capture.gd` | Sandbox preset → PNG | M2 |
| `tools/export_web.cmd` | Web export to `build/web` | M7 (smoke test in M2) |

---

## 3. Full game flow (screen ↔ state ↔ command)

```
BOOT ─data ok→ TITLE ─New Run→ RunState.new(seed) → NightGen(1) → NIGHT_MAP
NIGHT_MAP ─FIGHT→ EncounterState.new(run, encounter) ─(autosave)→ ENCOUNTER
ENCOUNTER: TURN_START(roll ROLL stream; Bell Ringer shackle BOSS stream)
           AWAIT_INPUT: select ⇄ reroll | bind | unbind | use consumable (inspector overlay)
                        projected = Scorer.score(army + pending)   # same scorer
           SUMMON → COMMIT (SUMMON-trigger counters, GOLD money) → TURN_END → next turn | COMBAT
           ATTACK NOW → COMMIT → COMBAT
COMBAT: result = Scorer.score(army) → state = RESULT immediately → CombatPlayer plays trace
        win → CASH_OUT overlay (Economy.cash_out lines; FIGHT_END relics) → SHOP (autosave)
             after Boss: bosses_defeated+1, night+1, NightGen(night) ; Night 8 boss → VICTORY
        lose → GAME_OVER (delete run save, update profile)
SHOP: buy / buy&use / sell / reroll / equipment / reorder relics / use consumables → NEXT FIGHT → NIGHT_MAP
TITLE ─Continue→ load run.json → route on saved phase (ENCOUNTER restarts from its start)
```

Each arrow is a command on the owning state object; each screen only calls commands and
reads `can_*`.

---

## 4. Milestones and tasks

Task IDs are referenced from commits / reviews. ✅ done · ⏳ in progress · ☐ todo.

### M0 — Scaffold (Day 1, Tue 10-20)

| ID | Task | Status |
| --- | --- | --- |
| M0-1 | Git repo + remote, `.gitignore`, `.gitattributes`, hooks, agent guide, skills | ✅ |
| M0-2 | `project.godot` per ART §2 (+ Compatibility renderer, custom user dir) | ✅ |
| M0-3 | Autoloads `Events/Settings/Audio/Game`; preload-free boot; Title placeholder | ✅ |
| M0-4 | All `data/*.json` transcribed from §6 + `check_data.py` | ✅ |
| M0-5 | Art manifest, palette, placeholder generator, validator | ✅ |
| M0-6 | Test runner + first suites (project settings, data load, recipes) | ✅ |
| M0-7 | Pixel theme from 9-slices; Fusion Pixel font (D-R05) | ✅ |
| M0-8 | Integer-scale display fit for non-16:9 windows (`Display` autoload, D-A08) + probe scene | ✅ |
| M0-9 | Switch to landscape 480×270 (D-A09): settings, DisplayFit, backgrounds 640×300, Title; ART_SPEC §6 layouts rewritten + wireframes (`docs/mockups/`) | ✅ (layouts approved) |

**Accept:** game boots to Title at 480×270 with integer scaling; `gen_placeholders.py`
creates every manifest file; `validate_art.py`, `check_data.py`, `tools\test.cmd` pass.

### M1 — Core rules (Days 1–2, 10-20 → 10-21)

| ID | Task |
| --- | --- |
| M1-1 | `RulesRegistry` + content test: every relic/consumable/equipment/boss row uses legal names; no unused registry entry |
| M1-2 | `Face`, `Die`, `Group`, `Recipes.resolve` + WILD resolution (§5.2, tie-break by unit table index) |
| M1-3 | `RelicEval` (conds, values with `per`, ops, counters, multi-block), `ScoreCtx` |
| M1-4 | `Scorer` + `TraceStep`; `round_half_up` helper; EXORCIST, WITCH_HUNTER in scorer |
| M1-5 | `RngStreams`; `EncounterState` FSM + legality table + commands; Bell Ringer; Inquisitor summons |
| M1-6 | `RunState` skeleton (enough for scorer/encounter: money, dice, relics, levels, bosses defeated) |
| M1-7 | `tools/balance_sim.gd`: Appendix A bot (partitions, greedy) in GDScript over core classes |
| M1-8 | Tests: §5.5 three fixtures; HEX rounding 3→5; 21 pairs / 4 triples / 52 invalid; WILD picks T3; encounter SM guards (§14); determinism: same seed ⇒ identical 100-turn bot log |

**Accept:** fixtures pass (2520 / 2450 / 1620); sim within ±5% of §5.6 (reference Python run
on 2026-10-20: mean 1579, median 1513, p10 924, p90 2346 — seed 1, 20k trials); all recipes
resolve; determinism log identical.

### M2 — Encounter playable (Days 3–4, 10-22 → 10-23)

| ID | Task |
| --- | --- |
| M2-1 | `pixel_theme.tres`, `pixel_button`, `number_label` (+ `NumberFormat` tests) |
| M2-2 | Encounter scene layout per ART §6.2 (regions anchored, containers inside; battlefield takes extra height) |
| M2-3 | `die_view` (body, glyph, modifier badge, select/bound/shackle overlays, roll anim 4×50 ms), tray container |
| M2-4 | `gesture.gd`; tap select, BIND/REROLL/SUMMON/ATTACK NOW wired to commands, `disabled` from `can()` |
| M2-5 | Pending group chips (tap = unbind), confirm overlay "Summon nothing?" |
| M2-6 | Score panel (projected P × C = dmg / HP; ≥ HP → `L2`), essence row, HP bar with projected segment |
| M2-7 | Enemy zone (sprite on pedestal, name, rule chip, HP), relic bar (static), top bar |
| M2-8 | Basic combat result: score → immediate win/lose banner (no horde yet) |
| M2-9 | Sandbox + presets; screenshot runner; web export smoke test on a private itch.io draft page (embed 960×540, fullscreen) |
| M2-10 | Test: projected damage == final damage for scripted encounters (property test over seeds) |

**Accept:** a full encounter can be played and won/lost on Web; projected = final every time.
**Then:** first human playtest (record per game-design-review procedure step 5).

### M3 — Run loop (Day 5, 10-24)

| ID | Task |
| --- | --- |
| M3-1 | `RunState` complete + run phase FSM; `NightGen` (boss rules, no repeat, Night 1 pool, Enraged) |
| M3-2 | Night Map scene; HP from `Economy.hp_for` |
| M3-3 | Cash-out overlay from `Economy.cash_out` lines (interest before payout; unused summons) |
| M3-4 | `ShopState` (weights, rarity, no dup, prereqs, reroll cost per visit, Haggler) + Shop scene |
| M3-5 | Consumables: Tome levels, Sigil/Ink via Dice Inspector overlay (target limits), Spare Die timing; usable in shop + AWAIT_INPUT |
| M3-6 | Equipment effects (dice, summons, rerolls, slots, reroll discount) |
| M3-7 | Game Over / Victory screens + run stats (best damage, most-summoned unit) |
| M3-8 | Debug flags: HP override, money, force shop item (not saved) |

**Accept:** a 24-encounter run completes with debug HP override; money math matches §4.5
(table tests).

### M4 — Content complete (Day 6, 10-25)

| ID | Task |
| --- | --- |
| M4-1 | One isolated scorer fixture per relic (25), incl. Black Grimoire ×1 step, Copycat, Overgrowth counter persistence + sell loses it |
| M4-2 | Fixture/scenario per consumable (18), equipment (8), boss rule (4 + Enraged) |
| M4-3 | Relic drag-reorder (Encounter + Shop; not during playback) → one `reorder` command |
| M4-4 | Tooltips (tap / long-press / hover) for relic, consumable, unit chip, rule, die |
| M4-5 | Witch Hunter disabled-relic look; Bell Ringer shackle overlay; Inquisitor summon count |

**Accept:** every relic / consumable / equipment / boss has a test or scripted scenario.

### M5 — Horde, playback, juice, art, audio (Days 7–8, 10-26 → 10-27)

| ID | Task |
| --- | --- |
| M5-1 | `presentation_queue` + states; `combat_player` timeline (§11.4), compression to 6 s, speed, tap-skip |
| M5-2 | `horde_renderer`: pool 260, visible curve §11.1, tiers §11.2, placement §11.3, LEGION banner |
| M5-3 | Palette-swap shader (Wisp mask + minis), flash, dissolve, Enraged outline + aura |
| M5-4 | Juice per ART §10 (summon pop, clone burst, lunge waves, slam, shake) with reduce-motion profile |
| M5-5 | Final art integration as delivered (anchors approved first, ART §9.2) — files replace placeholders 1:1 |
| M5-6 | Audio: SFX set, rising-pitch counter ticks (+1 semitone/step, cap 12), music after first tap |
| M5-7 | Perf: horde_test at 240 sprites ≥ 55 fps in a desktop browser (integrated GPU laptop), playable on a mid-range Android browser; MultiMesh only if not |

**Accept:** Night 6+ army with C ≥ 10,000 renders ≤ 240 sprites at ≥ 55 fps in a desktop
browser on an integrated-GPU laptop; playback ≤ 6 s at ×1.

### M6 — Persistence, settings, onboarding (Day 9, 10-28)

| ID | Task |
| --- | --- |
| M6-1 | `SaveStore`: atomic run save at encounter start + shop entry; profile; Continue routes on phase |
| M6-2 | Settings overlay (§12.2) persisted in profile |
| M6-3 | Tutorial coach marks (5, first run only, dismissable) |
| M6-4 | How to Play (4 pages, images captured from the game), Run Info recipe book (6×6 matrix + triples + level table) |

**Accept:** kill the tab mid-shop → Continue restores identical state (hash equal).

### M7 — Balance, QA, ship (Day 10, 10-29)

| ID | Task |
| --- | --- |
| M7-1 | Appendix B bot over 1,000 runs; tune `curve.json` / prices only in data |
| M7-2 | QA pass: no console errors; test matrix (desktop Chrome / Firefox / Edge / Safari, itch.io embed + fullscreen, then Chrome Android / Safari iOS landscape) |
| M7-3 | Web export preset (Thread Support off, Compatibility, `index.html`), `tools/export_web.cmd` → zip (< 1,000 files); itch.io page: Embed in page 960×540, fullscreen button, Click to play, Mobile friendly (landscape); app icon, version footer |

**Accept:** bot reaches Night 4 in ≥ 50% and wins ≤ 15% of 1,000 runs; no console errors.

Day 11 (10-30): buffer / launch. Halloween 10-31.

---

## 5. Test plan (maps to GAME_SPEC §14)

| Suite | Covers |
| --- | --- |
| `test_project` | Display/import settings |
| `test_data` | Content loads, recipe table, int narrowing |
| `test_registry` (M1) | Every data row legal; no unused DSL term |
| `test_recipes` (M1) | Matrix §6.3, 52 invalid triples, WILD |
| `test_scorer` (M1, M4) | §5.5 fixtures, HEX rounding, per-relic fixtures, trace last step == result |
| `test_encounter` (M1) | FSM guards, shackle, Attack Now, projected == final |
| `test_determinism` (M1, M3) | Same seed + script ⇒ same log / run hash after 3 Nights |
| `test_shop`, `test_economy` (M3) | No dup relic, prereqs, sell prices, reroll cost, cash-out lines |
| `test_save` (M6) | Round trip equality; Continue mid-encounter restarts with same RNG |
| `test_number_format` (M2) | Boundaries |
| `test_presentation` (M5) | Skip before/mid/after → final look, `finished` once |
| `balance_sim` (M1, M7) | §5.6 baseline; Appendix B run stats |

Evidence kinds stay separate (game-design-review rule 2): tests = correctness, sim = balance
pattern, playtest notes = fun.

---

## 6. Risks and mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| 11 days to Halloween, no slack | Miss the trend | Critical path §8; cut list §7; human playtest at M2, not later |
| `aspect=expand` + `scale_mode=integer` engine bug (godot#92055) | Jumping / inconsistent letterbox on resize | **Resolved in M0** (D-A08): aspect `keep` + `DisplayFit` canvas size; re-check in the itch.io embed + fullscreen in M2 |
| Layout proposal rejected late | Rework of every screen | Approve ART_SPEC §6 wireframes before M2 starts (M1 is pure logic, unaffected) |
| Web perf with 240 sprites + tweens | Choppy climax on phones | Pool from day one; perf check early in M5; MultiMesh fallback |
| Final art not ready | Ship with placeholders | Placeholder pipeline passes validator; art swaps 1:1; anchors approved first |
| Font coverage | Fusion Pixel subset is Latin only | **Resolved in M0** (D-R05, OFL); re-subset only if Vietnamese localization is pulled in |
| Night 8 HP (×110 baseline) unreachable or trivial | Curve wrong | M1 sim baseline; M7 Appendix B bot tuning in data only |
| One-loss-ends-run feels punishing | Low retention | Projected damage always visible + Attack Now; watch in M2/M3 playtests (design question, not code) |
| Mobile cold start | Blank screen seconds on low-end | Preload-free boot (done); keep autoloads light |

---

## 7. Cut list (in order, if a milestone slips)

1. Discovery-gated recipe book, endless, seed entry (already stretch).
2. WILD cycle-in-chip (stretch §5.2).
3. Enraged aura VFX → red modulate only.
4. How-to-Play images → text pages.
5. Clone-burst per sprite → per group.
6. Music → SFX only.

Never cut: projected damage, recipe book, save/continue, tap tooltips, determinism.

---

## 8. Critical path

`ContentDb → Recipes → RelicEval/Scorer → EncounterState → Encounter screen → RunState/Shop →
Save → Web export`. Horde/juice (M5) and onboarding (M6) hang off it and can be parallelised
once M2 lands (separate files: `fx/` vs `scenes/overlays/`).

---

## 9. Progress log

| Date | Done |
| --- | --- |
| 2026-10-20 | M0: repo + remote, skills (reused 6 from necwarband/necdrawmancer, added 4), agent guide, project.godot, autoloads, boot, data JSON + checker, art pipeline + 169 placeholders (`ART OK`), test runner (8 cases green), Title renders at 270×480 (movie-maker capture). Appendix A baseline reproduced in Python. |
| 2026-10-20 | Display switched to `keep` + integer + DisplayFit (D-A08, probe-verified); Fusion Pixel font (D-R05); 13 cases green. |
| 2026-10-20 | Switched to landscape 480×270 + itch.io-first (D-A09, D-A10): settings, DisplayFit (both axes, ≤ 640×300), 640×300 backgrounds, Title relayout, ART_SPEC §6 rewritten with wireframes; 12 cases green. |
