class_name DisplayFit
extends RefCounted
## Integer-scale fit for the landscape pixel canvas (ART_SPEC §2, D-A08).
## The engine's stretch aspect "expand" + scale mode "integer" misbehave together
## (godotengine/godot#92055, open), so the project uses aspect "keep" + "integer" and this
## function picks the canvas size: the design canvas at the largest whole-number scale that
## fits, grown on either axis to fill the window (up to `max_size`; the rest is letterboxed).
## Layouts anchor to the canvas edges; the extra space goes to the battlefield.


## Returns {"scale": int, "size": Vector2i} for a window of `window` physical pixels.
static func fit(window: Vector2i, base: Vector2i, max_size: Vector2i) -> Dictionary:
	var scale := maxi(1, mini(window.x / base.x, window.y / base.y))
	var size := Vector2i(
		clampi(window.x / scale, base.x, maxi(base.x, max_size.x)),
		clampi(window.y / scale, base.y, maxi(base.y, max_size.y)))
	return {"scale": scale, "size": size}
