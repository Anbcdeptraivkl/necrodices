class_name NumberFormat
extends RefCounted
## Number display (ART_SPEC §8): full with commas below 10,000; 3 significant digits + K/M/B/T
## up to 1e15; scientific above. The "full" setting keeps commas up to 1e15.

const SUFFIXES: PackedStringArray = ["", "K", "M", "B", "T"]


static func format(value: float, full: bool = false) -> String:
	var v := floorf(absf(value))
	var sign := "-" if value < 0 else ""
	if v >= 1e15:
		return sign + _scientific(v)
	if v < 10000.0 or full:
		return sign + commas(v)
	var tier := int(floor(log(v) / log(1000.0)))
	var scaled := v / pow(1000.0, tier)
	var text := _three_digits(scaled)
	if text.begins_with("1000"):  # 999.5K rounds up to the next suffix
		tier += 1
		text = _three_digits(v / pow(1000.0, tier))
	return sign + text + SUFFIXES[tier]


static func commas(v: float) -> String:
	var s := str(int(v))
	var out := ""
	var n := s.length()
	for i in n:
		out += s[i]
		var left := n - 1 - i
		if left > 0 and left % 3 == 0:
			out += ","
	return out


## x in [1, 1000): 3 significant digits ("4.56", "12.3", "123"); 99.96 → "100".
static func _three_digits(x: float) -> String:
	var decimals := 2 if x < 10.0 else (1 if x < 100.0 else 0)
	var r := roundf(x * pow(10.0, decimals)) / pow(10.0, decimals)
	if decimals > 0 and r >= pow(10.0, 3 - decimals):
		decimals -= 1
		r = roundf(x * pow(10.0, decimals)) / pow(10.0, decimals)
	if decimals == 0:
		return str(int(r))
	return String.num(r, decimals).rstrip("0").rstrip(".")


static func _scientific(v: float) -> String:
	var e := int(floor(log(v) / log(10.0)))
	var m := v / pow(10.0, e)
	return "%.2fe%d" % [m, e]
