extends CharacterBody3D

@export var speed: float = 5.0
@export var attack_damage: int = 25
@export var attack_range: float = 2.0
@export var click_indicator_path: NodePath
@export var cursor_default: Texture2D
@export var cursor_attack: Texture2D
@export var cursor_skill: Texture2D
@export var cursor_talk: Texture2D
@export var cursor_door: Texture2D
@export var flinch_duration: float = 0.2
@export var attack_hit_delay: float = 0.3  # Time until damage is dealt in attack animation
@export var attack_animation_duration: float = 0.5  # Total duration of attack animation

@export_group("Hotbar Inicial")
# Usamos un Array exportado para configurar las skills iniciales desde el editor
# Arrastra tus recursos de Skills (o Items) aquí en el inspector.
@export var initial_hotbar: Array[Resource] = []

# Nuevo: Inventario inicial para pruebas/debug
@export_group("Inventario Inicial")
@export var initial_inventory: Array[Resource] = []

# El array real en tiempo de ejecución (tamaño fijo de 9)
var hotbar_content: Array = [] 
var HOTBAR_SIZE = 9

@export_group("Prefabs")
@export var floating_text_scene: PackedScene
@export var level_up_effect_scene: PackedScene
@export var unarmed_attack_animation_resource: Animation = null

@onready var inventory_component: InventoryComponent = $InventoryComponent
@onready var equipment_component: EquipmentComponent = $EquipmentComponent
@onready var aoe_indicator: MeshInstance3D = $AOEIndicator
@onready var skill_component = $SkillComponent
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var click_indicator: MeshInstance3D = get_node_or_null(click_indicator_path)
@onready var health_component: HealthComponent = $HealthComponent
@onready var game_over_ui: CanvasLayer = $GameOverUI
@onready var stats: Node = $StatsComponent
@onready var sp_component: SPComponent = $SPComponent
@onready var regen_component = $RegenerationComponent
@onready var inventory = $InventoryComponent
@onready var status_effect_manager: StatusEffectManager = $StatusEffectManagerComponent
@onready var player: CharacterBody3D = $"."
@onready var hud: CanvasLayer = $"../HUD"
@onready var state_machine: StateMachine = $StateMachine
@onready var animation_tree: AnimationTree = $Mannequin_Medium/AnimationTree
@onready var animation_player: AnimationPlayer = $Mannequin_Medium/AnimationPlayer

# Bone attachments for equipment and visual elements
var bone_attachments: Dictionary = {
	"RIGHT_HAND": null,
	"LEFT_HAND": null,
	"LEFT_ARM": null,
	"HEAD": null
}

# --- Variables de Ataque y Control ---
var last_attack_time: int = 0
var _last_cursor_state := "default" # "default", "attack", "skill"

var is_clicking: bool = false
var is_dead: bool = false 
var is_stunned = false
var current_target_enemy = null
var can_attack_player: bool = true
var is_attacking: bool = false
var hovered_enemy = null
var is_casting: bool = false
var is_flinching: bool = false
var flinch_timer: float = 0.0

# Current weapon animation names (loaded from equipped weapon)
var current_weapon_idle_anim: StringName = &""
var current_weapon_attack_start_anim: StringName = &""
var current_weapon_attack_release_anim: StringName = &""

func _ready():
	# Initialize bone attachments early
	_initialize_bone_attachments()
	
	hotbar_content.resize(HOTBAR_SIZE)
	# Cargar configuración inicial de hotbar
	for i in range(HOTBAR_SIZE):
		if i < initial_hotbar.size() and initial_hotbar[i] != null:
			hotbar_content[i] = initial_hotbar[i]
		else:
			hotbar_content[i] = null

	# Cargar inventario inicial
	for item in initial_inventory:
		if item != null:
			inventory.add_item(item, 1)

	# 1. Calcular y setear vida inicial
	var max_hp_calculado = 100 + stats.get_max_hp_bonus()
	health_component.max_health = max_hp_calculado
	health_component.current_health = max_hp_calculado
	skill_component.setup(self, stats, sp_component)
	
	if sp_component:
		sp_component.setup(stats)
		if not sp_component.on_sp_changed.is_connected(_on_sp_changed):
			sp_component.on_sp_changed.connect(_on_sp_changed)
		_on_sp_changed(sp_component.current_sp, sp_component.max_sp)
	
	# Recalcular bonos pasivos al iniciar (importante después de cargar partida)
	GameManager.recalculate_all_passive_bonuses()
	
	inventory.inventory_changed.connect(_on_inventory_changed)
	
	# 3. Configurar HUD pasando los 3 componentes
	if hud:
		hud.setup_hud(stats, health_component, sp_component, inventory_component)
		hud.setup_hotbar_ui()
		
		# ESPERA UN FRAME: Esto soluciona problemas donde los slots 
		# aún no existen en el array 'slots' del HUD.
		await get_tree().process_frame 
		refresh_hotbar_to_hud()
		
	skill_component.skill_state_changed.connect(_on_skill_state_changed)
	# Conexiones adicionales
	health_component.on_health_changed.connect(_on_player_hit)
	health_component.on_damage_taken.connect(_on_player_damaged)
	health_component.on_death.connect(_on_player_death)
	regen_component.setup(stats, health_component, sp_component)
	regen_component.hp_regenerated.connect(_on_hp_regenerated)
	regen_component.sp_regenerated.connect(_on_sp_regenerated)
	skill_component.skill_cooldown_started.connect(_on_cooldown_started)
	
	# Connect equipment changes to update animations
	if equipment_component:
		equipment_component.equipment_changed.connect(_on_equipment_changed)
	
	# Initialize state machine for animations
	if state_machine and animation_tree:
		state_machine.setup(self, animation_tree)
	
	# Set initial idle animation based on equipped weapon
	_update_idle_animation()

func change_character_model(new_model_scene: PackedScene):
	"""
	Change the player's character model to a new one.
	The new model should have the same skeleton and animation structure.
	"""
	if not new_model_scene:
		print("Warning: No model scene provided to change_character_model")
		return
	
	# Find the current model node (assuming it's named with "Mannequin" or is the first child that's a model)
	var current_model = get_node_or_null("Mannequin_Medium")
	if not current_model:
		# Try to find any child that looks like a character model
		for child in get_children():
			if child is Node3D and child.has_node("AnimationTree"):
				current_model = child
				break
	
	if not current_model:
		print("Warning: Could not find current character model to replace")
		return
	
	# Store the current transform and animation tree state
	var current_transform = current_model.transform
	var anim_tree_was_active = false
	var anim_tree: AnimationTree = null
	
	if current_model.has_node("AnimationTree"):
		anim_tree = current_model.get_node("AnimationTree")
		anim_tree_was_active = anim_tree.active
	
	# Instantiate the new model
	var new_model = new_model_scene.instantiate()
	
	# Remove the old model from the tree before adding the new one
	var old_model_name = current_model.name
	if current_model.get_parent() == self:
		remove_child(current_model)
	current_model.queue_free()
	
	# Add the new model with the same parent and transform
	add_child(new_model)
	new_model.transform = current_transform
	new_model.name = old_model_name
	
	# Update the animation_player reference if the new model has one
	if new_model.has_node("AnimationPlayer"):
		animation_player = new_model.get_node("AnimationPlayer")

	# Update the animation_tree reference if the new model has one
	if new_model.has_node("AnimationTree"):
		animation_tree = new_model.get_node("AnimationTree")
		animation_tree.active = anim_tree_was_active
		
		# Reconnect the state machine to the new animation tree
		if state_machine:
			state_machine.setup(self, animation_tree)
	
	# Re-initialize bone attachments for equipment after model change
	if has_node("EquipmentComponent"):
		var equipment_comp = get_node("EquipmentComponent")
		equipment_comp._initialize_bone_attachments()
		# Re-apply equipped items to new model
		equipment_comp._recalculate_equipment_bonuses()
		for slot_type in equipment_comp.equipped_items:
			var item = equipment_comp.equipped_items[slot_type]
			if item:
				equipment_comp._update_equipment_visuals(item, slot_type)
		# Reload weapon animations for the new AnimationPlayer
		var weapon = equipment_comp.get_equipped_item(EquipmentItem.EquipmentSlot.WEAPON)
		load_weapon_animations(weapon)
	
	print("Character model changed successfully to: ", new_model_scene.resource_path)

func _unhandled_input(event):
	if is_dead: return
	# LÓGICA DE HOTBAR DINÁMICA
	# Iteramos del 1 al 9 para ver si se presionó alguna tecla "skill_X"
	for i in range(1, 10):
		if event.is_action_pressed("skill_" + str(i)):
				# Restamos 1 porque el array es base-0 (Tecla 1 -> Slot 0)
			use_hotbar_slot(i - 1)
			get_viewport().set_input_as_handled()
			return
	
	# CLICK DERECHO (cancelar skill o cast)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if skill_component.armed_skill:
			skill_component.cancel_cast()
		elif skill_component.is_casting:
			skill_component.cancel_cast()
		return

	# CLICK IZQUIERDO: manejar PRESIONADO y LIBERADO explícitamente
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_clicking = true
			if skill_component and skill_component.armed_skill:
				_handle_skill_target_selection()
				get_viewport().set_input_as_handled()
			else:
				is_clicking = true # este
				handle_click_interaction()
		else:
			# No cambiar is_clicking durante el cast para no interrumpirlo
			if not skill_component.is_casting:
				is_clicking = false

	# Actualizar cursor cuando el mouse se mueve
	if event is InputEventMouseMotion:
		update_cursor()

func _physics_process(_delta):
	if is_dead:
		return

	# Keep a local casting flag so animation state can read it
	is_casting = skill_component.is_casting if skill_component else false

	if is_flinching:
		flinch_timer -= _delta
		if flinch_timer <= 0.0:
			is_flinching = false

	if stats and stats.is_stunned:
		return
	_update_aoe_indicator()
	
	# 1. Bloqueo por animación de ataque (prioridad máxima)
	if is_attacking:
		nav_agent.target_position = global_position
		velocity = Vector3.ZERO
		update_cursor()
		move_and_slide()
		return
		
	if is_casting:
		velocity = Vector3.ZERO
		# Aquí podrías forzar la animación de "casteo"
		# animation_player.play("cast")
		move_and_slide() # Para mantener gravedad si es necesario
		return
		
	# 2. PROCESAMIENTO DE INPUT (Solo si NO hay skill armada Y NO estamos casteando)
	# Encapsulamos toda la lógica de "decidir a dónde ir" dentro de este if
	if is_clicking and not skill_component.armed_skill and not skill_component.is_casting:
		# Usamos la lógica centralizada (click sostenido ataca y mueve)
		_process_continuous_interaction()
	
	# Nota: Si skill_component.armed_skill es TRUE, el código salta todo el bloque anterior.
	# Por lo tanto, no se llama a nav_agent.set_target_position.

	# 3. EJECUCIÓN FÍSICA DEL MOVIMIENTO
	# Esto se ejecuta independientemente del input. 
	# Si ya tenías un camino trazado antes de armar la skill, esto hará que el personaje lo termine.
	if nav_agent.is_navigation_finished():
		velocity = Vector3.ZERO
		# Aquí podrías añadir animación de Idle si estás parado
	else:
		var next_path_pos = nav_agent.get_next_path_position()
		var direction = (next_path_pos - global_position).normalized()
		var speed_mult : float = (stats.get_move_speed_modifier() if stats else 1.0)
		velocity = direction * speed * speed_mult
		
		# Orientación
		var target_flat = Vector3(next_path_pos.x, global_position.y, next_path_pos.z)
		if velocity.length() > 0.1 and global_position.distance_to(target_flat) > 0.1:
			look_at(target_flat, Vector3.UP)
	
	update_cursor()
	move_and_slide()
	
func _process_continuous_interaction():
	# Si tenemos un enemigo targetado (por click inicial), continuar atacándolo mientras se sostiene el click
	if current_target_enemy and is_instance_valid(current_target_enemy):
		var dist = global_position.distance_to(current_target_enemy.global_position)
		var effective_range = get_effective_attack_range()
		
		if dist <= effective_range:
			# Si estamos en rango, nos detenemos y atacamos
			nav_agent.target_position = global_position
			_face_target(current_target_enemy)
			execute_attack(current_target_enemy)
		else:
			# Si estamos lejos, lo perseguimos
			nav_agent.target_position = current_target_enemy.global_position
		return
	
	# Si no hay enemigo targetado, manejar movimiento al suelo
	var result = get_mouse_world_interaction()
	if not result: return
	
	# Nota: No interactuar con NPCs durante click sostenido.
	if result.collider.has_method("interact"):
		return
	
	# No retargetear enemigos durante click sostenido - solo mover al suelo
	if not result.collider.is_in_group("enemy"):
		nav_agent.target_position = result.position

# --- FUNCIONES AUXILIARES DE MOVIMIENTO ---

func handle_click_interaction():
	if skill_component.armed_skill:
		return
	
	var result = get_mouse_world_interaction()
	if result:
		var collider = result.collider
		
		# Check if clicking on NPC
		if collider.has_method("interact"):
			# Interactuar solo con click directo
			current_target_enemy = null
			_stop_movement()
			collider.interact(self)
			is_clicking = false
			return
		
		var is_attack_click = collider.is_in_group("enemy")
		
		spawn_flash_effect(result.position, is_attack_click)
		
		if is_attack_click:
			current_target_enemy = collider
			# Attack immediately on click if in range, otherwise move towards enemy
			var dist = global_position.distance_to(collider.global_position)
			var effective_range = get_effective_attack_range()
			if dist <= effective_range:
				execute_attack(collider)
		else:
			current_target_enemy = null # Si clicamos suelo, cancelamos ataque

func move_to_mouse_position():
	if skill_component.armed_skill:
		return
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
	query.collide_with_areas = true  
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	var result = space_state.intersect_ray(query)
	if not result:
		return null
	return result

func _stop_movement():
	nav_agent.target_position = global_position
	velocity = Vector3.ZERO
func update_cursor():
	var result = get_mouse_world_interaction()
	var hovering_enemy = false
	var hovering_npc = false 
	var hovering_portal = false
	var within_skill_range = false

	if result and result.has("collider"):
		var col = result.collider
		if is_instance_valid(col):
		

			# 1. Detectar Enemigos
			
			if col.is_in_group("enemy"):
				
				hovering_enemy = true
				hovered_enemy = col
				if skill_component and skill_component.armed_skill:
					var cast_range = skill_component.armed_skill.cast_range
					if global_position.distance_to(col.global_position) <= cast_range:
						within_skill_range = true
			
			# 2. Detectar Portales (NUEVO)
			elif col.is_in_group("portal"):
				hovering_portal = true
			
			# 3. Detectar NPCs
			elif col.has_method("interact"):
				hovering_npc = true

	# --- LÓGICA DE ACTUALIZACIÓN VISUAL ---

	if within_skill_range:
		_set_cursor(cursor_skill, "skill", Vector2(16,16))
		return

	if hovering_enemy:
		_set_cursor(cursor_attack, "attack", Vector2(16,16))
		return
	
	if hovering_portal:
		_set_cursor(cursor_door, "door", Vector2(16,16))
		return
		
	if hovering_npc: # <--- NUEVO ESTADO
		_set_cursor(cursor_talk, "talk", Vector2(16,16))
		return

	# Si no hay nada, cursor default
	_set_cursor(cursor_default, "default", Vector2(0,0))

# Función auxiliar para no repetir código de cursor
func _set_cursor(texture, state_name, offset):
	if _last_cursor_state != state_name:
		Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, offset)
		_last_cursor_state = state_name

# --- HELPER FUNCTIONS FOR COMBAT ---

## Get the effective attack range based on equipped weapon
func get_effective_attack_range() -> float:
	if equipment_component:
		var weapon = equipment_component.get_equipped_item(EquipmentItem.EquipmentSlot.WEAPON)
		if weapon:
			return weapon.attack_range
	return attack_range  # Fallback to base attack range

# --- FUNCIONES AUXILIARES DE ATAQUE ---

func try_attack_enemy(enemy):
	var dist = global_position.distance_to(enemy.global_position)
	var effective_range = get_effective_attack_range()
	if dist <= effective_range - 0.2:
		if enemy.has_node("HealthComponent"):
			enemy.get_node("HealthComponent").take_damage(attack_damage)
	else:
		nav_agent.target_position = enemy.global_position

## Shoot a projectile at the target enemy
func _shoot_projectile(target: Node3D, projectile_scene: PackedScene) -> void:
	if not projectile_scene or not is_instance_valid(target):
		return
	
	# Spawn the projectile
	var projectile = projectile_scene.instantiate()
	get_tree().root.add_child(projectile)
	
	# Position it at the player's position (or weapon attach point if available)
	var spawn_position = global_position + Vector3(0, 1.5, 0)  # Slightly above player
	var attachment_key = "RIGHT_HAND"
	if equipment_component:
		var weapon = equipment_component.get_equipped_item(EquipmentItem.EquipmentSlot.WEAPON)
		if weapon:
			match weapon.weapon_attachment:
				EquipmentItem.WeaponAttachment.LEFT_HAND:
					attachment_key = "LEFT_HAND"
				EquipmentItem.WeaponAttachment.LEFT_ARM:
					attachment_key = "LEFT_ARM"
				EquipmentItem.WeaponAttachment.HEAD:
					attachment_key = "HEAD"
				_:
					attachment_key = "RIGHT_HAND"
	if bone_attachments.has(attachment_key) and bone_attachments[attachment_key]:
		spawn_position = bone_attachments[attachment_key].global_position
	
	projectile.global_position = spawn_position
	
	# Configure the projectile if it has the expected methods/properties
	if projectile.has_method("setup"):
		var damage = attack_damage
		if stats:
			damage = stats.get_atk()
		projectile.setup(target, damage, self)
	elif projectile.has_method("set_target"):
		projectile.set_target(target)

func execute_attack(enemy) -> void:
	# Retorna cuando el ataque y su cooldown (ASPD) finalizan
	if not can_attack_player or is_dead: 
		return

	# Si el enemigo dejó de ser válido, salir
	if not enemy or not is_instance_valid(enemy):
		return

	# IMMEDIATELY lock attacks to prevent re-entry
	can_attack_player = false
	
	# Marcar el estado de ataque para bloquear input/movimiento durante la animación
	is_attacking = true
	_face_target(enemy)

	# Bloqueo de movimiento mientras atacamos
	nav_agent.target_position = global_position
	velocity = Vector3.ZERO

	var enemy_health = enemy.get_node_or_null("HealthComponent")
	var enemy_data = enemy.data
	
	# Check if we're using a ranged weapon
	var weapon = null
	var is_ranged_attack = false
	if equipment_component:
		weapon = equipment_component.get_equipped_item(EquipmentItem.EquipmentSlot.WEAPON)
		if weapon and weapon.is_ranged:
			is_ranged_attack = true

	# Temporarily disable AnimationTree so AnimationPlayer can play weapon animations
	var anim_tree_was_active = false
	if animation_tree:
		anim_tree_was_active = animation_tree.active
		if anim_tree_was_active:
			animation_tree.active = false
	
	# Play weapon-specific attack start animation using AnimationPlayer or fallback to AnimationTree
	var played_attack_anim = false
	if animation_player and current_weapon_attack_start_anim != "" and animation_player.has_animation(current_weapon_attack_start_anim):
		animation_player.play(current_weapon_attack_start_anim)
		played_attack_anim = true
	elif animation_player and animation_player.has_animation("attack_1"):
		animation_player.play("attack_1")
		played_attack_anim = true

	# If no AnimationPlayer anim played, use AnimationTree state machine for melee/no-weapon
	if not played_attack_anim and animation_tree:
		var state_machine_playback = animation_tree.get("parameters/playback")
		if state_machine_playback:
			state_machine_playback.travel("Attack")
			played_attack_anim = true

	if not played_attack_anim:
		push_warning("Player: No attack start animation found")

	if enemy_health and enemy_data and stats:
		# WAIT for animation to reach hit frame before dealing damage
		await get_tree().create_timer(attack_hit_delay).timeout

		# Verificar que el enemigo sigue válido después del delay
		if not is_instance_valid(enemy) or not is_instance_valid(enemy_health):
			if animation_tree and anim_tree_was_active:
				animation_tree.active = true
			can_attack_player = true
			is_attacking = false
			return

		# For ranged attacks, shoot projectile instead of direct damage
		if is_ranged_attack and weapon.projectile_scene:
			# Play release animation for ranged weapons
			if animation_player:
				if current_weapon_attack_release_anim != "" and animation_player.has_animation(current_weapon_attack_release_anim):
					animation_player.play(current_weapon_attack_release_anim)
				elif animation_player.has_animation("attack_1"):
					animation_player.play("attack_1")
			
			_shoot_projectile(enemy, weapon.projectile_scene)
			# Projectile will handle damage, so skip direct damage calculation
			# But still show "attack" message
			get_tree().call_group("hud", "add_log_message", "Disparaste a " + enemy_data.monster_name, Color.WHITE)
		else:
			# Melee attack - calculate and apply damage directly
			# Play release animation for melee weapons
			if animation_player:
				if current_weapon_attack_release_anim != "" and animation_player.has_animation(current_weapon_attack_release_anim):
					animation_player.play(current_weapon_attack_release_anim)
				elif animation_player.has_animation("attack_1"):
					animation_player.play("attack_1")
			
			# Cálculo de hit
			var hit_chance_percent = (stats.get_hit() - enemy_data.flee) + 80
			hit_chance_percent = clamp(hit_chance_percent, 5, 95)
			var is_hit = (randi() % 100) < hit_chance_percent

			if not is_hit:
				get_tree().call_group("hud", "add_log_message", "Fallaste contra " + enemy_data.monster_name, Color.SKY_BLUE)
				spawn_floating_text(enemy.global_position, 0, true)
			else:
				# Obtener stats del enemigo
				var enemy_stats = enemy.get_node_or_null("StatsComponent")
				var base_atk = stats.get_atk()
				
				# Usar CombatMath para aplicar elemento del arma y bonos vs raza/elemento
				var final_damage = CombatMath.calculate_final_damage(
					base_atk, 
					stats, 
					enemy_stats,
					-1  # -1 significa usar weapon_element, no un elemento de skill específico
				)
				
				# Aplicar defensa del enemigo
				final_damage = max(1, final_damage - enemy_data.def)
				
				get_tree().call_group("hud", "add_log_message", "Golpeaste a %s por %d" % [enemy_data.monster_name, final_damage], Color.WHITE)
				enemy_health.take_damage(final_damage)
				spawn_floating_text(enemy.global_position, final_damage, false)

		# Wait for animation to finish (separate from attack cooldown)
		var remaining_anim_time = attack_animation_duration - attack_hit_delay
		if remaining_anim_time > 0:
			await get_tree().create_timer(remaining_anim_time).timeout

		# Restore AnimationTree after attack animation completes
		if animation_tree and anim_tree_was_active:
			animation_tree.active = true
		
		# Animation finished - release attacking state
		is_attacking = false

		# Now wait for the rest of the attack cooldown (ASPD)
		var cooldown_time = stats.get_attack_speed() - attack_animation_duration
		if cooldown_time > 0:
			await get_tree().create_timer(cooldown_time).timeout
		
		can_attack_player = true
	else:
		# If no valid target, just end the attack state
		if animation_tree and anim_tree_was_active:
			animation_tree.active = true
		is_attacking = false
		can_attack_player = true

func _face_target(target: Node3D) -> void:
	if not target or not is_instance_valid(target):
		return
	var target_pos = target.global_position
	look_at(Vector3(target_pos.x, global_position.y, target_pos.z), Vector3.UP)

func _on_player_hit(new_health):
	if has_node("HealthBar3D") and has_node("HealthComponent"):
		var max_hp = health_component.max_health
		$HealthBar3D.update_bar(new_health, max_hp)

func _on_sp_changed(current_sp, max_sp):
	if has_node("SPBar3D"):
		$SPBar3D.update_bar(current_sp, max_sp)

func _on_player_damaged(damage_amount: int):
	# 1. Mostrar floating text de daño (rojo para el jugador)
	spawn_floating_text_player_damage(global_position, damage_amount)
	
	# 2. Interrumpir cast SIEMPRE que el jugador reciba daño (force=true)
	if skill_component.is_casting:
		skill_component._interrupt_casting(true)
	
	# Desabilitar skill armada si hay una
	if skill_component.armed_skill:
		skill_component.cancel_cast()
	velocity = Vector3.ZERO
	nav_agent.target_position = global_position # Cancelar ruta actual

	# Trigger flinch animation state
	is_flinching = true
	flinch_timer = flinch_duration
	
	# 4. Feedback Visual (flinch animation only - don't control is_stunned)
	var tween = create_tween()
	
	tween.tween_property(self, "position:y", position.y + 0.05, 0.05)
	tween.chain().tween_property(self, "position:y", position.y, 0.1)

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

func _handle_skill_target_selection():
	
	var result = get_mouse_world_interaction()
	if not result: return

	if not skill_component or not skill_component.armed_skill: return
	
	var skill = skill_component.armed_skill
	
	# SELF skills no deben llegar aquí, pero por seguridad:
	if skill.type == SkillData.SkillType.SELF:
		return
	
	var target_data = null
	var distance_to_cast = 0.0
	
	# 1. Identificar el objetivo y calcular distancia
	if skill.type == SkillData.SkillType.TARGET:
		if result.has("collider") and result.collider.is_in_group("enemy"):
			target_data = result.collider
			distance_to_cast = global_position.distance_to(target_data.global_position)
	elif skill.type == SkillData.SkillType.POINT:
		target_data = result.position
		distance_to_cast = global_position.distance_to(target_data)

	# 2. VALIDACIÓN CRÍTICA
	if target_data != null:
		if distance_to_cast <= skill.cast_range:
			# DENTRO DE RANGO: Ejecutar y asegurar que no nos movemos			
			var look_pos = target_data.global_position if target_data is Node3D else target_data
			look_at(Vector3(look_pos.x, global_position.y, look_pos.z), Vector3.UP)
			
			skill_component.call_deferred("execute_armed_skill", target_data)
			is_clicking = false # Forzamos que deje de detectar el "mantener presionado"
			_stop_movement()
		else:
			# FUERA DE RANGO: Solo avisar, NO actualizar target_position
			get_tree().call_group("hud", "add_log_message", "Distancia insuficiente", Color.ORANGE)
			# Opcional: Cancelar la skill si quieres que el jugador deba presionar la tecla de nuevo
			# skill_component.cancel_cast() 
	
	# Importante: al procesar este click de skill, forzamos que is_clicking sea false 
	# momentáneamente para que el physics_process no mueva al jugador en este frame
	is_clicking = false


func try_use_skill():
	# Obtenemos la skill que el jugador intentó activar (la "armada")
	var skill = skill_component.armed_skill
	
	# Si no hay ninguna skill preparada, no hacemos nada
	if not skill: return 

	if current_target_enemy and is_instance_valid(current_target_enemy):
		var distance = global_position.distance_to(current_target_enemy.global_position)
		
		# Usamos la variable 'skill' (dinámica) en lugar de 'skill_1'
		if distance <= skill.cast_range:
			_stop_movement()
			
			var target_pos = current_target_enemy.global_position
			look_at(Vector3(target_pos.x, global_position.y, target_pos.z), Vector3.UP)
			
			# Ejecutamos la que esté armada
			skill_component.call_deferred("execute_armed_skill", current_target_enemy)
		else:
			# Opcional: Si está lejos, podrías hacer que el jugador camine hacia el enemigo
			nav_agent.target_position = current_target_enemy.global_position

func _update_aoe_indicator():
	var skill = skill_component.armed_skill

	# Si no hay skill armada, ocultar y salir
	if not skill or skill.aoe_radius <= 0:
		aoe_indicator.visible = false
		return

	# Lógica para mostrar el indicador...
	if skill.type == SkillData.SkillType.POINT:
		var result = get_mouse_world_interaction()
		if result:
			aoe_indicator.visible = true
			aoe_indicator.global_position = result.position + Vector3(0, 0.1, 0)
			var s = skill.aoe_radius
			aoe_indicator.scale = Vector3(s, 1, s)
		elif skill.type == SkillData.SkillType.SELF:
		# Para SELF skills, mostrar alrededor del jugador -- En realidad serían mejor nombradas "INSTANT" y no necesitan AOE
			aoe_indicator.visible = true
			aoe_indicator.global_position = global_position + Vector3(0, 0.1, 0)
			var s = skill.aoe_radius
			aoe_indicator.scale = Vector3(s, 1, s)
	else:
		# Si no hay skill o no tiene AOE, se oculta inmediatamente
		aoe_indicator.visible = false

func _on_skill_state_changed():
	update_cursor() # Cambia el color del cursor
	_update_aoe_indicator()
	if hud:
		if skill_component.armed_skill:
			# Enviamos el nombre al HUD para mostrar el Label
			hud.update_armed_skill_info(skill_component.armed_skill.skill_name)
		else:

			hud.update_armed_skill_info("")

# --- Callbacks de Regeneración ---

func _on_hp_regenerated(amount: int):
	spawn_regen_floating_text(global_position, amount, "hp")

func _on_sp_regenerated(amount: int):
	spawn_regen_floating_text(global_position, amount, "sp")

# --- FUNCIONES AUXILIARES MISC ---

func spawn_floating_text(pos: Vector3, value: int, is_miss: bool):
	if not floating_text_scene: return
	var txt_instance = floating_text_scene.instantiate()
	get_tree().current_scene.add_child(txt_instance)
	txt_instance.global_position = pos + Vector3(0, 1.5, 0)
	txt_instance.set_values_and_animate(value, is_miss)

func spawn_floating_text_player_damage(pos: Vector3, value: int):
	if not floating_text_scene: return
	var txt_instance = floating_text_scene.instantiate()
	get_tree().current_scene.add_child(txt_instance)
	txt_instance.global_position = pos + Vector3(0, 1.5, 0)
	txt_instance.set_values_and_animate(value, false, false, true) # is_player_damage = true

func spawn_regen_floating_text(pos: Vector3, value: int, regen_type: String):
	if not floating_text_scene: return
	var txt_instance = floating_text_scene.instantiate()
	get_tree().current_scene.add_child(txt_instance)
	txt_instance.global_position = pos + Vector3(0, 1.5, 0)
	txt_instance.set_regen_text(value, regen_type)

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

func use_hotbar_slot(index: int):
	var content = hotbar_content[index]
	
	if content is SkillData:
		# Limpiamos estados previos
		is_clicking = false
		
		# LÓGICA DE BIFURCACIÓN
		if content.type == SkillData.SkillType.SELF:
			# CASO A: Skill Instantánea (Buffs, Magnum Break)
			# Detenemos movimiento para castear
			_stop_movement()
			# Ejecutamos directamente sin pasar por armed_skill
			skill_component.cast_immediate(content)
			
		else:
			# CASO B: Skills de Target o Point (Fireball, Bash)
			# Comportamiento clásico de RO (Cursor cambia, espera click)
			skill_component.arm_skill(content)
	elif content is ItemData:
		# Buscamos y usamos el ítem desde el inventario
		_consume_item_from_inventory(content)

func _consume_item_from_inventory(item_to_use: ItemData):
	# Buscamos en qué slot del inventario está este ítem
	for i in range(inventory.slots.size()):
		var slot = inventory.slots[i]
		if slot and slot.item_data == item_to_use:
			# Usamos la función que ya tenemos en el InventoryComponent
			inventory.use_item_at_index(i, self)
			return # Salimos tras usar el primero que encuentre

func _on_skill_shortcut_pressed(skill: SkillData):
	# Limpiamos estados previos
	is_clicking = false
	
	# LÓGICA DE BIFURCACIÓN
	if skill.type == SkillData.SkillType.SELF:
		# CASO A: Skill Instantánea (Buffs, Magnum Break)
		# Detenemos movimiento para castear
		_stop_movement()
		# Ejecutamos directamente sin pasar por armed_skill
		skill_component.cast_immediate(skill)
		
	else:
		# CASO B: Skills de Target o Point (Fireball, Bash)
		# Comportamiento clásico de RO (Cursor cambia, espera click)
		skill_component.arm_skill(skill)

func refresh_hotbar_to_hud():
	if not hud: return
	
	# hotbar_content es el Array[Resource] que definimos anteriormente
	for i in range(hotbar_content.size()):
		var data = hotbar_content[i]
		# Get the amount from inventory if it's an item
		var amount = 0
		if data is ItemData:
			amount = inventory.get_item_amount(data)
		# Aquí es donde realmente se llama a la función del HUD que mencionas
		hud.update_hotbar_slot(i, data, amount)
		
func _on_inventory_changed():
	var _changed = false
	
	for i in range(hotbar_content.size()):
		var content = hotbar_content[i]
		
		# Solo nos importa si es un ItemData (las Skills no se gastan)
		if content is ItemData:
			if not inventory.has_item(content):
				hotbar_content[i] = null
				_changed = true
	
	# Siempre actualizamos la hotbar cuando el inventario cambia
	# (esto actualiza las cantidades incluso si no removimos items de la hotbar)
	refresh_hotbar_to_hud()
func _on_cooldown_started(skill_name: String, duration: float):
	if hud:
		hud.propagate_cooldown(skill_name, duration)

func _assign_item_to_hotbar(slot_index: int, item: ItemData):
	# Asignar el item al slot del hotbar
	if slot_index >= 0 and slot_index < HOTBAR_SIZE:
		hotbar_content[slot_index] = item
		refresh_hotbar_to_hud()

## Inicializa referencias a los attachment points del esqueleto
func _initialize_bone_attachments() -> void:
	var model = get_node_or_null("Mannequin_Medium")
	if not model:
		push_error("Player: Cannot find character model (Mannequin_Medium)")
		return
	
	var skeleton_path: String = "Rig_Medium/Skeleton3D"
	var skeleton = model.get_node_or_null(skeleton_path)
	
	if not skeleton:
		push_error("Player: Cannot find skeleton at path: ", skeleton_path)
		return
	
	# Mapear los attachment points disponibles
	var attachment_keys = ["RIGHT_HAND", "LEFT_HAND", "LEFT_ARM", "HEAD"]
	var attachment_node_names = ["RightHand", "LeftHand", "LeftArm", "Head"]
	
	for i in range(attachment_keys.size()):
		var key = attachment_keys[i]
		var node_name = attachment_node_names[i]
		var attachment = skeleton.get_node_or_null(node_name)
		if attachment:
			bone_attachments[key] = attachment
		else:
			push_warning("Player: Cannot find attachment point: ", node_name)

## Obtiene un attachment point por su clave
func get_bone_attachment(attachment_key: String) -> Node3D:
	if bone_attachments.has(attachment_key):
		return bone_attachments[attachment_key]
	return null

func _pick_first_animation(anim_names: Array) -> StringName:
	if not animation_player:
		return &""
	for anim_name in anim_names:
		if animation_player.has_animation(anim_name):
			return anim_name
	return &""

## Carga las animaciones de un arma equipada en el AnimationPlayer, o la animación unarmed si no hay arma
func load_weapon_animations(weapon: EquipmentItem) -> void:
	if not animation_player:
		return

	var fallback_idle = _pick_first_animation(["Idle_A", "idle", "Idle"])
	var fallback_attack = _pick_first_animation(["attack_1", "Attack", "Attack_A"])
	var fallback_release = _pick_first_animation(["attack_1", "Attack", "Attack_A"])
	
	# Get the animation library (default library)
	var anim_library: AnimationLibrary = null
	if animation_player.has_animation_library(""):
		anim_library = animation_player.get_animation_library("")
	else:
		# Create a new library if it doesn't exist
		anim_library = AnimationLibrary.new()
		animation_player.add_animation_library("", anim_library)
	
	if weapon:
		# Load idle animation
		if weapon.idle_animation_resource:
			var anim_name = "weapon_idle"
			if anim_library.has_animation(anim_name):
				anim_library.remove_animation(anim_name)
			anim_library.add_animation(anim_name, weapon.idle_animation_resource)
			current_weapon_idle_anim = anim_name
		else:
			current_weapon_idle_anim = fallback_idle
		
		# Load attack start animation
		if weapon.attack_start_animation_resource:
			var anim_name = "weapon_attack_start"
			if anim_library.has_animation(anim_name):
				anim_library.remove_animation(anim_name)
			anim_library.add_animation(anim_name, weapon.attack_start_animation_resource)
			current_weapon_attack_start_anim = anim_name
		else:
			current_weapon_attack_start_anim = fallback_attack
		
		# Load attack release animation
		if weapon.attack_release_animation_resource:
			var anim_name = "weapon_attack_release"
			if anim_library.has_animation(anim_name):
				anim_library.remove_animation(anim_name)
			anim_library.add_animation(anim_name, weapon.attack_release_animation_resource)
			current_weapon_attack_release_anim = anim_name
		else:
			current_weapon_attack_release_anim = fallback_release
	else:
		# No weapon equipped: use unarmed attack animation
		if unarmed_attack_animation_resource:
			var anim_name = "weapon_attack_start"
			if anim_library.has_animation(anim_name):
				anim_library.remove_animation(anim_name)
			anim_library.add_animation(anim_name, unarmed_attack_animation_resource)
			current_weapon_attack_start_anim = anim_name
		else:
			current_weapon_attack_start_anim = fallback_attack
		current_weapon_idle_anim = fallback_idle
		current_weapon_attack_release_anim = fallback_release
	
	print("Player: Loaded weapon animations - idle: %s, attack_start: %s, attack_release: %s" % [
		current_weapon_idle_anim, 
		current_weapon_attack_start_anim, 
		current_weapon_attack_release_anim
	])

## Actualiza la animación idle basada en el arma equipada
func _update_idle_animation() -> void:
	if not equipment_component or not animation_player:
		return
	
	var weapon = equipment_component.get_equipped_item(EquipmentItem.EquipmentSlot.WEAPON)
	
	# Si hay un arma con animación idle específica, usarla
	if weapon and current_weapon_idle_anim != &"":
		if animation_player.has_animation(current_weapon_idle_anim):
			# No reproducir directamente idle, dejar que el state machine lo maneje
			# Pero podríamos guardar esta info para que IdleState la use
			pass
	else:
		# Usar animación idle por defecto
		pass

## Callback cuando el equipo cambia
func _on_equipment_changed() -> void:
	# Load weapon animations when equipment changes
	if equipment_component:
		var weapon = equipment_component.get_equipped_item(EquipmentItem.EquipmentSlot.WEAPON)
		load_weapon_animations(weapon)
	
	_update_idle_animation()
