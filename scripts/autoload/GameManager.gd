extends Node

# Datos que queremos persistir
var player_stats = {
	"current_hp": 0,
	"current_sp": 0,
	"max_hp": 0,
	"max_sp": 0,
	"zeny": 0,
	"level": 1,
	"inventory_slots": [], # Array de {"item_path": String, "quantity": int}
	"equipped_items": {}, # {slot_type: item_path}
	"hotbar_content": [], # Array de item_paths
	"job_name": "Novice",
	"job_level": 1,
	"job_exp": 0,
	"is_transcended": false,
	"current_job_path": "res://resources/jobs/Novice.tres",
	"unlocked_jobs": [], # Array of resource paths to JobData
	"base_exp": 0,
	"skill_points": 0,
	"stat_points_available": 0,
	# NUEVO: Diccionario para skills aprendidas
	# Formato: { "bash": 5, "magnum_break": 1 }
	"learned_skills": {}
}

signal base_exp_gained(current_exp, next_level_exp)
signal job_exp_gained(current_exp, next_level_exp)
signal job_level_up(new_level)
signal base_level_up(new_level)
signal job_changed(new_job_name)

var current_job_data: JobData # Runtime reference to active job resource

var target_spawn_id: String = ""
var has_saved_data: bool = false
const SAVE_PATH = "user://savegame.data"

func save_player_data(player):
	player_stats["current_hp"] = player.health_component.current_health
	player_stats["max_hp"] = player.health_component.max_health
	player_stats["current_sp"] = player.sp_component.current_sp
	player_stats["max_sp"] = player.sp_component.max_sp
	player_stats["zeny"] = player.inventory_component.zeny
	player_stats["level"] = player.stats.current_level
	
	# Limpiar y guardar inventario
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
	
	# Guardar hotbar (items Y skills)
	player_stats["hotbar_content"] = []
	for content in player.hotbar_content:
		if content != null:
			player_stats["hotbar_content"].append(content.resource_path)
		else:
			player_stats["hotbar_content"].append(null)
	
	# Guardar el path del job actual
	if current_job_data:
		player_stats["current_job_path"] = current_job_data.resource_path
	
	has_saved_data = true


func load_player_data(player):
	# Load player data from GameManager (always, not just when manually saved)
	# 1. NIVEL Y ZENY (Básico)
	player.stats.current_level = player_stats["level"]
	player.stats.current_job_level = player_stats.get("job_level", 1)
	player.inventory_component.zeny = player_stats["zeny"]
	
	# Restaurar progresión (exp y stat points)
	# Nota: base_exp, job_exp, stat_points_available ya están en GameManager.player_stats
	# Solo necesitamos emitir las señales para actualizar la UI

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
			var resource_path = player_stats["hotbar_content"][i]
			if resource_path:
				var resource = load(resource_path)
				player.hotbar_content[i] = resource if resource else null
			else:
				player.hotbar_content[i] = null
		player.refresh_hotbar_to_hud()

	# 5. SALUD Y SP (Al final para evitar el clamping)
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
	
	# Emitir señales de experiencia para actualizar las barras de exp en el HUD
	var base_req = get_required_exp(player_stats["level"], false)
	var job_req = get_required_exp(player_stats["job_level"], true)
	base_exp_gained.emit(player_stats["base_exp"], base_req)
	job_exp_gained.emit(player_stats["job_exp"], job_req)
	
	# Forzar actualización de barras en el HUD si existe la función
	if player.hud and player.hud.has_method("update_hp"):
		player.hud.update_hp(player.health_component.current_health, player.health_component.max_health)
	if player.hud and player.hud.has_method("update_sp"):
		player.hud.update_sp(player.sp_component.current_sp, player.sp_component.max_sp)
	
	# 7. Initialize current_job_data if invalid (e.g. after loading from save)
	# Now using current_job_path from dictionary to populate runtime reference
	var path = player_stats.get("current_job_path", "res://resources/jobs/Novice.tres")
	if FileAccess.file_exists(path):
		current_job_data = load(path)
	else:
		current_job_data = load("res://resources/jobs/Novice.tres")
	
	# Ensure current job and novice are in unlocked_jobs
	var novice_path = "res://resources/jobs/Novice.tres"
	if not player_stats["unlocked_jobs"].has(novice_path):
		player_stats["unlocked_jobs"].append(novice_path)
	
	if current_job_data and not player_stats["unlocked_jobs"].has(current_job_data.resource_path):
		player_stats["unlocked_jobs"].append(current_job_data.resource_path)

	# Emit job changed signal to ensure UI components (like SkillTree) refresh
	job_changed.emit(player_stats["job_name"])



func change_map(map_path: String, spawn_id: String):
	target_spawn_id = spawn_id
	get_tree().change_scene_to_file.call_deferred(map_path)

func save_game_to_disk():
	# 1. Asegurarnos de tener los datos más recientes del jugador actual
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		save_player_data(player_node)
		# Guardamos también en qué mapa está actualmente
		player_stats["current_map"] = player_node.owner.scene_file_path
		# Guardamos dónde debería aparecer (cerca de donde guardó)
		player_stats["spawn_id"] = "InitialSpawn" 
		player_stats["saved_position"] = player_node.global_position
	# 2. Abrir archivo para escribir
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		# 3. Guardar el diccionario completo
		file.store_var(player_stats)
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
		get_tree().call_group("hud", "show_message", "Partida Guardada")
		
	if event.is_action_pressed("ui_load"): # Configura esta acción o usa KEY_F9
		load_game_from_disk()

func get_required_exp(level: int, is_job: bool = false) -> int:
	if is_job:
		# Ejemplo: El Job pide un poco más que el nivel base
		return int(40 * pow(level, 1.6)) 
	else:
		return int(50 * pow(level, 1.5))

# Función unificada para ganar experiencia
func gain_experience(amount: int, is_job: bool = false):
	var job_res = get_current_job_data()
	var max_jl = job_res.max_job_level if job_res else 5
	
	if is_job:
		# Si ya alcanzaste el nivel máximo, no ganas más job_exp
		if player_stats["job_level"] >= max_jl:
			return
		
		player_stats["job_exp"] += amount
		var req_exp = get_required_exp(player_stats["job_level"], true)
		
		while player_stats["job_exp"] >= req_exp and player_stats["job_level"] < max_jl:
			player_stats["job_exp"] -= req_exp
			player_stats["job_level"] += 1
			player_stats["skill_points"] += 1 # Ganamos un punto por nivel
			job_level_up.emit(player_stats["job_level"])
			req_exp = get_required_exp(player_stats["job_level"], true)
		
		# Si alcanzaste max level, limpiar exp restante
		if player_stats["job_level"] >= max_jl:
			player_stats["job_exp"] = 0
		
		job_exp_gained.emit(player_stats["job_exp"], req_exp)
	else:
		player_stats["base_exp"] += amount
		var req_exp = get_required_exp(player_stats["level"], false)
		
		while player_stats["base_exp"] >= req_exp:
			player_stats["base_exp"] -= req_exp
			player_stats["level"] += 1
			player_stats["stat_points_available"] += 1 # Ganamos un punto por nivel
			base_level_up.emit(player_stats["level"])
			req_exp = get_required_exp(player_stats["level"], false)
		
		base_exp_gained.emit(player_stats["base_exp"], req_exp)
func can_learn_skill(skill: SkillData) -> bool:
	# 1. ¿Tengo puntos de habilidad?
	if player_stats["skill_points"] <= 0:
		return false
	
	# 2. ¿He llegado al nivel máximo de esta skill?
	var current_lv = get_skill_level(skill.id)
	if current_lv >= skill.max_level:
		return false
		
	# 3. ¿Tengo el Job Level necesario?
	if player_stats["job_level"] < skill.required_job_level:
		return false
		
	# 4. ¿Tengo las skills previas requeridas?
	for req_skill in skill.required_skills:
		if get_skill_level(req_skill.id) < 1: # O el nivel que pidas
			return false
			
	return true

# Devuelve el nivel actual (0 si no la tienes)
func get_skill_level(skill_id: String) -> int:
	if player_stats["learned_skills"].has(skill_id):
		return player_stats["learned_skills"][skill_id]
	return 0

func get_current_job_data() -> JobData:
	if current_job_data:
		return current_job_data
	
	# Fallback/Lazy load
	var path = player_stats.get("current_job_path", "res://resources/jobs/Novice.tres")
	if FileAccess.file_exists(path):
		current_job_data = load(path)
	return current_job_data

# La función que realmente gasta el punto
func level_up_skill(skill: SkillData) -> bool:
	if can_learn_skill(skill):
		player_stats["skill_points"] -= 1
		
		var new_level = get_skill_level(skill.id) + 1
		player_stats["learned_skills"][skill.id] = new_level
		
		return true # Éxito
	
	return false # Fallo

func change_job(new_job_resource: JobData):
	# Check if player can transcend (reached job level 40, unless first job change from Novice)
	if player_stats["job_name"] == "Novice":
		# First job change requires job level 5
		if player_stats["job_level"] < 5:
			print("Debes alcanzar Job Level 5 para elegir tu primera clase")
			return
		player_stats["is_transcended"] = true
	else:
		# Subsequent job changes require job level 40 (transcendence requirement)
		if player_stats["job_level"] < 40:
			print("Debes alcanzar Job Level 40 para transcender a %s" % new_job_resource.job_name)
			return
		player_stats["is_transcended"] = true
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	player_stats["job_name"] = new_job_resource.job_name
	player_stats["job_level"] = 1
	player_stats["job_exp"] = 0
	player_stats["current_job_path"] = new_job_resource.resource_path
	current_job_data = new_job_resource
	
	# Add to unlocked jobs if not already there
	if not player_stats["unlocked_jobs"].has(new_job_resource.resource_path):
		player_stats["unlocked_jobs"].append(new_job_resource.resource_path)
	
	# Emitir señal para actualizar UI
	job_level_up.emit(player_stats["job_level"])
	job_changed.emit(player_stats["job_name"])
	
	print("¡Felicidades! Ahora eres un %s" % new_job_resource.job_name)
	save_game_to_disk() # Guardar progreso inmediatamente
