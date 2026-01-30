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
	# 1. Buscamos la cámara activa de esta escena
	var camera = get_viewport().get_camera_3d()
	
	if camera:
		# Si la cámara tiene una propiedad "target", se la asignamos
		if "target" in camera:
			camera.target = player
			# Opcional: Teletransportar la cámara de golpe al jugador para que no viaje desde el (0,0,0)
			if "offset" in camera:
				camera.global_position = player.global_position + camera.offset
				camera.look_at(player.global_position)
		
		# Si usas un script diferente que usa una función set_target
		elif camera.has_method("set_target"):
			camera.set_target(player)
			
	print("Mapa inicializado. Cámara asignada al jugador.")
	# 3. Cargar datos (SIEMPRE, no solo cuando has_saved_data)
	# Esto asegura que los datos persistentes de GameManager se sincronizan con el nuevo Player
	GameManager.load_player_data(player)

	# SI venimos de un "Load Game" y tenemos posición guardada
	if GameManager.player_stats.has("saved_position"):
		player.global_position = GameManager.player_stats["saved_position"]
		# Borramos la posición para que si cruza un portal normal, no se use esto
		GameManager.player_stats.erase("saved_position")
