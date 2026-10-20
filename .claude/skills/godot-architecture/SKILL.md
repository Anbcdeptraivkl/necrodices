---
name: godot-architecture
description: Architecture rules, established patterns and anti-patterns for Godot 4 game code (GDScript or C#) — layered state machines, model/view separation, signals, autoloads, data-driven content, save/run state, file and function size limits. Use when designing or adding a system, script, scene or autoload; refactoring; reviewing code; deciding where logic belongs; building a mechanism that may already have a known pattern; or when a change keeps breaking unrelated behaviour.
---

# Godot Architecture

Owns *where code goes and how systems talk*. Not rendering (`godot-pixel-art-rendering`),
not scoring rules (`roguelike-scoring-pipeline`), not run economy (`roguelike-run-economy`),
not animation sequencing (`godot-presentation-playback`), not tests (`godot-debugging-testing`).

## The target shape: state machines in layers, plus a presentation queue

A game of this kind is state machines stacked on each other. Make each one explicit:

| Layer | Owns | Pattern |
| --- | --- | --- |
| **Meta** | profile, unlocks, achievement points across runs | Persisted data + flat FSM for menus |
| **Run / Campaign** | overworld → battle → rewards → settlement → end; what a save resumes into | Flat FSM (enum + one transition function), **phase persisted in the save** |
| **Battle** | deploy → fight → rout/pursuit → aftermath → result; which commands are legal | Flat FSM + legality table (`can(verb)`) |
| **Interaction** | selection, order targeting, menus with Back / confirm / cancel | Pushdown automaton (stack of states) |
| **Presentation** | playing out what the model already decided | Event queue / sequencer |

**Direction of knowledge:** a lower layer never reads an upper one. Interaction asks Battle
"may I issue this order?"; Battle never asks whether a menu is open. Presentation never
mutates the model.

## Rules

1. **Model / view split.** Simulation and rules are plain objects or data-owning nodes with
   no rendering; views read model state and emit intents. A view never mutates the model —
   it calls a command method that validates, mutates and emits.
2. **Call down, signal up.** Parents call children's methods; children emit signals; the
   owner decides what a signal means. Siblings talk through their parent or an event bus,
   never `get_node("../..")`.
3. **One implementation of a rule.** A preview, forecast, AI evaluation or auto-resolve runs
   the *same* rules code on a copy — never a second model of the rules. A second model
   drifts on day one.
4. **Content is data.** Units, items, spells, factions, events are rows (`Resource`s or JSON)
   read by one interpreter; legal ids/ops live in a single const registry that a test checks
   every row against. Unknown data is `push_error`, never a silent skip.
5. **Explicit state beats flags.** When two booleans describe one situation, it is a state
   machine. A phase is one enum value; derived facts are read-only properties.
6. **Autoloads are few and dumb.** Use them for services with one instance (save, audio,
   event bus, content database). Game state that has a lifetime (a run, a battle) is owned by
   a node or object with that lifetime, not by a global. Look autoloads up through one helper.
7. **UI is authored in scenes.** Layout, colours and component structure live in `.tscn` and
   theme/palette resources; code fills data and toggles visibility. One source of truth for
   geometry.
8. **Size limits** (starting defaults; the project doc may change them): **500 logic lines per
   file, 50 per function, 10 branches per function**. Tripping one means extract a
   responsibility, not split arbitrarily.
9. **Typed boundaries.** Typed GDScript (`var hp: int`, typed arrays) everywhere; no new
   free-text dictionary keys read in more than one place — use a typed object or a `const` key.
10. **Comments state the current rule and why it is not obvious.** History belongs in git.

## Procedure — before building a mechanism

1. Name the problem in engineering terms. Check [references/patterns.md](references/patterns.md);
   if listed, use that pattern.
2. If not listed, look up the established answer (Nystrom's *Game Programming Patterns*, the
   Godot *Best practices* docs, how a shipped game in the genre does it) before inventing one.
   Add the new row to the project's pattern catalogue in the same change.
3. Decide the layer (table above) and the owner. If the owner is an existing god object,
   extract first — see [references/anti-patterns.md](references/anti-patterns.md).
4. After the change: nothing in the anti-pattern register got worse.

## Routing

- Pattern catalogue (problem → pattern → rule) → [references/patterns.md](references/patterns.md)
- Anti-patterns with the bug class each produces and its replacement → [references/anti-patterns.md](references/anti-patterns.md)
- Setting up a project's own debt register and a ratcheting rule checker → [references/audit-and-ratchet.md](references/audit-and-ratchet.md)

## Primary references

1. Robert Nystrom, *Game Programming Patterns* — https://gameprogrammingpatterns.com/contents.html
2. Godot docs, *Best practices* — https://docs.godotengine.org/en/stable/tutorials/best_practices/index.html
