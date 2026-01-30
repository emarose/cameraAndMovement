extends CharacterBody3D

@export var data: EnemyData 

@onready var nav_agent = $NavigationAgent3D
@onready var health_comp = $HealthComponent
@onready var health_bar = $HealthBar3D
@onready var mob_name: Label3D = $Label3D
@onready var stats_comp: StatsComponent = $StatsComponent
@onready var skill_comp: SkillComponent = $SkillComponent

enum State { IDLE, WANDERING, CHASING, ATTACKING }

var current_state = State.IDLE
var player = null
var mesh = null
var is_dead: bool = false
var wander_target: Vector3
var wander_timer: float = 0.0
var home_position: Vector3 = Vector3.ZERO
var can_attack: bool = true
var is_stunned: bool = false
var is_aggroed: bool = false

# Variables nuevas para el control de tiempo
var move_timer: float = 0.0
var is_jumping: bool = false

func _ready():
	if not data:
		push_error("Error: " + name + " no tiene EnemyData asignado.")
		return
		
	# Setup visual y stats
	if data.model_scene:
		var model_instance = data.model_scene.instantiate()
		add_child(model_instance)
		mesh = model_instance

	if stats_comp:
		stats_comp.initialize_from_resource(data)

	var total_max_hp = data.max_hp + stats_comp.get_max_hp_bonus()
	health_comp.max_health = total_max_hp
	health_comp.current_health = total_max_hp
	health_comp.on_health_changed.connect(_on_take_damage)
	health_comp.on_death.connect(_on_death)

	if health_bar:
		health_bar.update_bar(total_max_hp, total_max_hp)
	if mob_name:
		mob_name.set_text(data.monster_name)
		
	player = get_tree().get_first_node_in_group("player")
	
	# Setup skill component if enemy has skills
	if skill_comp and data.skills.size() > 0:
		var sp_comp = get_node_or_null("SPComponent")
		if not sp_comp:
			sp_comp = SPComponent.new()
			add_child(sp_comp)
			sp_comp.setup(stats_comp)
		skill_comp.setup(self, stats_comp, sp_comp)
	
	# --- CONFIGURACIÓN DE EVITACIÓN ---
	# Conectamos la señal que nos da la velocidad segura calculada por el server de navegación
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	# Ajustamos el radio de evitación al tamaño del enemigo (puedes ajustarlo en el inspector)
	nav_agent.avoidance_enabled = true 
	
	if data.type == StatsComponent.Size.LARGE:
		scale = Vector3(2.0, 2.0, 2.0)

func _physics_process(delta):
	if (stats_comp and stats_comp.is_stunned) or is_dead or not data: return

	if player and !player.is_dead:
		var dist_to_player = global_position.distance_to(player.global_position)
		
		# Sincronización de Aggro
		if dist_to_player <= data.aggro_range:
			is_aggroed = true
		elif dist_to_player > data.lose_aggro_range:
			is_aggroed = false

		if is_aggroed:
			# Chance de usar skill si está disponible
			if data.skills.size() > 0 and randf() < data.skill_use_chance:
				_try_use_skill()
			
			if dist_to_player <= data.attack_range:
				# Detenerse para atacar
				_stop_movement()
				attack_player()
			else:
				current_state = State.CHASING
				_move_logic(player.global_position, data.move_spd)
		else:
			patrol_logic(delta)
	else:
		is_aggroed = false
		patrol_logic(delta)

func _move_logic(target_pos: Vector3, movement_speed: float):
	nav_agent.target_position = target_pos
	
	if nav_agent.is_navigation_finished():
		_stop_movement()
		return
	
	var next_pos = nav_agent.get_next_path_position()
	var direction = (next_pos - global_position).normalized()
	var final_velocity = Vector3.ZERO

	var speed_mult := (stats_comp.get_move_speed_modifier() if stats_comp else 1.0)

	match data.movement_type:
		StatsComponent.MovementType.SLIDE:
			# Movimiento constante normal
			final_velocity = direction * movement_speed * speed_mult
			
		StatsComponent.MovementType.JUMP:
			# Lógica tipo Poring: Avanza por impulsos
			move_timer += get_physics_process_delta_time()
			# Ciclo: 0.4s moviendo, 0.4s quieto (basado en jump_frequency)
			if move_timer >= data.jump_frequency:
				is_jumping = !is_jumping
				move_timer = 0.0
				if is_jumping: _visual_jump_effect() # Feedback visual
			
			if is_jumping:
				final_velocity = direction * (movement_speed * 1.5) * speed_mult # Salto rápido
			else:
				final_velocity = Vector3.ZERO # Pausa entre saltos
				
		StatsComponent.MovementType.SLITHER:
			# Lógica tipo Fabre: Movimiento serpenteante
			move_timer += get_physics_process_delta_time()
			# Añadimos un vector perpendicular que oscila con un Seno
			var side_dir = direction.cross(Vector3.UP) 
			var wave = side_dir * sin(move_timer * 5.0) * 0.5
			final_velocity = (direction + wave).normalized() * movement_speed * speed_mult

	# Rotación (siempre mirar a donde intenta ir, excepto si está quieto)
	if final_velocity.length() > 0.1:
		var look_target = Vector3(next_pos.x, global_position.y, next_pos.z)
		look_at(look_target, Vector3.UP)
	
	nav_agent.set_velocity(final_velocity)

func _visual_jump_effect():
	if mesh:
		var tween = create_tween()
		tween.tween_property(mesh, "position:y", 0.5, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(mesh, "position:y", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
func _on_velocity_computed(safe_velocity: Vector3):
	# Esta función se dispara automáticamente gracias a la conexión en _ready
	velocity = safe_velocity
	move_and_slide()

func _stop_movement():
	# Pedimos una velocidad de cero al sistema de evitación
	nav_agent.set_velocity(Vector3.ZERO)
	
func patrol_logic(delta):
	if home_position == Vector3.ZERO:
		home_position = global_position
		_pick_next_wander_point()

	match current_state:
		State.IDLE:
			_stop_movement()
			wander_timer -= delta
			if wander_timer <= 0:
				_pick_next_wander_point()
				current_state = State.WANDERING
		
		State.WANDERING:
			var dist_to_dest = global_position.distance_to(wander_target)
			if dist_to_dest < 1.0 or nav_agent.is_navigation_finished():
				current_state = State.IDLE
				wander_timer = randf_range(data.idle_time_min, data.idle_time_max)
			else:
				_move_logic(wander_target, data.move_spd * data.movement_speed_factor)
	
func _pick_next_wander_point():
	var random_direction = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	var random_dist = randf_range(data.wander_radius * 0.3, data.wander_radius)
	var target_pos = home_position + (random_direction * random_dist)
	
	var map = get_world_3d().navigation_map
	wander_target = NavigationServer3D.map_get_closest_point(map, target_pos)
	nav_agent.target_position = wander_target

func chase_target(target_pos: Vector3, movement_speed: float):
	nav_agent.target_position = target_pos
	
	if nav_agent.is_navigation_finished():
		velocity = Vector3.ZERO
		return
	
	var next_pos = nav_agent.get_next_path_position()
	var current_pos = global_position
	
	# Rotación hacia el siguiente punto del camino
	var look_target = Vector3(next_pos.x, current_pos.y, next_pos.z)
	if current_pos.distance_to(look_target) > 0.1:
		look_at(look_target, Vector3.UP)
	
	var speed_mult := (stats_comp.get_move_speed_modifier() if stats_comp else 1.0)
	velocity = (next_pos - current_pos).normalized() * movement_speed * speed_mult
	move_and_slide()

func attack_player():
	# Mirar al jugador mientras ataca
	var look_target = Vector3(player.global_position.x, global_position.y, player.global_position.z)
	if global_position.distance_to(look_target) > 0.1:
		look_at(look_target, Vector3.UP)
	
	if can_attack:
		can_attack = false
		
		# Obtener componentes del jugador para cálculos
		var p_stats = player.get_node_or_null("StatsComponent")
		var health_node = player.get_node_or_null("HealthComponent")
		
		if health_node:
			# --- LÓGICA DE HIT VS FLEE (Estilo RO) ---
			var chance = 1.0 # Por defecto acierta si no hay stats
			if p_stats:
				# Fórmula: 80% base + (Mi HIT - Su FLEE) / 100
				chance = 0.8 + (float(stats_comp.get_hit() - p_stats.get_flee()) / 100.0)
				chance = clamp(chance, 0.05, 0.95) # Siempre hay 5% de chance de fallar o acertar
			
			if randf() <= chance:
				
				# ACERTÓ EL GOLPE
				get_tree().call_group("hud", "add_log_message", 
		"Has recibido %d de daño de %s" % [stats_comp.get_atk(), data.monster_name], 
		Color.CRIMSON)
				health_node.take_damage(stats_comp.get_atk())
				if player.has_method("_on_player_hit"):
					player._on_player_hit(health_node.current_health)
				_play_attack_anim()
				
				# Chance de aplicar status effect
				if data.attack_status_effects.size() > 0 and randf() < data.status_effect_chance:
					_apply_random_status_effect(player)
			else:
				# FALLÓ EL GOLPE (MISS)
				get_tree().call_group("hud", "add_log_message", 
		"¡Esquivaste el ataque de %s!" % data.monster_name, 
		Color.SKY_BLUE)
				if player.has_method("_on_player_miss"): # Por si quieres mostrar un texto de "MISS"
					player._on_player_miss()
		
		# El cooldown ahora depende de la Agilidad y Destreza del enemigo
		await get_tree().create_timer(stats_comp.get_attack_speed()).timeout
		can_attack = true

func _play_attack_anim():
	if not mesh: return
	var tween = create_tween()
	# Un pequeño paso hacia adelante y atrás
	tween.tween_property(mesh, "position:z", -0.2, 0.1).as_relative()
	tween.tween_property(mesh, "position:z", 0.2, 0.1).as_relative()

func _on_take_damage(new_health):
	if health_bar:
		health_bar.update_bar(new_health, health_comp.max_health)
	if stats_comp:
		stats_comp.is_stunned = true
	velocity = Vector3.ZERO
	
	if mesh: # Solo crear el tween SI tenemos el mesh listo
		var tween = create_tween()
		tween.tween_property(mesh, "scale", Vector3(1.3, 0.7, 1.3), 0.1)
		tween.tween_property(mesh, "scale", Vector3(1, 1, 1), 0.1)
	
	await get_tree().create_timer(0.2).timeout
	if stats_comp:
		stats_comp.is_stunned = false

func _on_death():
	if is_dead: return # Si ya está muriendo, ignorar
	is_dead = true
	
	# IMPORTANTE: Capturar posición antes de desactivar el nodo
	var death_position = global_position
	
	get_tree().call_group("hud", "add_log_message", 
		"Derrotaste a %s!" % data.monster_name, 
		Color.WHITE)
	
	# Generar drops con la posición capturada
	_spawn_loot(death_position)
	
	# 1. Desactivar colisiones e interacciones inmediatamente
	# Esto evita que el jugador lo pueda seguir clickeando o golpeando
	if has_node("CollisionShape3D"):
		$CollisionShape3D.disabled = true
	
	# 2. Detener toda la lógica
	set_physics_process(false)
	set_process(false)
	if stats_comp:
		stats_comp.is_stunned = true
	
	# 3. Dar XP al jugador
	GameManager.gain_experience(data.base_exp, false) # Exp Base from resource
	GameManager.gain_experience(data.job_exp, true)   # Exp Job from resource
	
	# 4. Feedback Visual (Animación)
	if mesh:
		var tween = create_tween()
		# Usamos set_trans y set_ease para que se vea más profesional (RO style)
		tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(mesh, "rotation:x", deg_to_rad(-90), 0.4)
		tween.parallel().tween_property(mesh, "scale", Vector3.ZERO, 0.5)
		
		# Ocultar UI
		if health_bar: health_bar.hide()
		if mob_name: mob_name.hide()
		
		await tween.finished
	
	queue_free()

## Genera los drops loot según la tabla de drops del enemigo
func _spawn_loot(death_position: Vector3):
	if not data or data.drop_table.is_empty():
		return
		
	for drop_entry in data.drop_table:
		# Validar que sea un resource con los métodos necesarios
		if drop_entry and drop_entry.has_method("should_drop") and drop_entry.has_method("get_drop_quantity"):
			if drop_entry.should_drop():
				var quantity = drop_entry.get_drop_quantity()
				_create_item_drop(drop_entry.item_data, quantity, death_position)
		
func _create_item_drop(item_data: ItemData, quantity: int, spawn_position: Vector3):
	if not item_data:
		return
	
	# Cargar la escena de ItemDrop
	var item_drop_scene = load("res://scenes/ItemDrop.tscn")
	if not item_drop_scene:
		push_error("ItemDrop.tscn no encontrada")
		return
	
	# 1. Instanciar
	var item_drop = item_drop_scene.instantiate()
	
	# 2. Añadir al mundo PRIMERO (antes de mover)
	get_parent().add_child(item_drop)
	
	# 3. Ahora sí podemos usar global_position
	item_drop.global_position = spawn_position + Vector3(0, 1.0, 0)
	
	# 4. Configurar el drop (esto inicia animaciones)
	item_drop.setup(item_data, quantity)

func _try_use_skill() -> void:
	if not skill_comp or not player:
		return
	
	# Elegir skill aleatoria
	var available_skills = data.skills.filter(func(s): return skill_comp.can_use_skill(s))
	if available_skills.is_empty():
		return
	
	var skill = available_skills[randi() % available_skills.size()]
	
	# Usar según tipo de skill
	match skill.type:
		SkillData.SkillType.SELF:
			skill_comp.cast_immediate(skill)
		SkillData.SkillType.TARGET:
			if skill_comp.can_use_skill(skill):
				skill_comp.execute_armed_skill(player)
		SkillData.SkillType.POINT:
			# Usar en posición del jugador
			if skill_comp.can_use_skill(skill):
				skill_comp.armed_skill = skill
				skill_comp.execute_armed_skill(player.global_position)

func _apply_random_status_effect(target: Node) -> void:
	if data.attack_status_effects.is_empty():
		return
	
	var effect = data.attack_status_effects[randi() % data.attack_status_effects.size()]
	
	if target.has_node("StatusEffectManagerComponent"):
		var status_mgr = target.get_node("StatusEffectManagerComponent")
		status_mgr.add_effect(effect)
		get_tree().call_group("hud", "add_log_message", 
			"¡%s te infligió %s!" % [data.monster_name, effect.effect_name], 
			Color.ORANGE)

func _play_aggro_effect():
	if mesh:
		var tween = create_tween()
		tween.tween_property(mesh, "position:y", 0.5, 0.1).as_relative()
		tween.chain().tween_property(mesh, "position:y", -0.5, 0.1).as_relative()
