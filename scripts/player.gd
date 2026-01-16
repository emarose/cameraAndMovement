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
var _last_cursor_state := "default" # "default", "attack", "skill"

var is_clicking: bool = false
var is_dead: bool = false 
var is_stunned = false
var current_target_enemy = null
var can_attack_player: bool = true
var is_attacking: bool = false

func _ready():

	# 1. Calcular y setear vida inicial
	var max_hp_calculado = 100 + stats.get_max_hp_bonus()
	health_component.max_health = max_hp_calculado
	health_component.current_health = max_hp_calculado
	skill_component.setup(self, stats, sp_component)
	var sp_comp = get_node_or_null("SPComponent")
	if sp_comp:
		sp_comp.setup(stats) 

	# 3. Configurar HUD pasando los 3 componentes
	if hud:
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
			if skill_component and skill_component.armed_skill:
				_handle_skill_target_selection()
			else:
				handle_click_interaction()
		else:
			is_clicking = false

	# Actualizar cursor cuando el mouse se mueve
	if event is InputEventMouseMotion:
		update_cursor()

func _start_attack_loop():
	# No bloqueamos movimiento aquí. Solo iniciamos el proceso que llevará al jugador a rango y luego atacará.
	if not current_target_enemy or not is_instance_valid(current_target_enemy):
		return
	if is_dead:
		return

	# Lanzamos la rutina asíncrona que se encargará de moverse hasta el objetivo y atacar cuando esté en rango
	_call_move_to_target_then_attack(current_target_enemy)

func _call_move_to_target_then_attack(enemy):
	if not enemy or not is_instance_valid(enemy):
		return

	# Loop: mientras el jugador mantenga el click y el enemigo sea válido
	while is_clicking and is_instance_valid(enemy) and not is_dead:
		var dist = global_position.distance_to(enemy.global_position)
		# Si estamos fuera de rango, movernos hacia el enemigo
		if dist > attack_range:
			# permitir navegación normal hacia el enemigo
			nav_agent.target_position = enemy.global_position
			# esperar un pequeño intervalo antes de re-evaluar (evita busy-wait)
			await get_tree().create_timer(0.08).timeout
			# si el jugador soltó el click, salimos
			if not is_clicking:
				break
			continue
		# Si llegamos aquí, estamos dentro de rango: bloquear movimiento y atacar
		is_attacking = true
		nav_agent.target_position = global_position
		velocity = Vector3.ZERO
		look_at(Vector3(enemy.global_position.x, global_position.y, enemy.global_position.z), Vector3.UP)

		# Ejecutar un ataque y esperar a que termine (execute_attack hace await del ASPD)
		await execute_attack(enemy)

		# Si el enemigo murió o el jugador soltó el click, salimos del loop
		if not is_clicking or not is_instance_valid(enemy) or is_dead:
			break

	# Liberar estado de ataque al salir
	is_attacking = false

func _stop_attack_loop():
	# Desactiva el estado de ataque (al soltar el click)
	is_attacking = false

func _physics_process(_delta):
	if is_dead or is_stunned: return

	# Si estamos atacando, bloquear movimiento y no procesar navegación normal
	if is_attacking:
		# Asegurar que no nos movemos
		nav_agent.target_position = global_position
		velocity = Vector3.ZERO
		update_cursor()
		move_and_slide()
		return

	# Si mantenemos click y no hay skill armado, actualizar interacción continua
	if is_clicking and not skill_component.armed_skill:
		_process_continuous_interaction()

	# LÓGICA DE SEGUIR TARGET (solo seguimiento, no auto-ataque)
	if current_target_enemy and is_instance_valid(current_target_enemy):
		var dist = global_position.distance_to(current_target_enemy.global_position)
		# Si estamos en rango y el jugador está manteniendo click sobre el enemigo, el ataque lo maneja el loop
		# Si no está haciendo click, no atacamos automáticamente; solo nos acercamos si el jugador lo desea
		if is_clicking:
			# Si el jugador mantiene click y está en rango, el loop de ataque se encargará de ejecutar ataques
			if dist > attack_range:
				nav_agent.target_position = current_target_enemy.global_position
			else:
				nav_agent.target_position = global_position
		else:
			# Si no está clickeando, no atacamos automáticamente; opcional: acercarnos si queremos
			# nav_agent.target_position = current_target_enemy.global_position
			pass

	elif is_clicking:
		# Movimiento normal hacia la posición del mouse mientras se mantiene presionado
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
	if not result:
		return null
	return result

func update_cursor():
	var result = get_mouse_world_interaction()
	var hovering_enemy = false
	var within_skill_range = false

	if result and result.has("collider"):
		var col = result.collider
		if is_instance_valid(col) and col.is_in_group("enemy"):
			hovering_enemy = true
			if skill_component and skill_component.armed_skill:
				var cast_range = skill_component.armed_skill.cast_range
				if global_position.distance_to(col.global_position) <= cast_range:
					within_skill_range = true

	if within_skill_range:
		if _last_cursor_state != "skill":
			Input.set_custom_mouse_cursor(cursor_skill, Input.CURSOR_ARROW, Vector2(16, 16))
			_last_cursor_state = "skill"
		return

	if hovering_enemy:
		if _last_cursor_state != "attack":
			Input.set_custom_mouse_cursor(cursor_attack, Input.CURSOR_ARROW, Vector2(16, 16))
			_last_cursor_state = "attack"
	else:
		if _last_cursor_state != "default":
			Input.set_custom_mouse_cursor(cursor_default, Input.CURSOR_ARROW, Vector2(0, 0))
			_last_cursor_state = "default"

# --- FUNCIONES AUXILIARES DE ATAQUE ---

func try_attack_enemy(enemy):
	var dist = global_position.distance_to(enemy.global_position)
	if dist <= attack_range - 0.2:
		if enemy.has_node("HealthComponent"):
			enemy.get_node("HealthComponent").take_damage(attack_damage)
	else:
		nav_agent.target_position = enemy.global_position

func execute_attack(enemy) -> void:
	# Retorna cuando el ataque y su cooldown (ASPD) finalizan
	if not can_attack_player or is_dead: 
		return

	# Si el enemigo dejó de ser válido, salir
	if not enemy or not is_instance_valid(enemy):
		return

	# Bloqueo de movimiento mientras atacamos
	nav_agent.target_position = global_position
	velocity = Vector3.ZERO

	var enemy_health = enemy.get_node_or_null("HealthComponent")
	var enemy_data = enemy.data

	if enemy_health and enemy_data and stats:
		can_attack_player = false

		# Cálculo de hit
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

		# Esperar el tiempo de ataque (ASPD) antes de liberar can_attack_player
		await get_tree().create_timer(stats.get_attack_speed()).timeout
		can_attack_player = true

	# Al finalizar el ataque, si el jugador no mantiene click, liberamos is_attacking
	if not is_clicking:
		is_attacking = false

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

	if not result or not result.has("collider"):
		return

	var collider = result.collider
	if not is_instance_valid(collider) or not collider.is_in_group("enemy"):
		return

	# Validar que la skill esté armada
	if not skill_component or not skill_component.armed_skill:
		return

	var enemy = collider
	var dist = global_position.distance_to(enemy.global_position)

	# Usar cast_range desde la skill armada
	var cast_range = skill_component.armed_skill.cast_range
	if dist <= cast_range:
		look_at(Vector3(enemy.global_position.x, global_position.y, enemy.global_position.z), Vector3.UP)
		# Llamada diferida para evitar problemas de timing
		skill_component.call_deferred("execute_armed_skill", enemy)
	else:
		get_tree().call_group("hud", "add_log_message", "Fuera de rango", Color.ORANGE)

func try_use_skill():
	if current_target_enemy and is_instance_valid(current_target_enemy):
		var distance = global_position.distance_to(current_target_enemy.global_position)
		if distance <= skill_1.cast_range:
			nav_agent.target_position = global_position
			velocity = Vector3.ZERO
			look_at(Vector3(current_target_enemy.global_position.x, global_position.y, current_target_enemy.global_position.z), Vector3.UP)
			# Llamada diferida
			skill_component.call_deferred("execute_armed_skill", current_target_enemy)
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
