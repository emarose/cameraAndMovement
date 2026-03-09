extends CharacterBody3D

@export var data: EnemyData 
@export var flinch_duration: float = 0.1
@export var attack_anim_duration: float = 0.4  # Total duration of attack animation
## Fraction (0.0–1.0) through the attack animation at which damage is applied.
## Replaces the old absolute attack_hit_delay to stay in sync across any animation length.
@export_range(0.0, 1.0, 0.01) var attack_hit_frame_ratio: float = 0.5
## Max yaw turn speed in degrees per second. Set to 0 for instant snapping.
@export_range(0.0, 1440.0, 1.0) var turn_speed_deg: float = 540.0

@onready var nav_agent = $NavigationAgent3D
@onready var health_comp = $HealthComponent
@onready var health_bar = $HealthBar3D
@onready var mob_name: Label3D = $Label3D
@onready var stats_comp: StatsComponent = $StatsComponent
@onready var skill_comp: SkillComponent = $SkillComponent
@onready var state_machine: StateMachine = $StateMachine
@onready var collision_shape_node: CollisionShape3D = get_node_or_null("CollisionShape3D")

enum State { IDLE, WANDERING, CHASING, ATTACKING }

var current_state = State.IDLE
var player = null
var mesh = null
var animation_tree: AnimationTree = null
var animation_player: AnimationPlayer = null
var is_dead: bool = false
var is_attacking: bool = false
var wander_target: Vector3
var wander_timer: float = 0.0
var home_position: Vector3 = Vector3.ZERO
var can_attack: bool = true
var is_stunned: bool = false
var is_aggroed: bool = false
var is_flinching: bool = false
var flinch_timer: float = 0.0

# Timer for skill usage attempts
var skill_attempt_timer: float = 0.0
var skill_attempt_interval: float = 1.0 # seconds between skill attempts

# Casting state variables
var is_casting: bool = false
var pending_skill: SkillData = null
var pending_target = null
var casting_tween: Tween = null
var casting_indicator: Node = null # Store indicator reference separately

# Variables nuevas para el control de tiempo
var move_timer: float = 0.0
var is_jumping: bool = false
var navigation_ready: bool = false

func _ready():
	if not data:
		push_error("Error: " + name + " no tiene EnemyData asignado.")
		return
		
	# Setup visual y stats
	if data.model_scene:
		var model_instance = data.model_scene.instantiate()
		add_child(model_instance)
		mesh = model_instance
		if model_instance is Node3D:
			_fit_collision_shape_from_model(model_instance)
		
		# Find AnimationTree in the model for state machine
		animation_tree = model_instance.get_node_or_null("AnimationTree")
		# Find AnimationPlayer inside the model (supports nested GLB hierarchies)
		_setup_animation_player(model_instance)

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

	# Esperar a que el mapa de navegación termine su primera sincronización
	await _wait_for_navigation_ready()
	
	if data.type == StatsComponent.Size.LARGE:
		scale = Vector3(2.0, 2.0, 2.0)
	
	# Initialize state machine for animations
	if state_machine and animation_tree:
		state_machine.setup(self, animation_tree)

func _physics_process(delta):
	if is_flinching:
		flinch_timer -= delta
		if flinch_timer <= 0.0:
			is_flinching = false

	if (stats_comp and stats_comp.is_stunned) or is_dead or not data:
		return
	if not navigation_ready:
		return

	# Keep locomotion animation in sync with actual velocity
	_update_locomotion_anim()

	if player and !player.is_dead:
		var dist_to_player = global_position.distance_to(player.global_position)
		# Sincronización de Aggro
		if dist_to_player <= data.aggro_range:
			is_aggroed = true
		elif dist_to_player > data.lose_aggro_range:
			is_aggroed = false

		if is_aggroed:
			# Try to use skills only every skill_attempt_interval seconds
			skill_attempt_timer -= delta
			if skill_attempt_timer <= 0.0:
				skill_attempt_timer = skill_attempt_interval
				if data.skills.size() > 0:
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
		_rotate_towards(look_target)
	
	nav_agent.set_velocity(final_velocity)

func _visual_jump_effect():
	if data:
		var resolved := _resolve_anim(data.anim_jump)
		if resolved != &"":
			animation_player.play(resolved)
			print("[%s] Playing jump animation '%s'" % [data.monster_name, resolved])
	
func _on_velocity_computed(safe_velocity: Vector3):
	# Esta función se dispara automáticamente gracias a la conexión en _ready
	velocity = safe_velocity
	move_and_slide()

func _stop_movement():
	# Pedimos una velocidad de cero al sistema de evitación
	nav_agent.set_velocity(Vector3.ZERO)

## Rebuilds the enemy collision from the current model (useful after changing model at runtime).
func refresh_collision_shape() -> void:
	if mesh and mesh is Node3D:
		_fit_collision_shape_from_model(mesh)
	
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
	if not navigation_ready:
		return
	var random_direction = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	var random_dist = randf_range(data.wander_radius * 0.3, data.wander_radius)
	var target_pos = home_position + (random_direction * random_dist)
	
	var map = get_world_3d().navigation_map
	wander_target = NavigationServer3D.map_get_closest_point(map, target_pos)
	nav_agent.target_position = wander_target

func _wait_for_navigation_ready() -> void:
	var map = get_world_3d().navigation_map
	if map == RID():
		return
	# Espera hasta que el mapa tenga al menos una iteración válida
	while NavigationServer3D.map_get_iteration_id(map) == 0:
		await NavigationServer3D.map_changed
	navigation_ready = true

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
		_rotate_towards(look_target)
	
	var speed_mult := (stats_comp.get_move_speed_modifier() if stats_comp else 1.0)
	velocity = (next_pos - current_pos).normalized() * movement_speed * speed_mult
	move_and_slide()

func attack_player():
	# Mirar al jugador mientras ataca
	var look_target = Vector3(player.global_position.x, global_position.y, player.global_position.z)
	if global_position.distance_to(look_target) > 0.1:
		_rotate_towards(look_target)
	
	if can_attack:
		can_attack = false
		is_attacking = true
		
		# --- RESOLVE WHICH ANIMATION TO PLAY ---
		var attack_anim: StringName = &""
		if data and animation_player:
			attack_anim = _resolve_anim(data.anim_attack)
		
		# --- READ ACTUAL ANIMATION LENGTH for perfectly synced hit timing ---
		var anim_length: float = attack_anim_duration  # fallback
		if animation_player and attack_anim != &"":
			var anim_res = animation_player.get_animation(attack_anim)
			if anim_res:
				anim_length = anim_res.length
		
		# --- PLAY ATTACK ANIMATION ---
		if animation_player and attack_anim != &"":
			animation_player.play(attack_anim)
			print("[%s] Playing attack animation '%s' (duration: %.2f)" % [data.monster_name, attack_anim, anim_length])
		else:
			print("[%s] No attack animation found, using fallback duration" % (data.monster_name if data else "?"))
		
		# --- WAIT FOR HIT FRAME ---
		# Hit delay is a ratio of actual animation length — stays in sync regardless of animation length.
		var actual_hit_delay: float = anim_length * attack_hit_frame_ratio
		await get_tree().create_timer(actual_hit_delay).timeout
		
		# Verify player is still valid after delay
		if not is_instance_valid(player) or player.is_dead:
			can_attack = true
			is_attacking = false
			return
		
		# --- APPLY DAMAGE AT HIT FRAME ---
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
				
				# Chance de aplicar status effect
				if data.attack_status_effects.size() > 0 and randf() < data.status_effect_chance:
					_apply_random_status_effect(player)
			else:
				# FALLÓ EL GOLPE (MISS)
				get_tree().call_group("hud", "add_log_message", 
					"¡Esquivaste el ataque de %s!" % data.monster_name, 
					Color.SKY_BLUE)
				if player.has_method("_on_player_miss"):
					player._on_player_miss()
		
		# --- WAIT FOR ANIMATION TO TRULY FINISH ---
		# Using animation_finished signal guarantees the skeleton won't snap mid-swing.
		if animation_player and animation_player.is_playing():
			await animation_player.animation_finished
		
		is_attacking = false
		
		# --- ASPD COOLDOWN ---
		# Any remaining time beyond the animation length before next attack.
		var cooldown_time: float = stats_comp.get_attack_speed() - anim_length
		if cooldown_time > 0.0:
			await get_tree().create_timer(cooldown_time).timeout
		
		can_attack = true

# Deprecated: Attack logic moved inline to attack_player() for better animation sync.
# Kept for reference but no longer called.
func _trigger_attack_state_DEPRECATED():
	is_attacking = true
	print("[%s] Triggering ATTACK state" % (data.monster_name if data else "?"))
	if data:
		var resolved := _resolve_anim(data.anim_attack)
		if resolved != &"":
			animation_player.play(resolved)
			print("  Playing attack animation '%s'" % resolved)

func _on_take_damage(new_health):

	if health_bar:
		health_bar.update_bar(new_health, health_comp.max_health)
	
	velocity = Vector3.ZERO
	
	# Activar aggro al recibir daño (ataque del jugador desde distancia)
	is_aggroed = true
	
	# Visual flinch effect
	if data:
		print("[%s] Taking damage - looking for flinch anim: '%s'" % [data.monster_name, data.anim_flinch])
		var resolved := _resolve_anim(data.anim_flinch)
		if resolved != &"":
			animation_player.play(resolved)
			print("  Playing flinch animation '%s'" % resolved)

	# Trigger flinch animation state
	is_flinching = true
	flinch_timer = flinch_duration

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
	if health_bar: health_bar.hide()
	if mob_name: mob_name.hide()

	if data:
		print("[%s] Death - looking for death anim: '%s'" % [data.monster_name, data.anim_death])
		var resolved := _resolve_anim(data.anim_death)
		if resolved != &"":
			animation_player.play(resolved)
			print("  Playing death animation '%s'" % resolved)
			await animation_player.animation_finished

	queue_free()

## Genera los drops loot según la tabla de drops del enemigo
func _spawn_loot(death_position: Vector3):
	if not data or data.drop_table.is_empty():
		return

	for drop_entry in data.drop_table:
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
	# Skip if already casting
	if is_casting:
		print("_try_use_skill: Enemy is still casting, skipping")
		return
	
	if not skill_comp or not player or not data:
		print("_try_use_skill: Missing component - skill_comp: %s, player: %s, data: %s" % [skill_comp != null, player != null, data != null])
		return
	
	var dist_to_player = global_position.distance_to(player.global_position)
	print("_try_use_skill: Checking %d skills, distance to player: %.1f" % [data.skills.size(), dist_to_player])

	# Single source of truth: enemy-level AI chance controls whether this attempt casts any skill.
	var ai_chance = data.get_skill_use_chance_normalized()
	if randf() >= ai_chance:
		print("_try_use_skill: Failed enemy skill_use_chance roll (%.0f%%)" % (ai_chance * 100.0))
		return
	
	# Find usable skills within range
	var usable_skills = []
	
	for skill in data.skills:
		# Check range
		if dist_to_player > skill.cast_range:
			print("  Skill %s: Out of range (distance: %.1f, range: %.1f)" % [skill.skill_name, dist_to_player, skill.cast_range])
			continue
		
		# Check if can use (cooldown, etc)
		if not skill_comp.can_use_skill(skill):
			print("  Skill %s: Cannot use (cooldown or other issue)" % skill.skill_name)
			continue

		usable_skills.append(skill)
	
	if usable_skills.is_empty():
		print("_try_use_skill: No usable skills found")
		return
	
	var skill = usable_skills[randi() % usable_skills.size()]
	print("_try_use_skill: USING SKILL %s (type=%d, cast_time=%.2f)" % [skill.skill_name, skill.type, skill.cast_time])
	
	# Execute using the new method that handles casting
	match skill.type:
		SkillData.SkillType.SELF:
			execute_skill(skill, null)
		SkillData.SkillType.TARGET:
			execute_skill(skill, player)
		SkillData.SkillType.POINT:
			execute_skill(skill, player.global_position)

# ---------------------------------------------------------------------------
# Animation helpers
# ---------------------------------------------------------------------------

## Finds the first AnimationPlayer in the model subtree (handles nested GLB hierarchies).
func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result = _find_animation_player(child)
		if result:
			return result
	return null

## Initialises animation_player and optionally loads the EnemyData animation library.
func _setup_animation_player(model_instance: Node) -> void:
	animation_player = _find_animation_player(model_instance)
	print("[%s] AnimationPlayer found: %s" % [data.monster_name if data else "?", animation_player])
	
	if not animation_player:
		print("  [WARNING] No AnimationPlayer in model!")
		return
	
	# List all existing animations BEFORE loading library
	print("  Existing animations in AnimationPlayer:")
	for lib_name in animation_player.get_animation_library_list():
		var lib = animation_player.get_animation_library(lib_name)
		var anim_list = lib.get_animation_list()
	
	if not data or not data.animation_library:
		print("  No animation_library in EnemyData, using embedded animations only")
		return
	
	# Avoid adding the library twice (e.g. when model is reloaded)
	if not animation_player.has_animation_library(&"enemy"):
		animation_player.add_animation_library(&"enemy", data.animation_library)
		print("  Added 'enemy' library with animations: %s" % data.animation_library.get_animation_list())

## Resolves a short animation name to the full name used by the AnimationPlayer.
## Checks "enemy/<name>" (loaded library) first, then the bare name (GLB embedded).
func _resolve_anim(short_name: StringName) -> StringName:
	if not animation_player or short_name == &"":
		return &""
	
	var prefixed := StringName("enemy/" + short_name)
	if animation_player.has_animation(prefixed):
		return prefixed
	
	if animation_player.has_animation(short_name):
		return short_name
	
	
	return &""

## Helper to list all available animations for debugging
func _get_all_anim_names() -> Array:
	if not animation_player:
		return []
	var all_anims = []
	for lib_name in animation_player.get_animation_library_list():
		var lib = animation_player.get_animation_library(lib_name)
		for anim_name in lib.get_animation_list():
			var full_name = (lib_name + "/" + anim_name) if lib_name != "" else anim_name
			all_anims.append(full_name)
	return all_anims

## Plays a resolved animation safely; does nothing if not found.
func _play_anim(short_name: StringName) -> void:
	var resolved := _resolve_anim(short_name)
	if resolved != &"":
		animation_player.play(resolved)

## Rotates enemy on yaw to face a world-space point, with optional model forward offset.
## This keeps rotation logic consistent across movement, chase and attack.
func _rotate_towards(target_pos: Vector3) -> void:
	var to_target := target_pos - global_position
	to_target.y = 0.0
	if to_target.length_squared() <= 0.0001:
		return

	# Godot forward is -Z, so yaw comes from atan2(x, z) with a PI shift.
	var target_yaw := atan2(to_target.x, to_target.z) + PI
	if data:
		target_yaw += deg_to_rad(data.facing_yaw_offset_deg)

	if turn_speed_deg <= 0.0:
		rotation.y = target_yaw
		return

	var delta_time := get_physics_process_delta_time()
	var max_step := deg_to_rad(turn_speed_deg) * delta_time
	var yaw_diff := wrapf(target_yaw - rotation.y, -PI, PI)
	rotation.y += clamp(yaw_diff, -max_step, max_step)

func _fit_collision_shape_from_model(model_root: Node3D) -> void:
	if not data or not data.auto_fit_collision_shape or not model_root:
		return

	var aabb := _calculate_model_local_aabb(model_root)
	if aabb.size.length_squared() <= 0.0001:
		return

	var fit_size = (aabb.size + (data.collision_padding * 2.0)) * data.collision_size_multiplier
	fit_size.x = max(fit_size.x, data.collision_min_size.x)
	fit_size.y = max(fit_size.y, data.collision_min_size.y)
	fit_size.z = max(fit_size.z, data.collision_min_size.z)

	if not collision_shape_node:
		collision_shape_node = CollisionShape3D.new()
		collision_shape_node.name = "CollisionShape3D"
		add_child(collision_shape_node)

	# Keep fitted shapes predictable even if the scene had edited transform values.
	collision_shape_node.rotation = Vector3.ZERO
	collision_shape_node.scale = Vector3.ONE

	var shape_mode := data.collision_shape_mode
	if shape_mode == 0:
		if collision_shape_node.shape is CapsuleShape3D:
			shape_mode = 1
		elif collision_shape_node.shape is BoxShape3D:
			shape_mode = 2
		elif collision_shape_node.shape is SphereShape3D:
			shape_mode = 3
		else:
			shape_mode = 1

	match shape_mode:
		1:
			var capsule := collision_shape_node.shape as CapsuleShape3D
			if not capsule:
				capsule = CapsuleShape3D.new()
				collision_shape_node.shape = capsule
			var radius = max(0.05, max(fit_size.x, fit_size.z) * 0.5)
			capsule.radius = radius
			capsule.height = max(fit_size.y, (radius * 2.0) + 0.05)
		2:
			var box := collision_shape_node.shape as BoxShape3D
			if not box:
				box = BoxShape3D.new()
				collision_shape_node.shape = box
			box.size = fit_size
		3:
			var sphere := collision_shape_node.shape as SphereShape3D
			if not sphere:
				sphere = SphereShape3D.new()
				collision_shape_node.shape = sphere
			sphere.radius = max(0.05, max(fit_size.x, fit_size.y, fit_size.z) * 0.5)

	var center := aabb.get_center() + data.collision_center_offset
	collision_shape_node.position = center

func _calculate_model_local_aabb(model_root: Node3D) -> AABB:
	var result := AABB()
	var has_any := false
	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(model_root, meshes)

	if meshes.is_empty():
		return AABB(Vector3(-0.2, 0.0, -0.2), Vector3(0.4, 1.0, 0.4))

	for mesh_instance in meshes:
		if not mesh_instance.mesh:
			continue
		var local_aabb := mesh_instance.get_aabb()
		if local_aabb.size.length_squared() <= 0.0001:
			continue
		var to_enemy_local := global_transform.affine_inverse() * mesh_instance.global_transform
		var transformed := to_enemy_local * local_aabb
		if has_any:
			result = result.merge(transformed)
		else:
			result = transformed
			has_any = true

	if not has_any:
		return AABB(Vector3(-0.2, 0.0, -0.2), Vector3(0.4, 1.0, 0.4))
	return result

func _collect_mesh_instances(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect_mesh_instances(child, out)

## Switches between idle and walk animations based on horizontal velocity.
func _update_locomotion_anim() -> void:
	if not animation_player or not data or is_attacking or is_flinching or is_casting or is_dead:
		return
	var h_speed := Vector2(velocity.x, velocity.z).length()
	var target: StringName = data.anim_walk if h_speed > 0.1 else data.anim_idle
	var resolved := _resolve_anim(target)
	if resolved == &"":
		return
	if animation_player.current_animation == resolved:
		return
	animation_player.play(resolved)

# ---------------------------------------------------------------------------

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

## Execute a skill with casting if needed, or immediate if no cast time
func execute_skill(skill: SkillData, target) -> void:
	if not skill or not skill_comp:
		return
	
	print("Enemy executing skill: %s (cast_time: %.2f)" % [skill.skill_name, skill.cast_time])
	
	# For immediate skills (cast_time <= 0.05)
	if skill.cast_time <= 0.05:
		match skill.type:
			SkillData.SkillType.SELF:
				skill_comp.cast_immediate(skill)
			SkillData.SkillType.TARGET:
				skill_comp.armed_skill = skill
				skill_comp.execute_armed_skill(target)
			SkillData.SkillType.POINT:
				skill_comp.armed_skill = skill
				skill_comp.execute_armed_skill(target if target is Vector3 else target.global_position)
	else:
		# For cast skills: start the casting process
		_start_casting_process(skill, target)

## Start the casting process (with indicator, no progress bar for enemy)
func _start_casting_process(skill: SkillData, target) -> void:
	if is_casting:
		print("Enemy already casting, ignoring new skill cast attempt")
		return
	
	is_casting = true
	pending_skill = skill
	pending_target = target
	
	var cast_time = skill.cast_time
	print("Enemy %s starting cast of %s (duration: %.2f)" % [data.monster_name, skill.skill_name, cast_time])
	
	# Show casting indicator (if available - positioned at enemy)
	_show_casting_indicator()
	
	# Create tween for casting
	if casting_tween:
		casting_tween.kill()
	casting_tween = create_tween()
	casting_tween.tween_interval(cast_time)
	casting_tween.tween_callback(_on_cast_finished)

## Called when cast finishes
func _on_cast_finished() -> void:
	if not is_casting:
		return
	
	print("Enemy %s finished casting %s" % [data.monster_name, pending_skill.skill_name])
	
	is_casting = false
	
	# Execute the skill directly without re-casting
	if pending_skill and skill_comp:
		match pending_skill.type:
			SkillData.SkillType.SELF:
				skill_comp.finalize_skill_execution(pending_skill, global_position)
			SkillData.SkillType.TARGET:
				if pending_target and is_instance_valid(pending_target):
					skill_comp.finalize_skill_execution(pending_skill, pending_target)
			SkillData.SkillType.POINT:
				var target_pos = pending_target if pending_target is Vector3 else (pending_target.global_position if is_instance_valid(pending_target) else null)
				if target_pos:
					skill_comp.finalize_skill_execution(pending_skill, target_pos)
	
	# Hide casting indicator
	_hide_casting_indicator()
	
	# Clean up
	pending_skill = null
	pending_target = null

## Show a visual indicator where the skill will be cast (similar to player's AOE indicator)
func _show_casting_indicator() -> void:
	if not pending_skill:
		return
	
	# Get or create an indicator scene at this enemy's position
	var indicator_scene = load("res://scenes/aoe_indicator.tscn")
	if not indicator_scene:
		print("Warning: aoe_indicator.tscn not found")
		return
	
	var indicator = indicator_scene.instantiate()
	get_tree().current_scene.add_child(indicator)
	
	# Position indicator based on skill type
	match pending_skill.type:
		SkillData.SkillType.SELF:
			indicator.global_position = global_position
		SkillData.SkillType.TARGET:
			# If targeting player, position at player
			if pending_target and is_instance_valid(pending_target):
				indicator.global_position = pending_target.global_position
		SkillData.SkillType.POINT:
			# If targeting position, use that position
			if pending_target is Vector3:
				indicator.global_position = pending_target
			elif pending_target and is_instance_valid(pending_target):
				indicator.global_position = pending_target.global_position
	
	# Scale indicator by AOE radius
	var scale_factor = pending_skill.aoe_radius / 1.0  # Assuming default radius is 1.0
	indicator.scale = Vector3.ONE * scale_factor
	
	# Store indicator reference separately (don't overwrite pending_target!)
	casting_indicator = indicator

## Hide the casting indicator
func _hide_casting_indicator() -> void:
	if casting_indicator and is_instance_valid(casting_indicator):
		casting_indicator.queue_free()
		casting_indicator = null
