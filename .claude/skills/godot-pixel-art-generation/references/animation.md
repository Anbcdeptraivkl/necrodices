# Animating small sprites (16–32 px units)

Budgets from shipped pixel games and guides, confirmed by a designer review of generated
prototypes; tune on captures.

## Frame budget

| Animation | 32 px unit | 16 px unit | Timing |
| --- | --- | --- | --- |
| Walk | 4 | 2 | By distance walked (one cycle per ~2 body widths), never by a clock, so feet never slide; random start phase per unit in a crowd. Give the standing frames a bigger share of the cycle than the up frames (e.g. 30 / 20 / 30 / 20 %): an even split loops fast and jittery |
| Idle | 2 (breathing) | 1–2 | 400–500 ms per frame |
| Attack | 6 poses: windup, 3 in-betweens, extend, follow | 4 | Windup held for the sim's wind-up; the strike plays only the last in-between (1 beat) and the impact pose (held 3–4 beats); the in-betweens play on the slow recovery. A beat = one 60 Hz frame |
| Hit area (smear) | 2: impact, dissipate (all kinds) | same | Spawned on the strike tick: impact ~50 ms, dissipate ~60 ms |
| Hit | 0 (flash shader) | 0 | — |
| Death | 3–4, the last frame is the corpse | 2–3 | one-shot |

Tiny sprites cannot show 8 distinct walk frames; more frames only add near-duplicates.

## Scripts that read well on squat chibis

- **Walk:** stand · body up 1 px with the near leg lifted · stand · up 1 px with the far leg
  lifted. The planted leg stretches one row, the lifted leg keeps its length and leaves the
  ground. No feet, no stride: the bob and the alternating lifted leg are the walk.
- **Idle:** the head group (head, hair, head gear) drops 1 px on the second frame; the torso
  and the tool stay. A breath, not a bounce.
- **Attack poses:** the upper body leans back 1 px with the tool cocked (windup), then 0 → 1 →
  2 px forward over planted legs through the in-betweens to full extension, and settles at 1
  at the end of the motion. Per tool: club raised behind the head → steep → diagonal → near
  level → level → down (follow-through); blade cocked → diagonal → thrust; pole pulled back →
  half way → full thrust → upright again.
- **Casting (spells):** hold the windup through the cast's wind-up, show the release pose
  (the hand thrown forward) on the tick the spell leaves, hold it ~150 ms (a few beats read as
  skipped when no smear marks the moment), settle back on the windup pose for the recovery, then idle. No strike in-between and
  no smear: the spell's own FX, particles and impact carry the hit.
- **Props at the canvas top** (upright poles, plumes) cannot bob without losing their aura row:
  keep them still while the body bobs — the fist slides along a grounded shaft, a plume lags
  (secondary motion).

## Snappy attack timing

The windup is the tell and may hold long; everything after it must be fast, the impact must
stop dead, and only the recovery may be slow. Spawn the smear on the strike tick with no
delay. An even-paced windup → swing → contact reads as floaty. Keep the timeline in code
next to the frames (a function that turns the sim's wind-up and recovery into frame times) so
the view, the previews and the tests share it.

**Force and inertia come from skipping frames, not adding them.** Playing every in-between at
an even pace is smooth and consistent but shows no force: a real chop or punch crosses from
windup to impact faster than the eye follows, stops dead, then recovers slowly. So the
strike shows only the windup (held: the tell), **the last in-between for one beat**, and the
**impact pose — the farthest from the windup** (a swung arc's follow-through, a thrust's full
extension) — for **3–4 beats** (a beat more than feels necessary: 2 read as rushed), with the smear. The in-betweens are drawn anyway: they play
on the **recovery**, slowly, from the impact pose back to idle. Count in beats of one display
frame (~17 ms at 60 Hz) so nothing is shorter than the screen can show; GIF previews stretch
frames under 20 ms, so judge the feel in the engine.

Name poses by what they show (windup, swing_early, swing, swing_late, extend, follow), not by
their role (contact, recover): which pose is the impact differs per weapon, and so may the
strike in-between and the recovery order (a claw: windup, swing, follow, then extend,
swing_late, swing_early; a bite: windup, extend, follow, then swing, swing_early). Keep these
per attack family in data, not as fixed frame indices.

**Force inside the sprite too:** the strike and impact frames may carry their own smear and
motion blur (a blade's arc, a claw's streaks) drawn into the unit's cell. They sell the force;
the separate hit-area smear still shows where the hit lands.

## The hit area is the smear

- **No tell graphics.** A held windup pose and a snappy swing are the telegraph; filling
  wedges and warning colours look cheap and add noise.
- **The smear is a separate FX sprite** spawned at contact where the attack lands (Hollow Knight
  slash effects, fighting-game hit boxes), and **it is the hit area**: the sim tests the same
  shape, direction and size. Never author a hit area the player cannot see, or a smear that
  does not match the hit area.
- **In front, clear of the body:** a moon-shaped swoosh whose inner radius exceeds the
  attacker's half-height, along the attack direction. A reach zone centred on the feet hides
  under the attacker's own body in three-quarter view; that is a design error, not an art
  detail.
- **Pre-drawn directions:** bodies usually face only left/right while aims go anywhere; draw
  the smear in 8 (at least 4) directions as pixel art, snap the sim's aim to the same
  directions, never rotate pixel sprites at runtime.
- **One smear kind per attack shape**, all big and bold (about 1.5–2 body widths), white front
  edge, a pale body, a 1 px rim in the team key colour so the palette-swap shader shows whose
  attack it is:
  - **slash** (swung weapons): a moon-shaped swoosh, inner radius clear of the body, thick in
    the middle, tapering to points, ~±60°;
  - **stab** (spears, forks, daggers, fists, horns): a lance along the attack, thin tail,
    widest near the front, pointed tip;
  - **bite** (animals, monsters): a **square jaw box** along the attack — straight jaw bars,
    end posts, corners kicked out — with sharp fangs from both bars meeting at the axis, the
    front ones longer; on dissipate the jaws spring apart again (letting go). Rounded or oval
    jaws read gentle; an "open" frame before the bite adds nothing. Offset the fangs of one
    jaw by the screen side, not the local side, so left and right bites mirror.
- **Spawn gap:** a smear glued to the weapon reads wrong; place it 1–2 px beyond the weapon. Make
  the gap the sheet's per-direction pivot (cell centre minus the gap along the direction), so
  the art stays untouched and the sim's hit area moves by the same amount.
- **Clear of the attacker's farthest pose, not its idle:** a lunge or a long weapon in the
  impact frame reaches past the idle silhouette, and a smear placed from the idle sinks into
  it. Start the shape beyond the impact pose's reach; to keep the area, make it shorter along
  the attack and taller across. Count the space between the attacker and the shape as hit
  too (the swing or lunge crosses it), so a target standing close is not missed.
- **Height:** draw the smear around the attacker's body centre; test the hit on the ground with
  the same radii, so it overlaps the targets' bodies at any direction.

## Building frames

- **Pivot = body centre.** Sprites drawn off-centre to leave room for a weapon need a per-sheet
  pivot, or they turn about the wrong point when flipped and their FX look offset.
- **With part grids, motion is offsets plus pose grids:** bob, lean and lunge move parts 1–2 px;
  legs swap between a few shared grids; each tool needs ~3–4 pose grids in final canvas
  coordinates. Run the same outline and aura passes on every frame so the style holds.
- **Animate the approved art, not the recipe.** When the designer edited tokens by hand, diff
  each approved token against its recipe, give every edited pixel to the part drawn under it
  (the nearest part for pixels added outside every part), and draw it with that part in every
  frame. An outline pixel on the approved silhouette's rim means "erased here" (the outline
  pass redraws it); inside the silhouette it is a line the designer drew. Test that the idle
  frame equals the approved token.
- **Edits must follow a part into its pose variants:** a lifted-leg pose drawn as its own grid
  loses the edits found on the standing legs (an armoured unit walks in cloth trousers). Map
  each variant to the base part's geometry (shifted rows, stretched rows) and carry the edits
  through that map; compare every frame with the reviewed sheet, not only the idle frame.
- **Designer touch-ups in a reviewed prototype sheet are the truth:** fold them back into the
  generator (diff the sheet against the recipe, frame by frame) so a later rebuild of a row
  keeps them.
- **Hand-drawn sprites still split into parts** (a part finder): give filled pixels a part
  by area and colour rules; give each outline pixel the part most of its nearest filled
  pixels belong to, so hand-drawn outlines travel with their part; drop only the aura *ring*
  (exterior aura touching the outline) and keep decorative aura — wisps beyond the ring,
  bands enclosed in the sprite, aura laid straight on a fill where the artist left the
  outline out. Details drawn only in outline (a staff's cap) need a rule that claims those
  outline pixels. On composition, close the outline only where a *fill* meets empty space,
  and ring the aura around non-aura pixels only. Test that the unmoved layers recompose the
  source.
- **Moving parts open gaps:** a head pushed forward leaves a seam to the body; stretch the
  neck by drawing the part's fill (no outline) at the intermediate offsets behind it.
- **Prototype on a canvas larger than the source** (e.g. 48×48 around a 32×32 sprite, pivot
  kept on the feet): lunges and weapons at full extension pass the source's edges.
- **Four or more legs walk as a bound, not by pairs:** neutral → all legs gathered under the
  body (body 1 px up, feet planted) → all legs stretched out fore and aft (feet off the ground)
  → neutral, looping or settling to idle. Diagonal pairs lifting in turn read stiff on a 32 px
  animal. A bite is a crouch
  back (head down) then a lunge (head forward 1–2 px past the body's lean).
- **Generation limits:** rigid-part motion, smears and FX generate well; cloth, hair, squash of
  the head do not; a bound gait generates as rigid leg offsets, a base for the artist. Plan
  an artist polish of the windup and contact keys, and of in-sprite smears.
