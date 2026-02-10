extends CanvasLayer

# --- Referencias Principales ---
@onready var hp_bar = $HealthBar
@onready var sp_bar = $ManaBar
@onready var hp_value_label = $HealthBar/HPValueLabel
@onready var sp_value_label = $ManaBar/SPValueLabel

@onready var exp_bar = $Level/BaseExpBar
@onready var level_label = $Level/BaseLevelLabel
@onready var job_exp_bar = $Level/JobExpBar
@onready var job_level_label = $Level/JobLevelLabel
@onready var job_name_label = $Level/JobNameLabel

@onready var stats_panel = $StatsPanel
@onready var points_label = $StatsPanel/VBoxContainer_Base/PointsLabel
@onready var log_label: RichTextLabel = $PanelContainer/LogLabel
@onready var active_skill_label = $ActiveSkillLabel
@onready var armed_skill_label: RichTextLabel = $ArmedSkillLabel
@onready var enemy_debug_panel: PanelContainer = $EnemyDebugPanel
@onready var enemy_name_label: Label = $EnemyDebugPanel/VBoxContainer/EnemyNameLabel
@onready var enemy_stats_label: Label = $EnemyDebugPanel/VBoxContainer/StatsLabel
@onready var pickup_panel: PanelContainer = $PickupPanel
@onready var pickup_label: Label = $PickupPanel/PickupLabel
@onready var hotbar_tooltip: PanelContainer = $HotbarTooltip
@onready var hotbar_tooltip_name: Label = $HotbarTooltip/VBox/NameLabel
@onready var hotbar_tooltip_desc: Label = $HotbarTooltip/VBox/DescLabel
@onready var inventory_window: Control = $InventoryUI
@onready var skill_tree_ui: Control = $SkillTreeUI

# --- Referencias a los Valores de Stats ---
@onready var str_label = $StatsPanel/VBoxContainer_Base/StrRow/Value
@onready var agi_label = $StatsPanel/VBoxContainer_Base/AgiRow/Value
@onready var vit_label = $StatsPanel/VBoxContainer_Base/VitRow/Value
@onready var int_label = $StatsPanel/VBoxContainer_Base/IntRow/Value
@onready var dex_label = $StatsPanel/VBoxContainer_Base/DexRow/Value
@onready var luk_label = $StatsPanel/VBoxContainer_Base/LukRow/Value

# --- Referencias a los Bonos de Job ---
@onready var str_bonus_label: Label = $StatsPanel/VBoxContainer_Base/StrRow/BonusLabel
@onready var agi_bonus_label: Label = $StatsPanel/VBoxContainer_Base/AgiRow/BonusLabel
@onready var int_bonus_label: Label = $StatsPanel/VBoxContainer_Base/IntRow/BonusLabel
@onready var vit_bonus_label: Label = $StatsPanel/VBoxContainer_Base/VitRow/BonusLabel
@onready var luk_bonus_label: Label = $StatsPanel/VBoxContainer_Base/LukRow/BonusLabel
@onready var dex_bonus_label: Label = $StatsPanel/VBoxContainer_Base/DexRow/BonusLabel

@onready var atk_val = $StatsPanel/VBoxContainer_Derived/AtkRow/Value
@onready var matk_val = $StatsPanel/VBoxContainer_Derived/MatkRow/Value
@onready var hit_val = $StatsPanel/VBoxContainer_Derived/HitRow/Value
@onready var flee_val = $StatsPanel/VBoxContainer_Derived/FleeRow/Value
@onready var aspd_val = $StatsPanel/VBoxContainer_Derived/AspdRow/Value
@onready var def_val = $StatsPanel/VBoxContainer_Derived/DefRow/Value
@onready var hotbar_container: HBoxContainer = $HotbarGrid
@onready var equipment_ui: EquipmentUI = $EquipmentUI
@onready var status_effects_container: HBoxContainer = $StatusEffectsContainer
@onready var cast_bar: ProgressBar = $CastBar
@onready var cast_label: Label = $CastBar/CastLabel
@onready var zeny_label: Label = $ZenyLabel

var slots: Array = []
var active_effect_indicators: Dictionary = {}  # effect_name -> indicator_node
var player_stats: StatsComponent
var current_skill_name: String = ""
var _pickup_base_pos := Vector2.ZERO
	
func _ready():
	# Connect to GameManager exp signals
	GameManager.base_exp_gained.connect(_on_xp_changed)
	GameManager.base_level_up.connect(_on_level_up)
	GameManager.job_exp_gained.connect(_update_job_bar)
	GameManager.job_level_up.connect(_on_job_level_up)

	# Initialize level labels with current values
	level_label.text = "Base Lvl: " + str(GameManager.player_stats["level"])
	job_level_label.text = "Job Lvl: " + str(GameManager.player_stats["job_level"])
	job_name_label.text = "(" + GameManager.player_stats["job_name"] + ")"
	
	# Initialize bars with current values
	var base_req = GameManager.get_required_exp(GameManager.player_stats["level"], false)
	_on_xp_changed(GameManager.player_stats["base_exp"], base_req)
	var job_req = GameManager.get_required_exp(GameManager.player_stats["job_level"], true)
	_update_job_bar(GameManager.player_stats["job_exp"], job_req)
	
	armed_skill_label.text = ""
	if pickup_panel:
		_pickup_base_pos = pickup_panel.position
		pickup_panel.visible = false
	if hotbar_tooltip:
		hotbar_tooltip.visible = false
		
	setup_hotbar_ui()


func refresh_ui():
	if not is_inside_tree() or get_tree() == null:
		return
	# Stats Base y Totales (mostrando el bono si existe)
	str_label.text = str(player_stats.get_total_str())
	agi_label.text = str(player_stats.get_total_agi())
	dex_label.text = str(player_stats.get_total_dex())
	int_label.text = str(player_stats.get_total_int())
	vit_label.text = str(player_stats.get_total_vit())
	luk_label.text = str(player_stats.get_total_luk())

	# Display job bonuses
	var current_job = GameManager.get_current_job_data()
			
	if current_job:
		str_bonus_label.text = "+%d" % current_job.str_bonus if current_job.str_bonus != 0 else ""
		agi_bonus_label.text = "+%d" % current_job.agi_bonus if current_job.agi_bonus != 0 else ""
		int_bonus_label.text = "+%d" % current_job.int_bonus if current_job.int_bonus != 0 else ""
	else:
		str_bonus_label.text = ""
		agi_bonus_label.text = ""
		int_bonus_label.text = ""
		agi_bonus_label.text = ""
		int_bonus_label.text = ""

	# Stats Derivados
	atk_val.text = str(player_stats.get_atk())
	matk_val.text = str(player_stats.get_matk())
	def_val.text = str(player_stats.get_def())
	hit_val.text = str(player_stats.get_hit())
	aspd_val.text = str(player_stats.get_aspd())
	flee_val.text = str(player_stats.get_flee())
	# Puntos disponibles
	points_label.text = "Puntos disponibles: " + str(GameManager.player_stats["stat_points_available"])
	# Control de botones
	var can_add = GameManager.player_stats["stat_points_available"] > 0
	for btn in get_tree().get_nodes_in_group("stat_buttons"):
		btn.visible = can_add

func setup_hud(stats: StatsComponent, health: HealthComponent, sp: SPComponent,inventory_comp):
	if not is_node_ready():
		await ready
	
	var player = get_tree().get_first_node_in_group("player")
	player_stats = stats
	
	# --- Sincronizar VIDA ---
	# 1. Primero el MAX_VALUE
	hp_bar.max_value = health.max_health
	# 2. Luego el VALUE actual
	hp_bar.value = health.current_health
	# 3. Actualizar el label
	hp_value_label.text = "%d / %d" % [health.current_health, health.max_health]
	# 4. Finalmente conectar la señal para cambios futuros
	if not health.on_health_changed.is_connected(_on_hp_changed):
		health.on_health_changed.connect(_on_hp_changed)
	
	# --- Sincronizar SP (Si el componente existe) ---
	if sp and sp_bar:
		sp_value_label.text = "%d / %d" % [sp.current_sp, sp.max_sp]
		sp_bar.max_value = sp.max_sp
		sp_bar.value = sp.current_sp
		if not sp.on_sp_changed.is_connected(_on_sp_changed):
			sp.on_sp_changed.connect(_on_sp_changed)
	
	# --- Sincronizar XP y Nivel ---
	# Levels are now managed by GameManager, so we read from there
	level_label.text = "Base Lvl: " + str(GameManager.player_stats["level"])
	job_level_label.text = "Job Lvl: " + str(GameManager.player_stats["job_level"])
	job_name_label.text =  GameManager.player_stats["job_name"]
	
	# Update exp bars with current GameManager values
	var base_req = GameManager.get_required_exp(GameManager.player_stats["level"], false)
	_on_xp_changed(GameManager.player_stats["base_exp"], base_req)
	var job_req = GameManager.get_required_exp(GameManager.player_stats["job_level"], true)
	_update_job_bar(GameManager.player_stats["job_exp"], job_req)
		
	if inventory_window:
		inventory_window.setup_inventory(inventory_comp)
	equipment_ui.set_player(player)
	
	if not player_stats.stats_changed.is_connected(refresh_ui):
		player_stats.stats_changed.connect(refresh_ui)
	
	# Setup status effect manager UI
	if player.has_node("StatusEffectManagerComponent"):
		var status_mgr = player.get_node("StatusEffectManagerComponent")
		if not status_mgr.effect_started.is_connected(_on_status_effect_started):
			status_mgr.effect_started.connect(_on_status_effect_started)
		if not status_mgr.effect_ended.is_connected(_on_status_effect_ended):
			status_mgr.effect_ended.connect(_on_status_effect_ended)
		if not status_mgr.effect_refreshed.is_connected(_on_status_effect_refreshed):
			status_mgr.effect_refreshed.connect(_on_status_effect_refreshed)
	
	# Setup skill component for cast bar
	if player.has_node("SkillComponent"):
		var skill_comp = player.get_node("SkillComponent")
		if not skill_comp.cast_started.is_connected(_on_cast_started):
			skill_comp.cast_started.connect(_on_cast_started)
		if not skill_comp.cast_interrupted.is_connected(_on_cast_ended):
			skill_comp.cast_interrupted.connect(_on_cast_ended)
		if not skill_comp.cast_completed.is_connected(_on_cast_ended):
			skill_comp.cast_completed.connect(_on_cast_ended)

	# --- Setup Zeny (Currency) ---
	if inventory_comp and inventory_comp.has_signal("zeny_changed"):
		if not inventory_comp.zeny_changed.is_connected(_on_zeny_changed):
			inventory_comp.zeny_changed.connect(_on_zeny_changed)
		# Force initial update
		_on_zeny_changed(inventory_comp.zeny)

	refresh_ui()
	
func setup_hotbar_ui():
	# Obtener los hijos (los slots) y configurarlos
	var i = 0
	if hotbar_container:
		for child in hotbar_container.get_children():
			if child is HotbarSlot:
				child.setup(i, str(i + 1)) # Asigna índice y tecla (1-9)
				child.parent_hud = self # Pasar referencia al HUD
				# Conectar señales de hover
				if not child.slot_hover.is_connected(_on_hotbar_slot_hover):
					child.slot_hover.connect(_on_hotbar_slot_hover)
				if not child.slot_exit.is_connected(_on_hotbar_slot_exit):
					child.slot_exit.connect(_on_hotbar_slot_exit)
				slots.append(child)
				i += 1

func update_hotbar_slot(index: int, content, amount: int = 0):
	if index >= 0 and index < slots.size():
		slots[index].update_slot(content, amount)

func show_pickup_message(item_name: String, amount: int):
	if not pickup_panel or not pickup_label:
		return
	pickup_label.text = "+%dx %s" % [amount, item_name]
	pickup_panel.visible = true
	pickup_panel.modulate = Color(1, 1, 1, 1)
	pickup_panel.position = _pickup_base_pos
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(pickup_panel, "position:y", _pickup_base_pos.y - 24.0, 0.35)
	tween.parallel().tween_property(pickup_panel, "modulate:a", 0.0, 0.5).set_delay(0.75)
	tween.chain().tween_callback(func():
		pickup_panel.visible = false
		pickup_panel.modulate.a = 1.0
		pickup_panel.position = _pickup_base_pos
	)

func show_skill_label(skill_name: String):
	armed_skill_label.text = ">> " + skill_name.to_upper() + " <<"
	armed_skill_label.visible = true

func hide_skill_label():
	armed_skill_label.visible = false	

func update_armed_skill_info(skill_name: String):
	if skill_name == "":
		armed_skill_label.text = ""
		armed_skill_label.hide()
	else:
		armed_skill_label.text = ">>> " + skill_name.to_upper() + " <<<"
		armed_skill_label.show()
		# Opcional: darle un color cian para que resalte
		armed_skill_label.modulate = Color.CYAN

func _modify_stat(stat_name: String):
	var current_val = player_stats.get(stat_name)
	
	# 1. Calcular el costo según tu regla (progresivo)
	var cost = _get_upgrade_cost(current_val)
	
	# 2. Verificar si tiene puntos suficientes para ese costo específico
	if GameManager.player_stats["stat_points_available"] >= cost:
		# Aumentar el stat
		player_stats.set(stat_name, current_val + 1)
		
		# Restar los puntos según el costo calculado
		GameManager.player_stats["stat_points_available"] -= cost
		
		# 3. Lógica especial para VIT
		if stat_name == "vit":
			_update_player_max_hp()
			
		# 4. Refrescar la UI y Log
		refresh_ui()
		add_log_message("Aumentaste %s a %d (Costo: %d pts)" % [stat_name.to_upper(), current_val + 1, cost], Color.AQUA)
	else:
		# Opcional: Avisar que no tiene suficientes puntos
		add_log_message("Puntos insuficientes. Necesitas %d para subir %s" % [cost, stat_name.to_upper()], Color.ORANGE_RED)

# --- Función auxiliar de costo (Punto 2 de tu lista) ---
func _get_upgrade_cost(current_value: int) -> int:
	# Aquí aplicamos tu regla: < 20 cuesta 1, >= 20 cuesta 2, etc.
	if current_value < 20:
		return 1
	elif current_value < 40:
		return 2
	elif current_value < 60:
		return 3
	else:
		return 4 # Puedes seguir escalando según desees
	
func _update_player_max_hp():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var health_comp = player.get_node("HealthComponent")
		# Recalculamos: Base (100) + Bono por VIT
		var nuevo_max = 100 + player_stats.get_max_hp_bonus()
		
		health_comp.max_health = nuevo_max
		hp_bar.max_value = nuevo_max
		# Opcional: Curar al jugador la diferencia para que la barra no se vea vacía
		health_comp.current_health += 15 
		_on_hp_changed(health_comp.current_health)

func _input(event):

	if event.is_action_pressed("toggle_inventory"):
		inventory_window.visible = !inventory_window.visible

	if event.is_action_pressed("toggle_equipment"):
		if equipment_ui and equipment_ui.is_inside_tree():
			if not equipment_ui.visible and equipment_ui.player_path == NodePath():
				var player = get_tree().get_first_node_in_group("player")
				if player:
					equipment_ui.set_player(player)
			equipment_ui.visible = !equipment_ui.visible
	
	# Toggle Skills window
	if event.is_action_pressed("toggle_skills"):
		if skill_tree_ui and skill_tree_ui.is_inside_tree():
			skill_tree_ui.visible = !skill_tree_ui.visible
		get_viewport().set_input_as_handled()
		

	if event.is_action_pressed("toggle_stats"):
		if stats_panel and stats_panel.is_inside_tree():
			stats_panel.visible = !stats_panel.visible
			if stats_panel.visible:
				refresh_ui()
		get_viewport().set_input_as_handled()

func add_log_message(text: String, color: Color = Color.WHITE):
	if log_label:
		# Convertimos el color a formato Hex para BBCode
		var color_hex = color.to_html(false)
		var timestamp = Time.get_time_string_from_system().substr(0, 5) # [HH:MM]
		
		var formatted_text = "[color=#888888][%s][/color] [color=#%s]%s[/color]\n" % [timestamp, color_hex, text]
		
		log_label.append_text(formatted_text)

# --- Actualización de Barras ---

func _on_hp_changed(current_hp):
	if hp_bar:
		hp_bar.value = current_hp
		hp_value_label.text = "%d / %d" % [current_hp, int(hp_bar.max_value)]
	
func _on_sp_changed(current_sp, max_sp):
	sp_bar.max_value = max_sp
	sp_bar.value = current_sp
	sp_value_label.text = "%d / %d" % [current_sp, max_sp]
	sp_bar.value = current_sp

func update_exp_bar():
	if exp_bar:
		var req_exp = GameManager.get_required_exp(GameManager.player_stats["level"], false)
		exp_bar.max_value = req_exp
		exp_bar.value = GameManager.player_stats["base_exp"]

# --- Actualización de Ventana de Stats ---

func _on_level_up(new_level):
	level_label.text = "Base Lvl: " + str(new_level)
	update_exp_bar()
	refresh_ui()

func _on_job_level_up(new_level):
	job_level_label.text = "Job Lvl: " + str(new_level)
	job_name_label.text = "(" + GameManager.player_stats["job_name"] + ")"
	update_exp_bar()
	refresh_ui()

func _on_add_str_pressed(): _modify_stat("str_stat")
func _on_add_agi_pressed(): _modify_stat("agi")
func _on_add_vit_pressed(): _modify_stat("vit")
func _on_add_int_pressed(): _modify_stat("int_stat")
func _on_add_dex_pressed(): _modify_stat("dex")
func _on_add_luk_pressed(): _modify_stat("luk")

func _on_xp_changed(current_xp, max_xp):
	if exp_bar:
		exp_bar.max_value = max_xp
		exp_bar.value = current_xp

func update_active_skill_display(skill_name: String):
	if skill_name == "":
		active_skill_label.text = ""
	else:
		active_skill_label.text = "Habilidad: " + skill_name
		active_skill_label.modulate = Color.CYAN

func propagate_cooldown(skill_name: String, duration: float):
	# Iteramos sobre los slots guardados
	for slot in slots:
		if slot is HotbarSlot:
			# Verificamos si este slot tiene la skill que entró en CD
			if slot.current_skill_name == skill_name:
				slot.start_cooldown_visual(duration)
				# Nota: No hacemos 'break' por si tienes la misma skill en 2 slots (raro pero posible)

# Callback cuando se asigna un item consumible al hotbar
func on_item_assigned_to_hotbar(slot_index: int, item: ItemData):
	# Obtener referencia al player para actualizar hotbar_content
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("_assign_item_to_hotbar"):
		player._assign_item_to_hotbar(slot_index, item)
	
	# Mostrar mensaje de éxito
	add_log_message("Asignado %s a slot %d" % [item.item_name, slot_index + 1], Color.LIGHT_GREEN)

# Nuevo callback que maneja la lógica de duplicados
func on_item_dropped_to_hotbar(target_slot_index: int, item: ItemData):
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	# Buscar si el item ya está en la hotbar
	var existing_slot_index = -1
	for i in range(player.hotbar_content.size()):
		var content = player.hotbar_content[i]
		if content is ItemData and content == item:
			existing_slot_index = i
			break
	
	if existing_slot_index >= 0:
		# El item ya existe en la hotbar: hacer swap
		if existing_slot_index != target_slot_index:
			# Intercambiar posiciones
			var temp = player.hotbar_content[target_slot_index]
			player.hotbar_content[target_slot_index] = player.hotbar_content[existing_slot_index]
			player.hotbar_content[existing_slot_index] = temp
			player.refresh_hotbar_to_hud()
			add_log_message("Movido %s a slot %d" % [item.item_name, target_slot_index + 1], Color.LIGHT_BLUE)
		# Si es el mismo slot, no hacer nada
	else:
		# El item NO está en la hotbar: asignarlo normalmente
		player.hotbar_content[target_slot_index] = item
		player.refresh_hotbar_to_hud()
		add_log_message("Asignado %s a slot %d" % [item.item_name, target_slot_index + 1], Color.LIGHT_GREEN)

# Callback para rechazar items no-consumibles
func reject_non_consumable_item(_item: ItemData):
	add_log_message("Solo se pueden asignar items consumibles", Color.ORANGE)


# Callback para hacer swap entre slots del hotbar
func on_hotbar_slot_swap(origin_slot_index: int, target_slot_index: int):
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	# Hacer swap en el array hotbar_content
	var temp = player.hotbar_content[target_slot_index]
	player.hotbar_content[target_slot_index] = player.hotbar_content[origin_slot_index]
	player.hotbar_content[origin_slot_index] = temp
	
	# Refrescar la UI del hotbar
	player.refresh_hotbar_to_hud()
	
	# Mensaje opcional
	add_log_message("Slots intercambiados", Color.LIGHT_BLUE)

# Callback para asignar una skill al hotbar

func on_skill_dropped_to_hotbar(target_slot_index: int, skill: SkillData):
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	# Buscar si la skill ya está en la hotbar
	var existing_slot_index = -1
	for i in range(player.hotbar_content.size()):
		var content = player.hotbar_content[i]
		if content is SkillData and content == skill:
			existing_slot_index = i
			break
	
	if existing_slot_index >= 0:
		# La skill ya existe en la hotbar: hacer swap
		if existing_slot_index != target_slot_index:
			var temp = player.hotbar_content[target_slot_index]
			player.hotbar_content[target_slot_index] = player.hotbar_content[existing_slot_index]
			player.hotbar_content[existing_slot_index] = temp
			player.refresh_hotbar_to_hud()
			add_log_message("Movida %s a slot %d" % [skill.skill_name, target_slot_index + 1], Color.LIGHT_BLUE)
		# Si es el mismo slot, no hacer nada
	else:
		# La skill NO está en la hotbar: asignarla normalmente
		player.hotbar_content[target_slot_index] = skill
		player.refresh_hotbar_to_hud()
		add_log_message("Asignada %s a slot %d" % [skill.skill_name, target_slot_index + 1], Color.LIGHT_CYAN)

# --- Status Effect UI Handlers ---

func _on_status_effect_started(status_data: StatusEffectData) -> void:
	if not status_effects_container:
		return
	
	# Crear indicator
	var indicator_scene = load("res://scenes/StatusEffectIndicator.tscn")
	if not indicator_scene:
		return
	
	var indicator = indicator_scene.instantiate()
	status_effects_container.add_child(indicator)
	indicator.setup(status_data, status_data.duration)
	
	# Guardar referencia
	active_effect_indicators[status_data.effect_name] = indicator
	
	# Log feedback
	add_log_message("Efecto: %s" % status_data.effect_name, Color.CYAN)

func _on_status_effect_ended(status_data: StatusEffectData) -> void:
	if status_data.effect_name in active_effect_indicators:
		var indicator = active_effect_indicators[status_data.effect_name]
		if indicator and is_instance_valid(indicator):
			indicator.queue_free()
		active_effect_indicators.erase(status_data.effect_name)

func _on_status_effect_refreshed(status_data: StatusEffectData, new_duration: float) -> void:
	if status_data.effect_name in active_effect_indicators:
		var indicator = active_effect_indicators[status_data.effect_name]
		if indicator and is_instance_valid(indicator):
			indicator.refresh_timer(new_duration)
			add_log_message("Efecto refrescado: %s" % status_data.effect_name, Color.YELLOW)



func _on_cast_started(skill_name: String, duration: float) -> void:
	if not cast_bar or not cast_label:
		return
	
	cast_bar.visible = true
	cast_bar.max_value = duration
	cast_bar.value = 0.0
	cast_label.text = skill_name
	
	# Tween para animar la barra de cast (se llena durante la duración)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(cast_bar, "value", duration, duration)

func _on_cast_ended() -> void:
	if not cast_bar:
		return
	
	cast_bar.visible = false

func update_enemy_debug_panel(enemy: Node3D) -> void:
	if not enemy_debug_panel:
		return
	
	if not enemy or not is_instance_valid(enemy):
		enemy_debug_panel.visible = false
		return
	
	# Get enemy data
	var enemy_data = enemy.data if enemy.has_meta("data") or enemy.get("data") else null
	
	if not enemy_data:
		enemy_debug_panel.visible = false
		return
	
	# Update name
	enemy_name_label.text = enemy_data.monster_name
	
	# Get enum names for display
	var size_names = ["SMALL", "MEDIUM", "LARGE"]
	var race_names = ["FORMLESS", "UNDEAD", "BRUTE", "PLANT", "INSECT", "FISH", "DEMON", "DEMI_HUMAN", "ANGEL", "DRAGON"]
	var element_names = ["NEUTRAL", "WATER", "EARTH", "FIRE", "WIND", "POISON", "HOLY", "SHADOW", "GHOST", "UNDEAD"]
	var movement_names = ["SLIDE", "JUMP", "SLITHER"]
	
	var size_str = size_names[enemy_data.type] if enemy_data.type < size_names.size() else "UNKNOWN"
	var race_str = race_names[enemy_data.race] if enemy_data.race < race_names.size() else "UNKNOWN"
	var element_str = element_names[enemy_data.element] if enemy_data.element < element_names.size() else "UNKNOWN"
	var movement_str = movement_names[enemy_data.movement_type] if enemy_data.movement_type < movement_names.size() else "UNKNOWN"
	
	# Update stats display
	enemy_stats_label.text = "Size: %s\nRace: %s\nElement: %s\nMovement: %s" % [size_str, race_str, element_str, movement_str]
	
	enemy_debug_panel.visible = true

func hide_enemy_debug_panel() -> void:
	if enemy_debug_panel:
		enemy_debug_panel.visible = false
	if cast_label:
		cast_label.text = ""


func _on_hotbar_slot_hover(resource: Resource) -> void:
	if not hotbar_tooltip or not resource:
		return
	
	if resource is SkillData:
		hotbar_tooltip_name.text = resource.skill_name
		hotbar_tooltip_desc.text = "SP Cost: %d | Cooldown: %.1fs" % [resource.sp_cost, resource.cooldown]
		hotbar_tooltip.visible = true
	elif resource is ItemData:
		hotbar_tooltip_name.text = resource.item_name
		hotbar_tooltip_desc.text = resource.description
		hotbar_tooltip.visible = true

func _on_hotbar_slot_exit() -> void:
	if hotbar_tooltip:
		hotbar_tooltip.visible = false

func _process(_delta):
	if hotbar_tooltip and hotbar_tooltip.visible:
		hotbar_tooltip.global_position = get_viewport().get_mouse_position() + Vector2(10, 10)

func _on_zeny_changed(amount: int):
	zeny_label.text = str(amount) + " Z"

func open_inventory_window():
	inventory_window.visible = true
	
func close_inventory_window():
	inventory_window.visible = false

func _update_job_bar(current, total):
	job_exp_bar.max_value = total
	job_exp_bar.value = current
	# Opcional: actualizar texto "Job Lv. 10"

func _on_skills_button_pressed() -> void:
	skill_tree_ui.visible = !skill_tree_ui.visible

func _on_equipment_button_pressed() -> void:
	equipment_ui.visible = !equipment_ui.visible
	
func _on_inventory_button_pressed() -> void:
	inventory_window.visible = !inventory_window.visible

func _on_stats_button_pressed() -> void:
	stats_panel.visible = !stats_panel.visible
