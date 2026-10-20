class_name RngStreams
extends RefCounted
## Named, seeded RNG streams (GAME_SPEC §10.1): one per concern so that drawing in one (a
## shop reroll) never shifts another (tomorrow's dice). States are saved with the run.

const NAMES: PackedStringArray = ["ROLL", "SHOP", "ENEMY", "BOSS"]

var _streams := {}


static func create(run_seed: String) -> RngStreams:
	var s := RngStreams.new()
	for n in NAMES:
		var r := RandomNumberGenerator.new()
		r.seed = hash(run_seed + ":" + n)
		s._streams[n] = r
	return s


func stream(name: String) -> RandomNumberGenerator:
	assert(_streams.has(name), "unknown RNG stream %s" % name)
	return _streams[name]


func roll_face(name: String = "ROLL") -> int:
	return stream(name).randi_range(0, Die.FACE_COUNT - 1)


## Uniform pick from a list (callers pass ids in a stable order).
func pick(name: String, items: Array) -> Variant:
	assert(not items.is_empty(), "pick from empty list")
	return items[stream(name).randi_range(0, items.size() - 1)]


## Weighted pick: keys in the given order, weights > 0.
func pick_weighted(name: String, keys: Array, weights: Array) -> Variant:
	var total := 0.0
	for w: float in weights:
		total += w
	var x := stream(name).randf() * total
	for i in keys.size():
		x -= weights[i]
		if x < 0.0:
			return keys[i]
	return keys[-1]


func to_dict() -> Dictionary:
	var out := {}
	for n in NAMES:
		# int64 state as a string: JSON numbers are doubles and would lose bits.
		out[n] = str(stream(n).state)
	return out


static func from_dict(run_seed: String, d: Dictionary) -> RngStreams:
	var s := create(run_seed)
	for n in NAMES:
		s.stream(n).state = int(d[n])
	return s


## Random 8-char uppercase alphanumeric seed (§4.1), from the engine RNG (not a run stream).
static func new_seed() -> String:
	const ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var r := RandomNumberGenerator.new()
	r.randomize()
	var out := ""
	for i in 8:
		out += ALPHABET[r.randi_range(0, ALPHABET.length() - 1)]
	return out
