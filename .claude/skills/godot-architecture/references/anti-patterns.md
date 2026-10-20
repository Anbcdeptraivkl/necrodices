# Anti-patterns

Each entry: the smell, the bug class it produces, and what replaces it. Severity is **bug
risk**, not ugliness. Policy: *fix when touched* — none of these justify a rewrite on their
own, but a change touching the code moves it the right way and never makes it worse.
Exception: High items that are live bug sources are worth scheduling.

## Logic

| # | Smell | Severity | Bug class | Replace with |
| --- | --- | --- | --- | --- |
| L1 | **Implicit state machine** — phase implied by `result == ""`, `turn == "player"`, several `pending_*` fields | High | Actions legal in the wrong phase; guards drift apart | Enum phase, one `_enter()`, `TRANSITIONS` + `LEGAL` tables, `can(verb)` |
| L2 | **Unpersisted run phase** — the save stores data but not *where* the player was | High | Quit on a reward screen → resume before the fight, reward lost or duplicated | Persist the phase; route scenes on phase change; autosave on phase exit |
| L3 | **Silent data failures** — unknown op/id/key skipped with a warning or default | High | Content that "works" but does nothing | Const registries, a content test over every row, `push_error` on unknown |
| L4 | **God object** — one manager/scene owns phase, economy, rendering, input, saves | Medium | A change for one responsibility breaks another sharing its variables | Extract by responsibility into small owners when touched; size limits |
| L5 | **View mutates the model** | Medium | Rules bypassed; forecasts disagree with play | Command methods on the model that validate, mutate, emit |
| L6 | **Stringly-typed view state** — `get_state()` dictionaries read with `.get("key", default)` | Medium | A misspelt key renders plausible wrong numbers | Typed snapshot objects or `const` keys |
| L7 | **Presentation concurrency through flags** — `_playing`, `_x_running`, `while flag: await` | Medium | Each new animation adds an ordering rule; races | One presentation queue (event queue of animation states) |
| L8 | **Hidden dependencies** — duplicated `get_node("/root/X")`, duck typing via `has_method` | Medium | A rename silently turns a feature off | One lookup helper; typed services object passed in |
| L9 | **Global mutable static** used as a rules switch | Low | A failing test leaves later tests on the wrong rule | A parameter with the shipped default |
| L10 | **Type-flag branching** — `if unit.is_player` inside shared rules | Low | Rules scatter; the second branch is the warning sign | Move the rule onto the type (polymorphism / data) |
| L11 | **Parked code kept compiling** | Low | Maintenance of dead paths; false test coverage | Delete; tag the last build that had it |
| L12 | **Comments as changelog** | Low | Comment contradicts code | State the current rule; history in git |

## Layout / UI

| # | Smell | Severity | Bug class | Replace with |
| --- | --- | --- | --- | --- |
| U1 | **Geometry with two sources of truth** — scene offsets overwritten by code constants | Medium | Editing the scene does nothing; docs drift | Containers compute layout, or one geometry resource read by scene, code and tests |
| U2 | **Near-identical views duplicated** | Medium | Every fix made twice, one forgotten | Shared component scenes instanced by both |
| U3 | **UI built in code** (`HBoxContainer.new()`…) | Low | Unreviewable layout, no editor preview | A row/component `.tscn` |
| U4 | **Copy-pasted input handling** (press/tap tests in N scripts) | Low | Inconsistent input behaviour | One static helper; a modal overlay base scene |
| U5 | **Literal colours outside the palette** | Low | Inconsistent theme, contrast bugs | Palette / theme tokens |
| U6 | **Component internals placed from outside** | Low | Parent breaks when the component changes | Variant expressed in the component's own scene |

## Measuring

A project should have a scanner that counts these (file size, function size, branches,
repeated guards, UI-in-code, literal colours, `await` outside presentation states, autoload
reaches) and a ratchet that stops them growing — see `audit-and-ratchet.md`.
