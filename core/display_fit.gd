class_name DisplayFit
extends RefCounted
## Integer-scale fit for the portrait pixel canvas (ART_SPEC §2, D-A08).
## The engine's stretch aspect "expand" + scale mode "integer" misbehave together
## (godotengine/godot#92055, open), so the project uses aspect "keep" + "integer" and this
## function picks the canvas size: width stays at the design width, height grows to fill a
## taller screen at the same whole-number scale (the extra height goes to the battlefield).


## Returns {"scale": int, "size": Vector2i} for a window of `window` physical pixels.
## `max_height` caps how tall the canvas may grow; the rest is letterboxed.
static func fit(window: Vector2i, base: Vector2i, max_height: int) -> Dictionary:
	var scale := maxi(1, mini(window.x / base.x, window.y / base.y))
	var height := clampi(window.y / scale, base.y, maxi(base.y, max_height))
	return {"scale": scale, "size": Vector2i(base.x, height)}
