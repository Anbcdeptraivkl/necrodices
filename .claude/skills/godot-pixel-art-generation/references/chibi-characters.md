# Chibi characters (small sprites and map tokens)

Target look: a **squat, cute chibi**: a big featureless head block, a short boxy body, stubby
arms and legs, flat colour fills, a thick dark outline that encloses every part, and one
clearly held class prop. Numbers are for a **32×32 canvas** and come from a designer's
redraw that was accepted; scale them for other tiers. When the project has a designer-drawn
template cell, **reproduce it with the part grids first** (pixel diff ≤ a handful of pixels)
and only then build the other units from the same parts.

## Proportions (interior pixels, before outline and aura)

| Part | Rows | Width | Note |
| --- | --- | --- | --- |
| Head gear | above the head as needed | brims may exceed the head | carries the class at ×1 |
| Head block | 12 | 16 | rounded only on the top 3 rows; ≈ 60% of the body height |
| Chin line | 1 | head width | an outline row between head and torso — no neck |
| Torso | 6 (incl. belt) | ~13–14 | the near arm is the two left columns, its hand at the bottom |
| Legs | 2 | torso width | split only on the last row (a 3 px gap), **no feet** |

Total interior height ~21 rows for a bare head, feet on the last interior row; leave 1 px for
the outline and 1 px for the aura on every side. Taller than ~24 interior rows (without head
gear) stops reading as chibi; a head narrower than the torso loses the cute read.

## Face and head

- **No features** except the eyes: two horizontal dashes, 3 px each, 2 px apart, on one row
  a little below the middle of the head, shifted towards the facing side. No mouth, nose,
  blush, pupils or highlights.
- Hair is optional and any colour (black hair may simply be the outline colour); it covers
  the top rows and a few pixels down the back of the head.
- Head gear sits on the head block and closes against the face with a dark row (brim
  underside, band, or outline), so the face is enclosed too.

## Three-quarter view (facing right) at this size

- The only cues are placement, not anatomy: eyes shifted right, hair/hood mass at the back
  (left), the far hand sticking out on the right, tools pointing forward.
- Do not draw feet direction, noses or ears — at this size they turn into noise.

## Shading

- Flat fills. At most **one light column on the facing side** (face, hat, shield) and a dark
  seam where the near arm meets the torso; no gradients, no random specks, no drop shadow.
- A cloth's *light* tone can be the torso fill; darker tones are for seams, belts, legs.

## Outline and aura

- Every part is enclosed: outer outline (4-connected), the chin line, and a ring around
  every hand, tool and shield where it overlaps the body. Never leave a part edge that
  touches another part without a dark line.
- The aura (team key colour) is **8-connected** — it fills the diagonal corners, giving a
  round, even halo; a 4-connected aura looks notched at every corner.

## Holding things

- Tools start at the **far hand** (2×2 skin, just right of the torso) and point
  **up-forward** (clubs, swords, daggers at ~45°), their butt resting in the fist.
- Poles (spears, forks) stand **upright** one pixel clear of the face: the sleeve reaches out
  and the fist is drawn over the shaft with its own ring.
- A cross-guard sits at the fist. Shields are upright ellipses on the near arm, covering the
  near hand. Back items (sacks) go behind the body on the back side with a strap.

## Building them: part grids

- One grid per part (body, head, hair, each head gear, each tool, hand poses), each with a
  canvas origin and a `ringed` flag. The outer outline and aura are final passes.
- The legend maps letters to (material slot, ramp index); a unit is a part list back to front
  plus a ramp per slot, so a new unit is data, not drawing code.
- Shared body and head across all humans keep proportions consistent; variety comes from
  head gear, tool and ramps.

## Review checklist (×8 beside the template, then ×1 on a capture)

1. Pixel diff of the template unit against the designer's cell is near zero.
2. Silhouette filled with one colour still says the class (gear + tool).
3. Squat: head ≈ 60% of the body, stubby limbs, no feet.
4. Face is only two dashes; shading is flat or one facing-side column.
5. Every part enclosed by outline; aura continuous with round corners.
6. Every tool gripped, pointing forward or upright; nothing floats.
