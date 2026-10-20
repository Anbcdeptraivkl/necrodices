# Pattern catalogue

Established patterns and the one-line rule that keeps each honest. A project keeps its own
`docs/engineering_patterns.md` with the same columns plus **Where** (the classes/files that
implement it here); this list is the general starting point.

| Problem | Pattern | Rule |
| --- | --- | --- |
| Multi-step player decisions with Back / confirm / cancel (select → order → target) | **Pushdown automaton** | Back = pop, commit = clear the stack; nothing is spent before commit |
| Game phases (run, battle) and which actions are legal in each | **Flat FSM + legality table** | One enum value; one `_enter()` that owns entry work; `TRANSITIONS` table; every verb asks `can(verb)`. Test it as a table |
| Where a save resumes | **Persisted FSM phase** | The snapshot stores the phase; loading routes on it. Never infer the phase from `pending_*` fields |
| A prediction that must match the real outcome (forecast, AI scoring, auto-resolve) | **One implementation, run on a shadow copy** | Never a second model of the rules |
| A preview and an effect reading one rule (area highlight vs hit area) | **Shared pure function** | Same argument as above, at the size of one function |
| Units, items, spells, events as content | **Type Object + data-driven effect ops** | Content rows in data; one interpreter; a const registry of legal ops/ids validated by a test |
| Player orders, AI orders, replays | **Command** | Orders are objects queued into the model at a tick/turn boundary; player and AI use the same commands |
| Decoupled reactions to game happenings (achievements, audio, logs, UI) | **Observer** (signals / event bus) | Observers subscribe; they never mutate what they observe |
| Presentation of something the model already resolved | **Event queue / sequencer** | Model appends events; a sequencer plays them one at a time; "show the new state" is the last item. No `await` chains across unrelated animations |
| Many similar views rebuilt often (slots, list rows, projectiles, FX) | **Object pool, indexed** | Reuse by index; hide, don't free |
| Parent / child / sibling communication | **Call down, signal up** | Views emit (`pressed`, `closed`); the owner decides what it means |
| Per-player settings | **Merged-over-defaults dictionary** | A key, not a storage system |
| Resource budgets (actions, stamina, command points) | **Resettable counters with named pools, as a table** | Effects add/subtract; no special "act again" state |
| Everything a body on the field shares (player unit, ally, enemy, summon) | **One base type, owners for the rest** | Shared pipelines take the base type. Reject one class with a `side` flag when sides carry different data |
| Who dealt the damage / who was struck | **Observer event carrying the real actors** | Events name the actual actor, even when a proxy (commander, summoner) owns the stat |
| Service lookups (save, audio, content db) | **One lookup helper or an injected services object** | No per-file `get_node("/root/...")` copies; tests/forecasts pass a null service on purpose |
| Sandbox / test setups | **Type Object — a scenario is a data row** | A new setup is a row, not another branch in the sandbox script |
| Architecture rules on every commit | **Ratchet against HEAD** | New or worse violations block; unchanged debt only warns (see `audit-and-ratchet.md`) |
| Measuring balance or a difficulty curve | **Probes × counts against banded thresholds** | Probes are measurement fixtures, never content; replay through the real command API |

## Adding an entry

One row: the problem in player or engineering terms, the pattern's recognised name, and the
rule that keeps it honest. If a pattern was tried and removed, keep the row and say why.
