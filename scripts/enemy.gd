extends CharacterBody3D

@export var data: EnemyData 

@onready var nav_agent = $NavigationAgent3D
@onready var health_comp = $HealthComponent
@onready var health_bar = $HealthBar3D
@onready var mob_name: Label3D = $Label3D
@onready var stats_comp: StatsComponent = $StatsComponent

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

func _ready():
	if not data:
		push_error("Error: " + name + " no tiene EnemyData asignado.")
		return
		
	# 1. Instanciar el modelo visual
	if data.model_scene:
		var model_instance = data.model_scene.instantiate()
		add_child(model_instance)
		mesh = model_instance

	# 2. Inicializar StatsComponent con los datos del Resource
	if stats_comp:
		stats_comp.initialize_from_resource(data)

	# 3. Inicialización de Vida (HP Base + Bono de VIT)
	var total_max_hp = data.max_hp + stats_comp.get_max_hp_bonus()
	health_comp.max_health = total_max_hp
	health_comp.current_health = total_max_hp
	health_comp.on_health_changed.connect(_on_take_damage)
	health_comp.on_death.connect(_on_death)
	
	# 4. UI y Visuales
	if health_bar:
		health_bar.update_bar(total_max_hp, total_max_hp)
	if mob_name:
		mob_name.set_text(data.monster_name)
	
	player = get_tree().get_first_node_in_group("player")
	
	if data.type == "Boss":
		scale = Vector3(2.0, 2.0, 2.0)

func _physics_process(delta):
	if is_stunned or not data: return

	if player and !player.is_dead:
		var dist_to_player = global_position.distance_to(player.global_position)
		
		# Sincronización de Aggro
		if dist_to_player <= data.aggro_range:
			is_aggroed = true
		elif dist_to_player > data.lose_aggro_range:
			is_aggroed = false

		if is_aggroed:
			# USAMOS UN PEQUEÑO MARGEN (Offset)
			# A veces el origen del modelo está en los pies y el del player en el centro.
			if dist_to_player <= data.attack_range:
				# PRIORIDAD: Detener navegación para que no "resbale"
				nav_agent.get_next_path_position() # Limpiar buffer
				velocity = Vector3.ZERO
				attack_player()
			else:
				current_state = State.CHASING
				chase_target(player.global_position, data.move_spd)
		else:
			patrol_logic(delta)
	else:
		is_aggroed = false
		patrol_logic(delta)

	move_and_slide()

func patrol_logic(delta):
	# Fijar posición inicial si es la primera vez
	if home_position == Vector3.ZERO:
		home_position = global_position
		_pick_next_wander_point()

	match current_state:
		State.IDLE:
			velocity = velocity.move_toward(Vector3.ZERO, 0.5) # Frenado suave
			move_and_slide()
			wander_timer -= delta
			if wander_timer <= 0:
				_pick_next_wander_point()
				current_state = State.WANDERING
		
		State.WANDERING, State.CHASING: # Al patrullar usamos lógica de persecución hacia el punto
			var dist_to_dest = global_position.distance_to(wander_target)
			
			if dist_to_dest < 1.5 or nav_agent.is_navigation_finished():
				current_state = State.IDLE
				wander_timer = randf_range(data.idle_time_min, data.idle_time_max)
			else:
				chase_target(wander_target, data.move_spd * data.movement_speed_factor)
		
		State.ATTACKING:
			# En estado de ataque, si el jugador se aleja, volvemos a perseguir
			pass

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
	
	velocity = (next_pos - current_pos).normalized() * movement_speed
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
	is_stunned = true
	velocity = Vector3.ZERO
	
	if mesh: # Solo crear el tween SI tenemos el mesh listo
		var tween = create_tween()
		tween.tween_property(mesh, "scale", Vector3(1.3, 0.7, 1.3), 0.1)
		tween.tween_property(mesh, "scale", Vector3(1, 1, 1), 0.1)
	
	await get_tree().create_timer(0.2).timeout
	is_stunned = false

func _on_death():
	if is_dead: return # Si ya está muriendo, ignorar
	is_dead = true
	get_tree().call_group("hud", "add_log_message", 
		"Derrotaste a %s!" % data.monster_name, 
		Color.WHITE)
	# 1. Desactivar colisiones e interacciones inmediatamente
	# Esto evita que el jugador lo pueda seguir clickeando o golpeando
	if has_node("CollisionShape3D"):
		$CollisionShape3D.disabled = true
	
	# 2. Detener toda la lógica
	set_physics_process(false)
	set_process(false)
	is_stunned = true
	
	# 3. Dar XP al jugador
	if player and player.has_node("StatsComponent"):
		player.get_node("StatsComponent").add_xp(data.base_exp)

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

func _play_aggro_effect():
	if mesh:
		var tween = create_tween()
		tween.tween_property(mesh, "position:y", 0.5, 0.1).as_relative()
		tween.chain().tween_property(mesh, "position:y", -0.5, 0.1).as_relative()
