class_name Overlay
extends PanelContainer
## Base of every modal overlay pushed on an OverlayHost (ART_SPEC §6.6). Emits `closed` once
## with its result (null = cancelled / dismissed).

signal closed(result: Variant)

var dismissable := true
var _closed := false


func close(result: Variant = null) -> void:
	if _closed:
		return
	_closed = true
	closed.emit(result)
