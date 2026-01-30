extends Area3D

@export_file("*.tscn") var target_map_path: String # Ruta de la escena destino
@export var target_spawn_id: String = "from_outside" # ID de dónde aparecerá el PJ

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player"):
		print("Portal activado!")
		# No need to save_player_data here - GameManager already has all persistent data
		# and load_player_data() will restore it in the new map
		GameManager.change_map(target_map_path, target_spawn_id)
