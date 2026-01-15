extends Node
class_name SPComponent

signal on_sp_changed(current, max_sp)

@export var max_sp: int = 0
var current_sp: int = 0
var stats: StatsComponent

func setup(stats_ref: StatsComponent):
	stats = stats_ref
	# Sincronizamos con los stats iniciales
	update_max_sp()
	current_sp = max_sp # Empezar lleno
	on_sp_changed.emit(current_sp, max_sp)

func update_max_sp():
	if stats:
		max_sp = stats.get_max_sp()
		on_sp_changed.emit(current_sp, max_sp)

func use_sp(amount: int) -> bool:
	if current_sp >= amount:
		current_sp -= amount
		on_sp_changed.emit(current_sp, max_sp)
		return true
	return false

# Aquí puedes meter la regeneración de RO fácilmente
func _on_regen_timer_timeout():
	if current_sp < max_sp:
		current_sp = min(current_sp + 1 + (stats.int_stat / 6), max_sp)
		on_sp_changed.emit(current_sp, max_sp)
