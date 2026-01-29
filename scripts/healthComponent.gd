class_name HealthComponent
extends Node

signal on_death
signal on_health_changed(new_health)
signal on_damage_taken(amount: int)
@onready var stats: StatsComponent = $"../StatsComponent"

@export var max_health: int = 100
var current_health: int

func _ready():
	if _should_initialize_full_health():
		current_health = max_health

func _should_initialize_full_health() -> bool:
	var parent = get_parent()
	if parent and parent.is_in_group("player"):
		return not GameManager.has_saved_data
	return true
	
func heal(amount: int):
	current_health = min(current_health + amount, max_health)
	# Emitir señal para actualizar barra de vida
	on_health_changed.emit(current_health)

func take_damage(amount: int):
	current_health -= amount
	on_health_changed.emit(current_health) # Esto hace que la barra baje
	on_damage_taken.emit(amount) # Emitir señal de daño recibido (para flinch, etc)
	
	if current_health <= 0:
		on_death.emit() # Esto es lo que debe activar el _on_death del enemigo
