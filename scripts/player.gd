extends CharacterBody3D

@export var speed: float = 5.0
@export var attack_damage: int = 25
@export var attack_range: float = 2.0
@export var click_indicator_path: NodePath
@export var cursor_default: Texture2D
@export var cursor_attack: Texture2D
@export var cursor_skill: Texture2D

@export_group("Skills")
@export var skill_1: SkillData

@export_group("Prefabs")
@export var floating_text_scene: PackedScene
@export var level_up_effect_scene: PackedScene

@onready var skill_component = $SkillComponent
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var click_indicator: MeshInstance3D = get_node_or_null(click_indicator_path)
@onready var health_component: HealthComponent = $HealthComponent
@onready var game_over_ui: CanvasLayer = $GameOverUI
@onready var hud: CanvasLayer = $"../Hud"
@onready var stats: Node = $StatsComponent
@onready var sp_component: SPComponent = $SPComponent

# --- Variables de Ataque y Control ---
var last_attack_time: int = 0
var is_clicking: bool = false
var is_dead: bool = false 
var is_stunned = false
var current_target_enemy = null
var can_attack_player: bool = true

func _ready():
	# 1. Calcular y setear vida inicial
	var max_hp_calculado = 100 + stats.get_max_hp_bonus()
	health_component.max_health = max_hp_calculado
	health_component.current_health = max_hp_calculado # Llenar vida
	skill_component.setup(self, stats, sp_component)
	# 2. Si tienes SPComponent, inicializarlo (Asumiendo que el nodo se llama SPComponent)
	var sp_comp = get_node_or_null("SPComponent")
	if sp_comp:
		sp_comp.setup(stats) # Esto debería poner el SP al máximo dentro del componente
	
	# 3. Configurar HUD pasando los 3 componentes
	if hud:
		# Pasamos stats, health y el sp_comp (que puede ser null si no existe)
		hud.setup_hud(stats, health_component, sp_comp)
	
	# Conexiones adicionales
	health_component.on_health_changed.connect(_on_player_hit)
	health_component.on_death.connect(_on_player_death)

func _unhandled_input(event):
	if is_dead: return

	# SHORTCUTS
	if event.is_action_pressed("skill_1"):
		_on_skill_shortcut_pressed(skill_1)

	# CLICK DERECHO (cancelar)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if skill_component.armed_skill:
			skill_component.cancel_cast()

	# CLICK IZQUIERDO: manejar PRESIONADO y LIBERADO explícitamente
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_clicking = true
			if skill_component.armed_skill:
				_handle_skill_target_selection()
			else:
				handle_click_interaction()
		else:
			# solo cuando se suelta el botón izquierdo
			is_clicking = false

	# Opcional: actualizar cursor cuando el mouse se mueve (menos raycasts que cada frame)
	if event is InputEventMouseMotion:
		update_cursor()

func _physics_process(_delta):
	if is_dead or is_stunned: return
	if is_clicking and not skill_component.armed_skill:
		_process_continuous_interaction()
	# LÓGICA DE AUTO-ATAQUE: Si tenemos un objetivo, lo perseguimos y atacamos
	if current_target_enemy and is_instance_valid(current_target_enemy):
		var dist = global_position.distance_to(current_target_enemy.global_position)
		if dist <= attack_range:
			execute_attack(current_target_enemy)
		else:
			# Si está lejos, movernos hacia él
			nav_agent.target_position = current_target_enemy.global_position
	
	elif is_clicking:
		move_to_mouse_position()

	if nav_agent.is_navigation_finished():
		return

	var next_path_pos = nav_agent.get_next_path_position()
	velocity = (next_path_pos - global_position).normalized() * speed
	var target_flat = Vector3(next_path_pos.x, global_position.y, next_path_pos.z)
	if velocity.length() > 0.1:
		if global_position.distance_to(target_flat) > 0.1:
			look_at(target_flat, Vector3.UP)
	update_cursor()
	move_and_slide()

func _process_continuous_interaction():
	var result = get_mouse_world_interaction()
	if not result: return
	
	if result.collider.is_in_group("enemy"):
		# CASO A: Estamos clickeando un enemigo
		var enemy = result.collider
		current_target_enemy = enemy
		var dist = global_position.distance_to(enemy.global_position)
		
		if dist <= attack_range:
			# Si estamos en rango, nos detenemos y atacamos
			nav_agent.target_position = global_position
			execute_attack(enemy)
		else:
			# Si estamos lejos, lo perseguimos
			nav_agent.target_position = enemy.global_position
			
	else:
		# CASO B: Estamos clickeando el suelo
		current_target_enemy = null
		nav_agent.target_position = result.position

# --- FUNCIONES AUXILIARES DE MOVIMIENTO ---

func handle_click_interaction():
	var result = get_mouse_world_interaction()
	if result:
		var collider = result.collider
		var is_attack_click = collider.is_in_group("enemy")
		
		spawn_flash_effect(result.position, is_attack_click)
		
		if is_attack_click:
			current_target_enemy = collider
		else:
			current_target_enemy = null # Si clicamos suelo, cancelamos ataque

func move_to_mouse_position():
	if current_target_enemy != null and is_instance_valid(current_target_enemy):
		# Opcional: Aquí podrías hacer que persiga al enemigo. 
		# Por ahora, si clicamos enemigo, no movemos el punto de navegación al suelo
		# para evitar caminar "dentro" del enemigo.
		pass 
	else:
		# Lógica normal de caminar al suelo
		var result = get_mouse_world_interaction()
		if result:
			nav_agent.target_position = result.position

#func get_mouse_world_interaction():
#	var camera = get_viewport().get_camera_3d()
#	var mouse_pos = get_viewport().get_mouse_position()
#	var ray_origin = camera.project_ray_origin(mouse_pos)
#	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 2000
#	var space_state = get_world_3d().direct_space_state
#	
#	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
#	query.exclude = [get_rid()]
#	return space_state.intersect_ray(query)

func get_mouse_world_interaction():
	var camera = get_viewport().get_camera_3d()
	if not camera: return null
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 2000
	var space_state = get_world_3d().direct_space_state

	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [get_rid()]
	var result = space_state.intersect_ray(query)
	if not result: # intersect_ray devuelve {} si no choca
		return null
	return result

func update_cursor():
	var result = get_mouse_world_interaction()
	
	if result and result.collider.is_in_group("enemy"):
		# Cambiar a cursor de ataque
		Input.set_custom_mouse_cursor(cursor_attack, Input.CURSOR_ARROW, Vector2(16, 16))
	else:
		# Volver al cursor normal
		Input.set_custom_mouse_cursor(cursor_default, Input.CURSOR_ARROW, Vector2(0, 0))

# --- FUNCIONES AUXILIARES DE ATAQUE ---

func try_attack_enemy(enemy):
	var dist = global_position.distance_to(enemy.global_position)
	if dist <= attack_range - 0.2:
		if enemy.has_node("HealthComponent"):
			enemy.get_node("HealthComponent").take_damage(attack_damage)
	else:
		nav_agent.target_position = enemy.global_position

func execute_attack(enemy):
	if not can_attack_player or is_dead: return
	
	var enemy_health = enemy.get_node_or_null("HealthComponent")
	var enemy_data = enemy.data

	if enemy_health and enemy_data and stats:
		can_attack_player = false
		# TODO: ESTO TEDRIA QUE ESTAR EN STATSCOMPONENTS COMO LOS DEMAS CALCULOS
		var hit_chance_percent = (stats.get_hit() - enemy_data.flee) + 80
		hit_chance_percent = clamp(hit_chance_percent, 5, 95)
		
		var is_hit = (randi() % 100) < hit_chance_percent
		
		if not is_hit:
			get_tree().call_group("hud", "add_log_message", "Fallaste contra " + enemy_data.monster_name, Color.SKY_BLUE)
			spawn_floating_text(enemy.global_position, 0, true)
		else:
			var final_damage = max(1, stats.get_atk() - enemy_data.def)
			get_tree().call_group("hud", "add_log_message", "Golpeaste a %s por %d" % [enemy_data.monster_name, final_damage], Color.WHITE)
			enemy_health.take_damage(final_damage)
			spawn_floating_text(enemy.global_position, final_damage, false)
		
		await get_tree().create_timer(stats.get_attack_speed()).timeout 
		can_attack_player = true

func _on_player_hit(new_health):
	if has_node("HealthBar3D") and has_node("HealthComponent"):
		var max_hp = health_component.max_health
		$HealthBar3D.update_bar(new_health, max_hp)
	# 2. Stun / Flinch
	is_stunned = true
	velocity = Vector3.ZERO
	# Interrumpimos el click para que el jugador tenga que volver a dar la orden (opcional, da tensión)
	#is_clicking = false 
	nav_agent.target_position = global_position # Cancelar ruta actual
	
	# 3. Feedback Visual
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y + 0.05, 0.05)
	tween.chain().tween_property(self, "position:y", position.y, 0.1)

	await get_tree().create_timer(0.3).timeout # Tiempo de flinch
	is_stunned = false

func _on_player_death():
	if is_dead: return # Evitar que se ejecute dos veces
	
	is_dead = true
	is_clicking = false
	velocity = Vector3.ZERO
	
	print("El jugador ha muerto")
	
	# 1. Feedback visual de muerte (caerse de lado)
	var tween = create_tween()
	tween.tween_property(self, "rotation:z", deg_to_rad(-90), 0.5).set_trans(Tween.TRANS_BOUNCE)
	
	# 2. Mostrar la UI de Revivir
	if game_over_ui:
		game_over_ui.visible = true
		# Hacer visible el mouse para que el jugador pueda hacer clic en el botón
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# --- FUNCIONES AUXILIARES DE SKILLS ---

func _on_skill_shortcut_pressed(skill: SkillData):
	# Detener al jugador inmediatamente
	nav_agent.target_position = global_position
	velocity = Vector3.ZERO
	# Armar la skill en el componente
	skill_component.arm_skill(skill)

func _handle_skill_target_selection():
	var result = get_mouse_world_interaction()
	if result and result.collider.is_in_group("enemy"):
		var enemy = result.collider
		var dist = global_position.distance_to(enemy.global_position)
		
		if dist <= skill_component.armed_skill.cast_range:
			# Mirar al enemigo antes de disparar
			look_at(Vector3(enemy.global_position.x, global_position.y, enemy.global_position.z), Vector3.UP)
			skill_component.execute_armed_skill(enemy)
		else:
			get_tree().call_group("hud", "add_log_message", "Fuera de rango", Color.ORANGE)
	else:
		print("Selecciona un enemigo válido")

func try_use_skill():
	if current_target_enemy and is_instance_valid(current_target_enemy):
		var distance = global_position.distance_to(current_target_enemy.global_position)
		
		if distance <= skill_1.cast_range:
			# 1. Detener el movimiento del NavigationAgent
			nav_agent.target_position = global_position 
			velocity = Vector3.ZERO
			
			# 2. Mirar al enemigo (solo en el eje Y para no rotar raro)
			look_at(Vector3(current_target_enemy.global_position.x, global_position.y, current_target_enemy.global_position.z), Vector3.UP)
			
			# 3. Intentar ejecutar
			skill_component.execute_skill(skill_1, current_target_enemy)
		else:
			print("Demasiado lejos")

# --- FUNCIONES AUXILIARES MISC ---

func spawn_floating_text(pos: Vector3, value: int, is_miss: bool):
	if not floating_text_scene: return
	var txt_instance = floating_text_scene.instantiate()
	get_tree().current_scene.add_child(txt_instance)
	txt_instance.global_position = pos + Vector3(0, 1.5, 0)
	txt_instance.set_values_and_animate(value, is_miss)

func spawn_flash_effect(pos, is_attack = false):
	if click_indicator:
		click_indicator.global_position = pos + Vector3(0, 0.05, 0)
		click_indicator.visible = true
		click_indicator.transparency = 0.0
		
		var tween = get_tree().create_tween().set_parallel(true)
		var mat = click_indicator.get_active_material(0)
		
		if is_attack:
			if mat: mat.albedo_color = Color(1, 0, 0)
			click_indicator.scale = Vector3(0.1, 0.1, 0.1)
			tween.tween_property(click_indicator, "scale", Vector3(1.8, 1.8, 1.8), 0.2)
			tween.tween_property(click_indicator, "transparency", 1.0, 0.2)
		else:
			if mat: mat.albedo_color = Color(0, 0.8, 1)
			click_indicator.scale = Vector3(0.1, 0.1, 0.1)
			tween.tween_property(click_indicator, "scale", Vector3(1.2, 1.2, 1.2), 0.3)
			tween.tween_property(click_indicator, "transparency", 1.0, 0.3)
		
		tween.chain().tween_callback(func(): click_indicator.visible = false)

func _on_level_up(new_level: int):
	get_tree().call_group("hud", "add_log_message", 
		"Has alcanzado el nivel " + str(new_level), 
		Color.GOLD)
	show_level_up_text(new_level)

func show_level_up_text(level: int):
	var text = preload("res://effects/LevelUpEffect.tscn").instantiate()
	text.position = Vector3(0, 1.8, 0) # sobre la cabeza
	add_child(text)

	# Opcional: pasarle el nivel
	if text.has_method("set_level"):
		text.set_level(level)

func show_level_up():
	var text = preload("res://effects/LevelUpEffect.tscn").instantiate()
	text.position = Vector3(0, 1.8, 0) # arriba de la cabeza
	add_child(text)
