---
name: roguelike-run-economy
description: The run around the fights in a Godot 4 roguelike / roguelite — run and encounter state machines, seeded named RNG streams, shop stock generation (weighted categories, rarity, no duplicates, rerolls with rising cost), buy / sell / use, money and interest, permanent upgrades with prerequisites, difficulty curves, checkpoint saves that resume deterministically, and headless balance-simulation bots. Use when building or changing the run loop, map / encounter flow, shop, rewards or cash-out, consumables, upgrades / vouchers, enemy or boss selection, HP or difficulty curves, save / continue, determinism or seed bugs ("same seed, different run"), or when tuning balance with a simulation bot.
---

# Roguelike Run Economy

Owns *the loop between fights*: what the player earns, buys and carries, how the run is
seeded and saved, and how balance is measured. The scorer is `roguelike-scoring-pipeline`;
layer placement is `godot-architecture`; whether a tuning change is the right next step is
`game-design-review`. The project spec names prices, weights and curves — they live in data.

## Rules

1. **Run state is one serialisable object.** Money, dice/deck, items (with counters), held
   consumables, unit levels, night/ante, encounter index, owned upgrades, RNG stream states,
   and the **run phase** (map, encounter, shop). Saving is `to_dict()`; loading routes on the
   stored phase, never on which `pending_*` fields happen to be set.
2. **Named RNG streams, one per concern.** Derive each stream's seed from
   `hash(run_seed + ":" + name)` (e.g. `ROLL`, `SHOP`, `ENEMY`, `BOSS`) and save each
   `RandomNumberGenerator.state`. Rerolling the shop must not change tomorrow's dice; a
   new feature that draws randomness gets its own stream rather than borrowing one.
3. **Generate on entry, store the result.** A night's enemies, a shop's stock, the boss rule
   are rolled once when that screen's state begins and stored in run state. Reloading shows
   the same stock; re-entering never re-rolls.
4. **Checkpoint saves at state boundaries** (encounter start, shop entry). Quitting
   mid-encounter resumes the encounter from its start with the same RNG state — so the save
   must be written *before* the first roll. Delete the run save on game over / victory; the
   profile (records, settings, tutorial flags) is a separate file.
5. **Commands own every mutation.** `buy(slot)`, `sell(item)`, `reroll_shop()`,
   `use(consumable, targets)` validate (money, free slot, legality), mutate, emit. Buttons only
   reflect `can_buy(slot)`; the same checks run in the command, so a stale button cannot cheat.
6. **Weighted picks are explicit and exclusion-aware.** Category by weight → item by rarity
   weight → exclude owned and already-offered ids → re-pick from the remaining pool (not
   "retry until different", which can loop). Empty pool → a defined fallback.
7. **Money math is a table, tested line by line.** Reward per role, unused-action bonus,
   interest computed on money **before** the payout, end-of-fight item payouts — one function
   returns the list of lines the cash-out screen shows; the screen sums nothing itself.
8. **Curves are data: base per tier × role multiplier.** Store the base per night and the
   multipliers; compute HP in one function. Special rules that change the multiplier are data
   on the rule.
9. **Balance is measured by bots through the real commands.** A headless bot drives the same
   run/encounter commands a player uses (with a policy from the spec), over N seeded runs,
   and reports distributions (reach night k %, win %, damage percentiles, money at shop).
   Bot results are balance evidence, not fun evidence (`game-design-review`).
10. **Debug overrides are explicit run flags** (HP ×0.01, infinite money, force shop item),
    set from a debug menu or sandbox preset, saved nowhere, and never read by content code.

## Balance loop that converges

1. Report **where runs die**, not only how far they get: deaths by (night, role, rule) and mean
   damage / HP per night. One rule dominating the deaths is a pricing error, not a curve error.
2. Price each boss rule's HP multiplier by how much it weakens the army (a rule removing a
   quarter of the dice can cut damage to a third — groups, not dice, are what scale). A boss
   with two rules multiplies both prices.
3. Change only data; keep tests and checkers on the *formula* (base × multiplier) and on sane
   ranges, never on tunable numbers, or every tuning pass breaks the suite.
4. Confirm on 1,000 runs with a fixed seed and log the before/after numbers with the decision.

## Procedure — adding a shop item kind, reward or upgrade

1. Data row (+ registry entry for its kind); content test passes.
2. Command for acquiring/using it with its `can_*` guard; test the guard and the effect.
3. Shop generator: weight, exclusion and pool-empty cases tested with a fixed seed.
4. Save round-trip test still equal; determinism test (same seed + scripted inputs → same
   run-state hash after k encounters) still passes.
5. Re-run the balance bot; compare against the last recorded distribution in the project doc.

## Routing

- Stream table, save layout, determinism test and the balance-bot harness →
  [references/rng-save-sim.md](references/rng-save-sim.md)

## Traps

| Trap | Symptom | Fix |
| --- | --- | --- |
| One global RNG / `randi()` | Same seed diverges after an unrelated feature draws a number | Named streams with saved state |
| Shop rolled in `_ready` of the shop scene | Reload / re-enter shows different stock (save-scum) | Roll on state entry, store in run state |
| Save written after the first roll | Continue gives a different first roll than the one quit on | Save at the boundary before any randomness |
| Iterating a `Dictionary` built in a different order | Same seed, different pick after a refactor | Iterate sorted ids / arrays in pick code |
| Interest computed after rewards | Off-by-one money every fight; players notice | Snapshot money before payout |
| "Retry until not owned" | Hang when the pool is exhausted late in a run | Filter the pool, then pick; handle empty |
| Reroll cost not reset per visit | Shop reroll gets expensive forever | Cost counter lives in the shop visit state |
| Bot that calls internal functions | Bot passes while the real UI path has a bug | Bot uses the same command API as the UI |
| Debug HP override left in a save | Real runs load with ×0.01 HP | Debug flags are not serialised |
