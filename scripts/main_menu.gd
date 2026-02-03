extends Control

@onready var load_button = $VBoxContainer/BtnLoadGame

func _ready():
	# Si no hay archivo de guardado, deshabilitamos el botón "Cargar"
	if not FileAccess.file_exists(GameManager.SAVE_PATH):
		load_button.disabled = true

func _on_btn_new_game_pressed():
	# Reiniciar stats en GameManager para empezar de cero
	GameManager.has_saved_data = false
	GameManager.player_stats = { # Reset manual o crea una función reset_data()
		"current_hp": 0, "max_hp": 0, "zeny": 0, "level": 1, 
		"inventory_slots": [], "equipped_items": {}, "hotbar_content": []
	}
	# Cargar primer nivel
	GameManager.change_map("res://scenes/maps/southern_fields.tscn", "InitialSpawn")

func _on_btn_load_game_pressed():
	var success = GameManager.load_game_from_disk()
	if not success:
		print("Error al cargar partida")
