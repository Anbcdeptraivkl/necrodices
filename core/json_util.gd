class_name JsonUtil
extends RefCounted
## Reads JSON without engine ERROR spam on bad input, and narrows whole-number floats to int
## (JSON numbers parse as float; ids, prices and counts must compare as int).


## Returns the parsed value, or null and appends a message to `errors`.
static func load_file(path: String, errors: PackedStringArray) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("%s: missing" % path)
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		errors.append("%s:%d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return narrow(json.data)


static func narrow(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var f: float = value
			if f == floorf(f) and absf(f) < 9.0e15:
				return int(f)
			return f
		TYPE_ARRAY:
			var out: Array = []
			for item: Variant in value:
				out.append(narrow(item))
			return out
		TYPE_DICTIONARY:
			var out := {}
			for key: Variant in value:
				out[key] = narrow(value[key])
			return out
	return value
