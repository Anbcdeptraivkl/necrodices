---
name: game-design-review
description: Reviewing game design before it grows — stating the player promise, separating engineering / simulation / human-play evidence, researching reference games, spotting warning signs, choosing the smallest next test with a stop criterion, and checking real-time action combat for depth. Use when researching reference games, proposing or adding a system or content, planning the next milestone or prototype, closing a prototype with keep / change / cut, reviewing a playtest, when a mechanic "will be fun once X is added", when a feature is justified mainly by a reference game, when combat feels clunky, shallow or solved by one routine (kiting, spam, dodge), or when docs and tunings grow faster than play evidence.
---

# Game Design Review

This skill owns *whether the next piece of work is the right one*: the promise, the evidence,
and the smallest test that could change our mind. It does not cover how to build systems
(`godot-architecture`, the system skills) or how to run tests (`godot-debugging-testing`).
The project's own promise, loop and decisions live in its design docs; this skill holds the
questions to put to them.

## Rules

1. **State the promise as a playable moment.** "The player does ___, sees ___, and feels
   ___." A list of genres or systems does not identify the payoff, so it cannot be tested.
2. **Keep three kinds of evidence apart.** Engineering tests prove correctness, simulations
   and bots reveal balance patterns, human play proves understanding and enjoyment. None
   stands in for another; a bot that dodges perfectly says nothing about how it feels.
3. **Every prototype has one question, pass criteria, a timebox — and ends in a written
   keep / change / cut.** "Ok for now" is not a decision; a timebox that passes without one
   is the sunk-cost trap starting.
4. **Default rescue budget: two focused experiments, each changing one axis.** Extend only for
   concrete new evidence, never because work is already invested.
5. **No polish (final art, juice, frame timings, fine balance) before the loop around it
   plays.** What makes a part fun is what it feeds and consumes; polishing it in isolation
   optimises the wrong thing.
6. **A borrowed mechanic brings its supporting constraints, or it fails.** Before copying a
   reference, name what else in that game makes the mechanic work, and test those here.
7. **Variety must change behaviour.** A new enemy, unit, item or reward earns its place only if
   it changes what the player prioritises or does — not names and bigger numbers.
8. **The next addition has a job.** Name the observed problem it fixes, its cost (rules, UI,
   content), and what it replaces or improves.
9. **Respect explicit scope.** Report untested assumptions and warning signs; never invent
   playtest results or silently widen the task.
10. **Version the reference evidence.** Record the game, edition / DLC and source date;
    distinguish developer intent, released mechanics and player reports. Check later official
    changes before treating an old complaint or feature list as current. A reference is
    evidence about its own rules, not proof that the adaptation will be fun.

## Procedure — before adding a system or planning a milestone

1. Fill the experiment block (copy it into the review):
   ```text
   Player promise: The player does ___, sees ___, and feels ___.
   Core loop: ___ → ___ → payoff → repeat.
   Biggest untested assumption:
   Smallest playable test, deadline, evidence that would change our mind:
   ```
2. Walk the checklist; attach an observed example to each answer (unchecked = unknown, not
   failed):
   - [ ] **Payoff exists now** in the current build (for build / synergy games: give a strong
         combination early to test it).
   - [ ] **Actions matter**: input or preparation visibly connects to the result; different
         situations make different plans useful.
   - [ ] **Fantasy matches rules**: named actions (grow, upgrade, sacrifice, "powerful") feel as
         intended; hidden tradeoffs do not undermine the promise.
   - [ ] **Variety changes behaviour.**
   - [ ] **Interaction earns its time**: reading, clicks, waiting support a decision or
         satisfying feedback — test one ordinary loop through real input.
   - [ ] **Players show interest**: a memorable moment, an unprompted retry, curiosity about
         another approach (voluntary play, not a testing assignment).
   - [ ] **The next addition has a job** (rule 8).
3. Check the warning signs in [references/warning-signs.md](references/warning-signs.md).
4. Decide with the evidence table there (expand one dimension / fix readability / change the
   central interaction / shelve), set the budget, and write the decision where the project
   logs decisions.
5. Keep the playtest record short:
   ```text
   Build / date / players:
   Memorable moment and voluntary replay behaviour:
   Friction or repeated routine:
   Fact / hypothesis:
   Next single change / success or stop criterion / deadline:
   ```

## Routing

- Reference-game research, source checks and transferable design conclusions →
  [references/reference-research.md](references/reference-research.md)
- Warning signs, their checks, and the next-step table → [references/warning-signs.md](references/warning-signs.md)
- Real-time action combat feels clunky, shallow or solved (kite, spam, dodge) →
  [references/action-combat-depth.md](references/action-combat-depth.md)

## Traps

| Trap | Symptom | Fix |
| --- | --- | --- |
| Bot evidence read as fun evidence | Reports say "pass" from headless bots; nobody has written how it felt | Schedule a human session with the playtest record before more tuning |
| Fast building outruns playtesting | Several prototypes sit at "built, awaiting playtest" while new ones start | Stop starting; batch the playtest and write keep / change / cut for each |
| Scope creep inside a prototype | The question was X, the decisions are about Y, Z and pixel / millisecond tunings | Re-read the question; close it, open a new prototype for the rest |
| Half a reference | The defensive half of a game's combat is copied (tells, dodge, low HP) but not the offensive half that forces engagement | Rule 6: list what makes it work there; take the pair or neither |
| Decision log as a changelog | Entries are mostly numbers that belong in data | Log the why and what is ruled out; numbers live in data |
| Old reference material treated as current | A recommendation fixes a feature the reference has since changed | Check edition / DLC / patch scope; separate the historical problem from the current design |
