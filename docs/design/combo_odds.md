# Combo odds (GAME_SPEC §4.3)

Simulation evidence for the combo ranking and the ritual rule (DECISIONS D-G07). 200,000 trials
per row, 5 dice with uniform faces over the 6 elements, seed 7. "Rerolls" = a greedy policy that
keeps the most common element and re-rolls the rest (stops at 4 of a kind). Points and runes are
ignored — this is about patterns only.

| Rerolls | Rabble | Duo Pact | Trio | Rainbow | Full Moon | Ritual | Quartet | Quintet |
|---|---|---|---|---|---|---|---|---|
| 0 | 37.2% | 20.0% | 14.3% | 9.3% | 3.9% | 13.2% | 2.0% | 0.1% |
| 1 | 18.8% | 18.6% | 29.4% | 0.8% | 9.6% | 9.7% | 12.2% | 0.9% |
| 2 | 10.3% | 11.0% | 32.9% | 0.1% | 10.0% | 6.6% | 26.9% | 2.3% |

Rejected variant: a ritual as any 3 distinct elements matching one of four triads appeared in
**44.9%** of raw rolls (0 rerolls) — more often than every other combo — so the ritual now needs
its core element twice.

The in-game balance bot measures the same thing through the real rules
(`tools\balance_sim.cmd --mode=baseline`, `combos` field), including points, runes and trinkets.

```python
import random, collections
E = "BFILVM"
# ritual = 3 distinct elements + the core element twice (4 dice)
RITUALS = [("B", set("BFL")), ("V", set("BVM")), ("I", set("ILV")), ("M", set("FIM"))]

def best(roll):
    c = collections.Counter(roll); counts = sorted(c.values(), reverse=True)
    if counts[0] >= 5: return "QUINTET"
    if counts[0] >= 4: return "QUARTET"
    if any(t <= set(roll) and c[core] >= 2 for core, t in RITUALS): return "RITUAL"
    if counts[0] >= 3 and len(counts) > 1 and counts[1] >= 2: return "FULL_MOON"
    if len(c) == 5: return "RAINBOW"
    if counts[0] >= 3: return "TRIO"
    if counts[0] >= 2 and len(counts) > 1 and counts[1] >= 2: return "DUO_PACT"
    return "RABBLE"

RANK = ["RABBLE", "DUO_PACT", "TRIO", "RAINBOW", "FULL_MOON", "RITUAL", "QUARTET", "QUINTET"]

def greedy(roll, rr, rng):
    for _ in range(rr):
        c = collections.Counter(roll); top, n = c.most_common(1)[0]
        if n >= 4: break
        roll = [d if d == top else rng.choice(E) for d in roll]
    return roll

rng = random.Random(7); N = 200000
for rr in (0, 1, 2):
    t = collections.Counter(best(greedy([rng.choice(E) for _ in range(5)], rr, rng)) for _ in range(N))
    print(f"rerolls={rr}: " + ", ".join(f"{k} {100*t[k]/N:.1f}%" for k in RANK))
```
