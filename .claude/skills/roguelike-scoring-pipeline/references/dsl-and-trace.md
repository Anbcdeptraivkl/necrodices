# Effect DSL, registry and trace — reference shape

A shape that has worked for chips × mult style games. The project spec owns the actual op,
condition and source names; keep them in one registry file and generate nothing by hand.

## Row shapes

```json
{ "id": "ITEM", "trigger": "GROUP", "cond": {"type": "group_has_element", "element": "BONE"},
  "effects": [ {"op": "add_count", "value": 2} ] }

{ "id": "ITEM2",
  "counter": {"on": "SUMMON", "cond": {"type": "group_has_element", "element": "LEAF"}, "inc": 1},
  "blocks": [ {"trigger": "FINAL", "cond": {"type": "always"},
               "effects": [ {"op": "add_count", "value": {"base": 0, "per": "counter", "step": 1}} ]} ] }
```

Normalise on load: a flat row becomes `blocks = [{trigger, cond, effects}]`, so the
interpreter has one path.

## Registry (one const dictionary per kind)

```gdscript
const TRIGGERS := ["GROUP", "FINAL", "SUMMON", "FIGHT_END"]
const OPS := ["add_power", "add_count", "mul_power", "mul_count", "add_money"]
const SOURCES := ["money", "rerolls_left", "summons_left", "groups", "bosses_defeated", "counter"]  # + "essence:<E>"
const CONDS := {  # name -> required params
    "always": [], "group_has_element": ["element"], "group_tier": ["tier"], ...
}
```

The content test iterates every data row and every registry entry: unknown names fail, and
every registry entry is used by at least one row or has its own fixture (no dead ops).

## Evaluation

```
for each block where block.trigger == phase:
    if eval_cond(block.cond, group_or_null, ctx):
        for e in block.effects:
            v = eval_value(e.value, item_instance, ctx)
            apply(e.op, v, ctx)                 # rounds × ops half-up immediately
            trace.push(step(kind, gi, item.id, e.op, v, ctx.a, ctx.b, label(e.op, v)))
```

- `eval_value` with `per` reads the source from `ctx` (or the item instance for `counter`).
- `add_money` is legal only in commit / end-of-fight phases; the scorer rejects it (registry
  says which phases each op may run in).

## Trace step

| Field | Meaning |
| --- | --- |
| `kind` | `group_base`, `face_mod`, `relic`, `boss`, `total` |
| `group_index` | index in the army, `-1` for final / total |
| `source_id` | unit / modifier / item / rule id |
| `op`, `value` | what happened (`none` for display-only steps) |
| `a_after`, `b_after` | running totals after the step |
| `label` | ready-to-show text from the strings table (`+2 Count`, `×1.5 Count`) |

Tests assert on `(source_id, op, a_after, b_after)` sequences — readable diffs when an order
changes.

## Number display

Keep formatting out of the scorer. One formatter: full with separators below a threshold,
3 significant digits + suffix (K, M, B, T) above it, scientific beyond; a setting may force
full. Test the boundaries (9,999 / 10,000 / 999.5K rounding up to 1.00M).
