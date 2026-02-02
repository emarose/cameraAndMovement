extends Area3D

@export_file("*.tscn") var target_map_path: String # Ruta de la escena destino
@export var target_spawn_id: String = "from_outside" # ID de dónde aparecerá el PJ

func _ready():
	add_to_group("portal")
	body_entered.connect(_on_body_entered)

func interact(player):
	# Guardar el estado del jugador antes de cambiar de mapa
	GameManager.save_player_data(player)
	GameManager.change_map(target_map_path, target_spawn_id)

func _on_body_entered(body):
	if body.is_in_group("player"):
		# Guardar el estado del jugador antes de cambiar de mapa
		GameManager.save_player_data(body)
		GameManager.change_map(target_map_path, target_spawn_id)
