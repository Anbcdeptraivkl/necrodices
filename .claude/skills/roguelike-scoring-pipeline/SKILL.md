---
name: roguelike-scoring-pipeline
description: Ordered, data-driven scoring for Balatro-style roguelikes in Godot 4 — additive and multiplicative running totals (chips × mult, power × count), per-item effects resolved left to right, an effect/condition DSL interpreted from JSON, a score trace that presentation replays, previews that run the same scorer, rounding and big-number rules, and fixture-based tests. Use when building or changing a scorer, adding a relic / joker / modifier / boss rule, writing or extending an effect DSL, wiring projected damage or score previews, deciding trigger timing (per group, final, on commit, end of fight), seeing a preview disagree with the result, order-of-effects bugs, rounding drift, or scores that overflow or format badly.
---

# Roguelike Scoring Pipeline

Owns *how a score is computed and explained*: the pipeline, the effect language, the trace
contract and the tests that pin them. Where the scorer lives in the code base is
`godot-architecture`; how the trace is animated is `godot-presentation-playback`; the run
around it (shop, money, RNG) is `roguelike-run-economy`. The project's game spec names the
items, numbers and order.

## Rules

1. **One pure scorer.** `score(board, run, encounter) -> ScoreResult{total, a, b, trace}` is a
   static function on plain data (`RefCounted`, no `Node`, no RNG). Projected damage,
   AI/bot evaluation, the real combat and the tests call this same function. A second "quick
   estimate" drifts from the rules the first time an item is added.
2. **Previews never fire side effects — but they simulate them.** Commit-time effects
   (counters, money from a face) happen in the commit command, not in `score()`. A preview
   applies those same commit effects to *copies* (relic counters, money, summons left − 1) and
   scores `board + pending`, so the projection equals the result of attacking now while the
   run stays untouched.
3. **Order is the rule, so make it explicit data.** Groups resolve in commit order; within a
   group: base → face modifiers in tray order → items left to right; then final items left to
   right. Order-sensitivity (`+` before `×` vs after) is the player's main decision; test it
   with a swapped-order fixture.
4. **Round at the operation, not at the end.** Each `×` rounds half up to an integer
   immediately (`floor(x + 0.5)`, not `round()` — banker's rounding differs in some engines
   and languages). Running totals stay integer-valued in a 64-bit float; damage =
   `floor(a × b)`. Rounding at the end gives answers players cannot reproduce by hand.
5. **Effects are data in a tiny DSL, interpreted in one place.** An item row is
   `{trigger, cond, effects[]}` (or `blocks[]` when one item triggers at two moments).
   Values are a number or `{base, per: <source>, step}`. Legal triggers, ops, conditions and
   sources live in **one const registry**; a content test checks every row against it and
   the loader `push_error`s unknown names. New behaviour = a new op/cond in the registry +
   its test, never an `if id == "X"` branch in the scorer.
6. **Conditions read a context snapshot built before resolution.** Whole-board facts
   (element essence, group count, money, rerolls left) are computed once into a `Ctx`;
   per-group facts come from the group. An item never reads live UI or run nodes.
7. **The trace is the contract with presentation.** Every change to a running total appends a
   step `{kind, group_index, source_id, op, value, a_after, b_after, label}`, including
   no-op steps the design wants shown (an item at ×1 "charging"). Presentation replays the
   trace verbatim and never re-evaluates a condition; the last step equals the result.
8. **Disabled ≠ removed.** A boss rule that disables an item marks the instance for this
   encounter; the scorer skips it and emits no step, the UI greys it. Removing it from the
   list shifts every "leftmost / first" rule after it.
9. **Persistent counters live on the item instance** (run state), increment only in their
   trigger's command (e.g. on commit), are saved with the run and die with the item when sold.
10. **Fixtures before features.** The spec's worked examples become test fixtures verbatim
    (input board, items in order, expected total) before the UI exists; each item gets one
    isolated fixture. A statistical baseline (mean / median / p10 / p90 of a simple bot over
    N trials, fixed seed) catches recipe or scorer regressions no single fixture covers.

## Procedure — adding an item, modifier or boss rule

1. Express it in the existing DSL. If it does not fit, add the smallest new op/cond/source
   to the registry (and the spec's DSL list), with a fixture for the new term alone.
2. Add the data row; run the content test (every row validated against the registry).
3. Add its isolated fixture: minimal board, the item alone, expected trace labels and total.
   If it is order-sensitive, add the swapped-order case.
4. Check the preview: a test that `score(board + pending)` before commit equals the combat
   result after commit for the same inputs (with commit-time effects excluded or applied).

## Routing

- DSL shape, registry, evaluation order and trace step reference →
  [references/dsl-and-trace.md](references/dsl-and-trace.md)

## Traps

| Trap | Symptom | Fix |
| --- | --- | --- |
| Projected number computed by a second function | Preview says win, combat says lose, after a new item | Preview calls `score()`; a test compares preview vs result |
| Commit-time counters incremented inside `score()` | The counter climbs every time the preview refreshes | Counters change only in the commit command |
| `round()` for ×1.5 | 2.5 → 2 on one platform, 3 on another; fixtures fail by 1 | `floor(x + 0.5)` in one helper |
| Integer `int` totals | Overflow / wrap past 2^63 in late game, or float→int warnings from JSON | 64-bit floats for totals, integer-valued by rounding; format for display only |
| JSON numbers loaded as floats | `price 4` shows as `4.0`, `==` with ints surprises | Narrow whole floats to int in the loader for id/price/count fields |
| `if relic.id == "X"` in the scorer | Every new item touches the scorer; ordering bugs per special case | New op/cond in the registry |
| Removing a disabled item from the list | "Leftmost item" boss rule hits the wrong item after re-order | Disable flag on the instance for the encounter |
| Trace re-derived in the view | The animation shows numbers the scorer never produced | View plays `trace` only; assert last step == result in a test |
| Wild / choice faces resolved in the view | Preview and result pick different units for the same dice | Resolution (max-tier, deterministic tie-break) is part of the rules module and stored on the group |
