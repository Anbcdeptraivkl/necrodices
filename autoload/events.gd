extends Node
## Signal bus (GAME_SPEC §10.2). Emitters own the meaning; listeners never mutate the emitter.

signal dice_rolled
signal die_selected(index: int)
signal group_bound(group_index: int)
signal group_unbound(group_index: int)
signal summoned
signal combat_started
signal trace_step(step: Dictionary)
signal combat_finished(win: bool)
signal money_changed(money: int)
signal relics_changed
signal consumables_changed
signal shop_opened
signal night_started(night: int)
signal run_ended(victory: bool)
