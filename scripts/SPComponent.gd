# --- SPComponent.gd ---
extends Node
class_name SPComponent

signal on_sp_changed(current, max_sp)

var max_sp: int = 0
var current_sp: int = 0
var stats: StatsComponent

func setup(stats_ref: StatsComponent):
	stats = stats_ref
	update_max_sp()
	if not _should_preserve_sp():
		current_sp = max_sp
	on_sp_changed.emit(current_sp, max_sp)

func _should_preserve_sp() -> bool:
	var parent = get_parent()
	if parent and parent.is_in_group("player"):
		return GameManager.has_saved_data
	return false

func update_max_sp():
	if stats:
		max_sp = stats.get_max_sp()
		current_sp = clamp(current_sp, 0, max_sp)
		on_sp_changed.emit(current_sp, max_sp)

func use_sp(amount: int) -> bool:
	if current_sp >= amount:
		current_sp -= amount
		on_sp_changed.emit(current_sp, max_sp)
		return true
	return false

func recover(amount: int):
	current_sp = min(current_sp + amount, max_sp)
	on_sp_changed.emit(current_sp, max_sp)
