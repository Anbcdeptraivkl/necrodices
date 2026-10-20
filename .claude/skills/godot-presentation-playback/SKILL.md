---
name: godot-presentation-playback
description: Playing back what the game model already decided in Godot 4 — a presentation queue of skippable animation states, replaying a score/combat trace step by step, tween timing budgets and global speed settings, tap-to-skip, counters that tick, juice (pop, punch, shake, flash, clone bursts) with reduce-motion, and pooled sprite hordes with render tiers. Use when adding or changing any animation, tween, combat playback, damage/score count-up, summon or hit effect, screen shake, game-speed setting, skip button, or when many sprites must appear at once, playback desyncs from the result, animations overlap or hang, a skipped animation leaves stale visuals, or frame rate drops during a big playback.
---

# Presentation Playback

Owns *showing a result the model already computed*. The model (scorer, encounter, run) never
waits for an animation and never learns an animation was skipped. Where the trace comes from
is `roguelike-scoring-pipeline`; pixel-perfect rendering rules are `godot-pixel-art-rendering`.

## Rules

1. **The model resolves first, the view replays.** Combat computes its full result (and
   trace) synchronously, the state changes at once, then a sequencer plays it. Skipping,
   speed-up and reduce-motion can then never change outcomes.
2. **Every animation is a state in one queue.** A `PresentationState` has `_start(host)`
   (creates tweens, connects the last tween's `finished` to `done()`) and `_jump_to_end()`
   (kills its tweens and applies the final look). The queue plays states in order; `skip()`
   jumps the current and all queued states to their end, and `finished` fires exactly once.
3. **No `await` inside a state.** A skipped or freed state leaves a suspended coroutine
   waiting on a tween that was killed and will never emit. Use signal connections that die
   with their emitter.
4. **Time is budgeted, then scaled.** Each phase has a nominal duration from the spec; if the
   whole playback exceeds its cap, compress step durations uniformly; then multiply by the
   speed setting (×1/×2/×4). Compute the timeline once before playing, not per step.
5. **Rest state is pixel-exact.** Scale punches, rotations and shakes are transient (short
   tweens); every state's end look is scale 1, rotation 0, positions rounded to whole pixels.
   `_jump_to_end()` must restore exactly this.
6. **Counters interpolate display values only.** A number label tweens its *shown* value
   toward the trace's `after` value; the real value is already in the model.
7. **Hordes are pooled and tiered.** Pre-allocate the sprite pool at scene load (the spec's
   cap + margin); show/hide and re-texture, never `instantiate` per step. Map true counts to
   visible counts with a capped curve (e.g. linear to 12, log beyond, hard cap), and switch
   to smaller sprites (minis) or banners past tier thresholds. The badge always shows the true
   number. Move to `MultiMeshInstance2D` only when profiling on the target device says so.
8. **Placement is seeded by the view, not the game RNG.** Jitter by group index (or a
   presentation-only RNG), so replays and previews never consume gameplay randomness.
9. **Reduce motion is a profile of the same states**, not separate code paths: fewer bursts,
   no shake or flash, shorter tweens — chosen once when the queue builds the timeline.
10. **Input during playback is limited to skip.** Tap anywhere → `queue.skip()`; all other
    game input is disabled by the owning FSM state, not by checking `is_playing` flags in
    every handler.

## Procedure — adding an animation

1. Write the state class with `_start` / `_jump_to_end`; no `await`.
2. Enqueue it from the owner when the model emits the event (or when building the trace
   timeline).
3. Test: play → `finished` once; skip before start, mid-way and after end → final look
   exact, `finished` once, no leaked tweens or orphan nodes.
4. Check it at ×1, ×4 and reduce-motion on a capture or a short recording.

## Traps

| Trap | Symptom | Fix |
| --- | --- | --- |
| `await tween.finished` in a skippable step | Playback hangs after skip; leaked coroutine | Connect `finished` → `done()`; no await |
| Tween created on a node that is freed mid-playback | Errors about freed instance; tween keeps running | Create tweens on the host (`host.create_tween()`), kill in `_jump_to_end` |
| Separate `is_animating` flags in UI handlers | Some button still works during playback | FSM state "PLAYBACK" with a legality table |
| Per-step `instantiate()` of sprites | Hitches as counts grow; GC spikes on web | Pool pre-allocated at load |
| Clone burst per sprite at 240 sprites | Frame drops at the climax | Cap bursts per group; reduce motion cuts to one per group |
| Durations summed per step at ×1 then scaled per step | Long fights exceed the cap at ×1 | Compute the whole timeline, compress, then scale |
| Shake applied to the camera/root at a fractional offset | Blurry frame during shake | Integer offsets; restore exactly |
| Playback reads model values live | Shows the *next* encounter's numbers after an early state change | Replay only the trace / event payloads captured at resolve time |
