extends CanvasLayer

# --- Referencias Principales ---
@onready var hp_bar = $HealthBar
@onready var sp_bar = $ManaBar
@onready var exp_bar = $ExpBar
@onready var hp_value_label = $HealthBar/HPValueLabel
@onready var sp_value_label = $ManaBar/SPValueLabel

@onready var level_label = $LevelLabel
@onready var stats_panel = $StatsPanel
@onready var points_label = $StatsPanel/VBoxContainer_Base/PointsLabel
@onready var log_label: RichTextLabel = $PanelContainer/LogLabel
@onready var active_skill_label = $ActiveSkillLabel
@onready var armed_skill_label: RichTextLabel = $ArmedSkillLabel
@onready var pickup_panel: PanelContainer = $PickupPanel
@onready var pickup_label: Label = $PickupPanel/PickupLabel
@onready var inventory_window: Control = $InventoryUI

# --- Referencias a los Valores de Stats ---
@onready var str_label = $StatsPanel/VBoxContainer_Base/StrRow/Value
@onready var agi_label = $StatsPanel/VBoxContainer_Base/AgiRow/Value
@onready var vit_label = $StatsPanel/VBoxContainer_Base/VitRow/Value
@onready var int_label = $StatsPanel/VBoxContainer_Base/IntRow/Value
@onready var dex_label = $StatsPanel/VBoxContainer_Base/DexRow/Value
@onready var luk_label = $StatsPanel/VBoxContainer_Base/LukRow/Value

@onready var atk_val = $StatsPanel/VBoxContainer_Derived/AtkRow/Value
@onready var matk_val = $StatsPanel/VBoxContainer_Derived/MatkRow/Value
@onready var hit_val = $StatsPanel/VBoxContainer_Derived/HitRow/Value
@onready var flee_val = $StatsPanel/VBoxContainer_Derived/FleeRow/Value
@onready var aspd_val = $StatsPanel/VBoxContainer_Derived/AspdRow/Value
@onready var def_val = $StatsPanel/VBoxContainer_Derived/DefRow/Value
@onready var hotbar_container: HBoxContainer = $HotbarGrid
@onready var equipment_ui: EquipmentUI = $EquipmentUI

var slots: Array = []
var player_stats: StatsComponent
var current_skill_name: String = ""
var _pickup_base_pos := Vector2.ZERO

func _ready():
	# El HUD comienza oculto
	stats_panel.visible = false
	armed_skill_label.text = ""
	if pickup_panel:
		_pickup_base_pos = pickup_panel.position
		pickup_panel.visible = false
	setup_hotbar_ui()

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
	
func setup_hotbar_ui():
	# Obtener los hijos (los slots) y configurarlos
	var i = 0
	if hotbar_container:
		for child in hotbar_container.get_children():
			if child is HotbarSlot:
				child.setup(i, str(i + 1)) # Asigna índice y tecla (1-9)
				slots.append(child)
				i += 1

func update_hotbar_slot(index: int, content, amount: int = 0):
	if index >= 0 and index < slots.size():
		slots[index].update_slot(content, amount)

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
	level_label.text = "Nivel: " + str(stats.current_level)
	_on_xp_changed(stats.current_xp, stats.xp_to_next_level)
	if not stats.on_xp_changed.is_connected(_on_xp_changed):
		stats.on_xp_changed.connect(_on_xp_changed)
	if not stats.on_level_up.is_connected(_on_level_up):
		stats.on_level_up.connect(_on_level_up)
		
	if inventory_window:
		inventory_window.setup_inventory(inventory_comp)
	equipment_ui.set_player(player)
	update_stats_ui()

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
	# Ahora player_stats ya no será Nil
	if player_stats and player_stats.stat_points_available > 0:
		# 1. Aumentar el stat
		var current_val = player_stats.get(stat_name)
		player_stats.set(stat_name, current_val + 1)
		
		# 2. Restar punto disponible
		player_stats.stat_points_available -= 1
		
		# 3. Lógica especial para VIT (Actualizar vida máxima)
		if stat_name == "vit":
			_update_player_max_hp()
			
		# 4. Refrescar la UI
		update_stats_ui()
		add_log_message("Aumentaste %s a %d" % [stat_name.to_upper(), current_val + 1], Color.AQUA)

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
		
	# Abrir/Cerrar menú con la tecla C (debes configurarla en Input Map)
	if event.is_action_pressed("toggle_stats"):
		stats_panel.visible = !stats_panel.visible
		if stats_panel.visible:
			update_stats_ui()

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
	if exp_bar and player_stats:
		exp_bar.max_value = player_stats.xp_to_next_level
		exp_bar.value = player_stats.current_xp

# --- Actualización de Ventana de Stats ---

func _on_level_up(new_level):
	level_label.text = "Nivel: " + str(new_level)
	update_exp_bar()
	update_stats_ui()

func update_stats_ui():
	if not player_stats: return
	
	# 1. Stats Base (Lo que ya tenías)
	points_label.text = "Puntos: " + str(player_stats.stat_points_available)
	str_label.text = str(player_stats.str_stat)
	agi_label.text = str(player_stats.agi)
	vit_label.text = str(player_stats.vit)
	int_label.text = str(player_stats.int_stat)
	dex_label.text = str(player_stats.dex)
	luk_label.text = str(player_stats.luk)
	
	# 2. Sub-Stats Derivados (La columna derecha estilo RO)
	atk_val.text = str(player_stats.get_atk())
	matk_val.text = str(player_stats.get_matk())
	hit_val.text = str(player_stats.get_hit())
	flee_val.text = str(player_stats.get_flee())
	def_val.text = str(player_stats.get_def())
	aspd_val.text = str(player_stats.get_aspd())
	
	# Control de botones
	var can_add = player_stats.stat_points_available > 0
	for btn in get_tree().get_nodes_in_group("stat_buttons"):
		btn.visible = can_add

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
