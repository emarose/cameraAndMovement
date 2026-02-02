extends Node3D

@onready var player = $Player

func _ready():
	# 0. Crear y configurar el click indicator
	_setup_click_indicator()
	
	# 1. Posicionar jugador en spawn point
	var spawn_id = GameManager.target_spawn_id
	if spawn_id == "":
		spawn_id = "InitialSpawn"
	
	var spawn_node = find_child(spawn_id)
	if spawn_node and spawn_node is Marker3D:
		player.global_position = spawn_node.global_position
		if player.has_node("NavigationAgent3D"):
			player.get_node("NavigationAgent3D").set_velocity(Vector3.ZERO)

	# 2. Esperar a que el jugador y todos los hijos terminen su inicialización
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 3. Cargar datos ANTES de configurar la cámara
	# Esto asegura que los datos persistentes de GameManager se sincronizan con el nuevo Player
	GameManager.load_player_data(player)
	
	# 4. Configurar cámara
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
			
	# SI venimos de un "Load Game" y tenemos posición guardada
	if GameManager.player_stats.has("saved_position"):
		player.global_position = GameManager.player_stats["saved_position"]
		# Borramos la posición para que si cruza un portal normal, no se use esto
		GameManager.player_stats.erase("saved_position")

func _setup_click_indicator():
	# Instanciar la escena del ClickIndicator
	var click_indicator_scene = preload("res://scenes/ClickIndicator.tscn")
	var click_indicator = click_indicator_scene.instantiate()
	
	# Añadir al mapa
	add_child(click_indicator)
	
	# Asignar automáticamente al player
	if player:
		player.click_indicator_path = click_indicator.get_path()
		# Refrescar la referencia del player al click_indicator
		player.click_indicator = click_indicator
