class_name HealthComponent
extends Node

signal on_death
signal on_health_changed(new_health)
@onready var stats: StatsComponent = $"../StatsComponent"

@export var max_health: int = 100
var current_health: int

func _ready():
	current_health = max_health
	
func heal(amount: int):
	current_health = min(current_health + amount, stats.max_hp)
	# Emitir señal para actualizar barra de vida
	on_health_changed.emit(current_health, stats.max_hp)

func take_damage(amount: int):
	current_health -= amount
	on_health_changed.emit(current_health) # Esto hace que la barra baje
	
	if current_health <= 0:
		on_death.emit() # Esto es lo que debe activar el _on_death del enemigo
