extends Node

# Datos que queremos persistir
var player_stats = {
	"current_hp": 0,
	"current_sp": 0,
	"max_hp": 0,
	"max_sp": 0,
	"zeny": 0,
	"level": 1,
	"exp": 0,
	"inventory_slots": [], # Array de {"item_path": String, "quantity": int}
	"equipped_items": {}, # {slot_type: item_path}
	"hotbar_content": [] # Array de item_paths
}

var target_spawn_id: String = ""
var has_saved_data: bool = false
const SAVE_PATH = "user://savegame.data"

# Guardar datos del jugador antes de cambiar de mapa
func save_player_data(player):
	player_stats["current_hp"] = player.health_component.current_health
	player_stats["max_hp"] = player.health_component.max_health
	player_stats["current_sp"] = player.sp_component.current_sp
	player_stats["max_sp"] = player.sp_component.max_sp
	player_stats["zeny"] = player.inventory_component.zeny
	player_stats["level"] = player.stats.current_level
	
	# Guardar inventario
	player_stats["inventory_slots"] = []
	for slot in player.inventory_component.slots:
		if slot != null and slot.item_data != null:
			player_stats["inventory_slots"].append({
				"item_path": slot.item_data.resource_path,
				"quantity": slot.quantity
			})
		else:
			player_stats["inventory_slots"].append(null)
	
	# Guardar equipamiento
	var equipment_comp = player.get_node_or_null("EquipmentComponent")
	if equipment_comp:
		player_stats["equipped_items"] = {}
		for slot_type in equipment_comp.equipped_items.keys():
			var item = equipment_comp.equipped_items[slot_type]
			if item:
				player_stats["equipped_items"][slot_type] = item.resource_path
			else:
				player_stats["equipped_items"][slot_type] = null
	
	# Guardar hotbar
	player_stats["hotbar_content"] = []
	for item in player.hotbar_content:
		if item != null:
			player_stats["hotbar_content"].append(item.resource_path)
		else:
			player_stats["hotbar_content"].append(null)
	
	has_saved_data = true
	print("[GameManager] Datos guardados: HP=%d/%d, SP=%d/%d, Zeny=%d, Items=%d" % [
		player_stats["current_hp"], player_stats["max_hp"], 
		player_stats["current_sp"], player_stats["max_sp"],
		player_stats["zeny"], player_stats["inventory_slots"].size()
	])

# Cargar datos al jugador al entrar a un nuevo mapa

func load_player_data(player):
	if not has_saved_data:
		print("[GameManager] No hay datos guardados, usando valores iniciales")
		return

	# 1. NIVEL Y ZENY (Básico)
	player.stats.current_level = player_stats["level"]
	player.inventory_component.zeny = player_stats["zeny"]

	# 2. EQUIPAMIENTO (Prioridad Alta)
	# Cargamos el equipo antes que la vida para que los bonos de vitalidad/HP se apliquen primero
	var equipment_comp = player.get_node_or_null("EquipmentComponent")
	if equipment_comp and player_stats["equipped_items"].size() > 0:
		for slot_type in player_stats["equipped_items"].keys():
			var item_path = player_stats["equipped_items"][slot_type]
			if item_path:
				var item = load(item_path)
				equipment_comp.equipped_items[slot_type] = item if item else null
		
		# Forzamos el recalculo de los stats máximos (Max HP/SP) basados en el equipo
		equipment_comp._recalculate_equipment_bonuses()
		equipment_comp.equipment_changed.emit()

	# 3. INVENTARIO COMPLETO
	if player_stats["inventory_slots"].size() > 0:
		player.inventory_component.slots.clear()
		player.inventory_component.slots.resize(player.inventory_component.max_slots)
		for i in range(min(player_stats["inventory_slots"].size(), player.inventory_component.max_slots)):
			var slot_data = player_stats["inventory_slots"][i]
			if slot_data != null:
				var item = load(slot_data["item_path"])
				if item:
					player.inventory_component.slots[i] = InventorySlot.new(item, slot_data["quantity"])
	
	# 4. HOTBAR
	if player_stats["hotbar_content"].size() > 0:
		for i in range(min(player_stats["hotbar_content"].size(), player.hotbar_content.size())):
			var item_path = player_stats["hotbar_content"][i]
			if item_path:
				var item = load(item_path)
				player.hotbar_content[i] = item if item else null
		player.refresh_hotbar_to_hud()

	# 5. SALUD Y SP (Al final para evitar el clamping)
	# Ahora que el equipo ya subió el Max HP, podemos poner el current_hp sin que se recorte
	if player_stats["max_hp"] > 0:
		player.health_component.max_health = player_stats["max_hp"]
		player.health_component.current_health = player_stats["current_hp"]
		player.health_component.on_health_changed.emit(player.health_component.current_health)
	
	if player_stats["max_sp"] > 0:
		player.sp_component.max_sp = player_stats["max_sp"]
		player.sp_component.current_sp = player_stats["current_sp"]
		player.sp_component.on_sp_changed.emit(player.sp_component.current_sp, player.sp_component.max_sp)

	# 6. ACTUALIZAR UI Y SEÑALES
	player.inventory_component.inventory_changed.emit()
	player.inventory_component.zeny_changed.emit(player.inventory_component.zeny)
	
	# Forzar actualización de barras en el HUD si existe la función
	if player.hud and player.hud.has_method("update_hp"):
		player.hud.update_hp(player.health_component.current_health, player.health_component.max_health)
	if player.hud and player.hud.has_method("update_sp"):
		player.hud.update_sp(player.sp_component.current_sp, player.sp_component.max_sp)

	print("[GameManager] Carga exitosa: HP %d/%d" % [player.health_component.current_health, player.health_component.max_health])


func change_map(map_path: String, spawn_id: String):
	target_spawn_id = spawn_id
	get_tree().change_scene_to_file.call_deferred(map_path)

func save_game_to_disk():
	# 1. Asegurarnos de tener los datos más recientes del jugador actual
	# Buscamos al player en el grupo "player" (asegúrate de que tu Player esté en ese grupo)
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		save_player_data(player_node)
		# Guardamos también en qué mapa está actualmente
		player_stats["current_map"] = player_node.owner.scene_file_path
		# Guardamos dónde debería aparecer (cerca de donde guardó)
		# Nota: Esto es simple. Para algo exacto, necesitarías guardar Vector3 position.
		player_stats["spawn_id"] = "InitialSpawn" 
		player_stats["saved_position"] = player_node.global_position
	# 2. Abrir archivo para escribir
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		# 3. Guardar el diccionario completo
		file.store_var(player_stats)
		print("[System] Partida guardada exitosamente en: ", SAVE_PATH)
	else:
		print("[System] Error al intentar guardar la partida.")

func load_game_from_disk():
	get_tree().paused = false
	# 1. Verificar si existe el archivo
	if not FileAccess.file_exists(SAVE_PATH):
		print("[System] No existe archivo de guardado.")
		return false # Retornamos falso para saber que falló
	
	# 2. Abrir archivo para leer
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		# 3. Leer los datos y sobreescribir player_stats
		player_stats = file.get_var()
		has_saved_data = true
		
		print("[System] Partida cargada. Nivel: ", player_stats["level"])
		
		# 4. Cambiar al mapa donde se guardó
		var map_path = player_stats.get("current_map", "res://scenes/maps/starting_field.tscn")
		var spawn_id = player_stats.get("spawn_id", "InitialSpawn")
		
		# Usamos tu función existente para cambiar de mapa
		change_map(map_path, spawn_id)
		return true
	return false

func _input(event):
	# Solo para pruebas (luego esto va en un menú UI)
	if event.is_action_pressed("ui_save"): # Configura esta acción o usa KEY_F5
		save_game_to_disk()
		# Feedback visual opcional:
		get_tree().call_group("hud", "show_message", "Partida Guardada")
		
	if event.is_action_pressed("ui_load"): # Configura esta acción o usa KEY_F9
		load_game_from_disk()
