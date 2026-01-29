extends Node3D

@onready var player = $Player

func _ready():
	# 1. Posicionar jugador en spawn point
	var spawn_id = GameManager.target_spawn_id
	if spawn_id == "":
		spawn_id = "InitialSpawn"
	
	var spawn_node = find_child(spawn_id)
	if spawn_node and spawn_node is Marker3D:
		player.global_position = spawn_node.global_position
		if player.has_node("NavigationAgent3D"):
			player.get_node("NavigationAgent3D").set_velocity(Vector3.ZERO)
	else:
		print("[BaseMap] Spawn point '%s' no encontrado" % spawn_id)
	
	# 2. Esperar a que el jugador termine su inicialización
	await get_tree().process_frame
	
	# 3. Cargar o guardar datos
	if GameManager.has_saved_data:
		# Restaurar datos guardados
		GameManager.load_player_data(player)
	else:
		# Primera vez: guardar estado inicial
		GameManager.save_player_data(player)
