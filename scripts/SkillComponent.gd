extends Node
class_name SkillComponent

signal skill_state_changed
signal skill_cooldown_started(skill_name: String, duration: float)

# SEÑALES NUEVAS PARA LA UI DE CASTEO
signal cast_started(skill_name: String, duration: float)
signal cast_interrupted
signal cast_completed

var is_casting: bool = false
var current_cast_tween: Tween # Usaremos un Tween para manejar el tiempo
var pending_skill: SkillData = null # La skill que se está casteando
var pending_target = null # El objetivo guardado

var stats: StatsComponent
var sp_comp: SPComponent
var actor: Node3D
var armed_skill: SkillData = null

var cooldown_timers: Dictionary = {} 

func setup(actor_node: Node3D, stats_node: StatsComponent, sp_node: SPComponent):
	actor = actor_node
	stats = stats_node
	sp_comp = sp_node

func can_use_skill(skill: SkillData) -> bool:
	if not skill: return false
	
	if cooldown_timers.has(skill.skill_name):
		if Time.get_ticks_msec() < cooldown_timers[skill.skill_name]:
			get_tree().call_group("hud", "add_log_message", "Habilidad en cooldown", Color.ORANGE)
			return false
			
	if sp_comp and sp_comp.current_sp < skill.sp_cost:
		get_tree().call_group("hud", "add_log_message", "SP insuficiente", Color.RED)
		return false
		
	return true

func cast_immediate(skill: SkillData):
	if not can_use_skill(skill): return

	sp_comp.use_sp(skill.sp_cost)
	_start_cooldown(skill)
	
	# SOLUCIÓN ERROR LÍNEA 44: Ahora la función acepta el parámetro skill
	_apply_aoe_damage(actor.global_position, skill) 
	
	if skill.effect_scene:
		var fx = skill.effect_scene.instantiate()
		get_tree().current_scene.add_child(fx)
		fx.global_position = actor.global_position

func _start_cooldown(skill: SkillData):
	var duration_ms = int(skill.cooldown * 1000)
	cooldown_timers[skill.skill_name] = Time.get_ticks_msec() + duration_ms
	skill_cooldown_started.emit(skill.skill_name, skill.cooldown)

func arm_skill(skill: SkillData):
	if is_casting: return # No puedes armar si estás casteando
	if not can_use_skill(skill): return
	armed_skill = skill
	skill_state_changed.emit()

func cancel_cast():
	# 1. Si estaba solo apuntando (armed)
	if armed_skill:
		armed_skill = null
		skill_state_changed.emit()
	
	get_tree().call_group("hud", "add_log_message", "Cancelado.", Color.GRAY)

	# 2. Si estaba activamente casteando (barra de progreso)
	if is_casting:
		_interrupt_casting()

func execute_armed_skill(target_data) -> void:
	if not armed_skill: return
	
	var skill_to_use = armed_skill
	
	# 1. Calculamos el tiempo real basado en DEX
	var final_cast_time = stats.get_cast_time_reduction(skill_to_use.cast_time)
	
	# CASO A: INSTANTÁNEO
	if final_cast_time <= 0.05: # Margen pequeño
		_finalize_skill_execution(skill_to_use, target_data)
		armed_skill = null # Desarmamos inmediatamente
		skill_state_changed.emit()
		
	# CASO B: REQUIERE CASTEO
	else:
		_start_casting_process(skill_to_use, target_data, final_cast_time)
		# Nota: NO desarmamos 'armed_skill' aún, esperamos a que termine
		# o lo manejamos según prefieras la UX (normalmente se desarma al iniciar cast)
		armed_skill = null 
		skill_state_changed.emit()

# --- LÓGICA DE CASTEO ---

func _start_casting_process(skill: SkillData, target, time: float):
	is_casting = true
	pending_skill = skill
	pending_target = target
	
	# Emitir señal para que aparezca la barra sobre la cabeza
	cast_started.emit(skill.skill_name, time)
	get_tree().call_group("hud", "add_log_message", "Casteando %s..." % skill.skill_name, Color.CYAN)
	
	# Crear un Tween que funcione como Timer
	if current_cast_tween: current_cast_tween.kill()
	current_cast_tween = create_tween()
	
	# Simplemente esperamos el tiempo. Si el tween termina, el cast tuvo éxito.
	current_cast_tween.tween_interval(time)
	current_cast_tween.tween_callback(_on_cast_finished)

func _on_cast_finished():
	if not is_casting: return
	
	is_casting = false
	cast_completed.emit()
	
	# Ejecutar el efecto real
	_finalize_skill_execution(pending_skill, pending_target)
	
	# Limpieza
	pending_skill = null
	pending_target = null

func _interrupt_casting(force: bool = false):
	if not is_casting: return
	
	# Solo interrumpir si la skill lo permite (algunas skills como "Endure" evitan esto)
	# EXCEPTO cuando force=true (como cuando el jugador recibe daño)
	if not force and pending_skill and not pending_skill.is_interruptible:
		return

	is_casting = false
	if current_cast_tween:
		current_cast_tween.kill()
	
	cast_interrupted.emit()
	get_tree().call_group("hud", "add_log_message", "¡Casteo interrumpido!", Color.RED)
	
	pending_skill = null
	pending_target = null

# --- EJECUCIÓN FINAL (Lo que antes hacía execute_armed_skill) ---

func _finalize_skill_execution(skill: SkillData, target_data):
	# Validar SP y Cooldown justo antes de disparar (por si el SP bajó durante el cast)
	if sp_comp and sp_comp.current_sp < skill.sp_cost:
		get_tree().call_group("hud", "add_log_message", "SP insuficiente al terminar cast", Color.RED)
		return

	if sp_comp:
		sp_comp.use_sp(skill.sp_cost)
	
	_start_cooldown(skill)

	# Lógica de Efectos (Tu código existente)
	match skill.type:
		SkillData.SkillType.TARGET:
			if target_data is Node3D and is_instance_valid(target_data):
				_apply_damage(target_data, skill)
		SkillData.SkillType.POINT:
			if target_data is Vector3:
				_apply_aoe_damage(target_data, skill)
		SkillData.SkillType.SELF:
			_apply_aoe_damage(actor.global_position, skill)

	# Visuals
	if skill.effect_scene:
		var pos = target_data if target_data is Vector3 else target_data.global_position
		# Ajuste por si el target murió/desapareció durante el cast
		if target_data is Node3D and not is_instance_valid(target_data):
			return 
			
		var fx = skill.effect_scene.instantiate()
		get_tree().current_scene.add_child(fx)
		fx.global_position = pos

# --- FUNCIONES DE DAÑO ACTUALIZADAS CON MATRIZ ELEMENTAL ---

func _apply_damage(target: Node3D, skill: SkillData):
	if not is_instance_valid(target): return
	
	# Prevent self-targeting
	if target == actor: return
	
	if target.has_node("HealthComponent") and target.has_node("StatsComponent"):
		var target_stats = target.get_node("StatsComponent") as StatsComponent
		
		# 1. Calculamos el daño base (ATK * Multiplicador de Skill)
		var base_damage = int(stats.get_atk() * skill.damage_multiplier)
		
		# 2. Obtenemos el daño final pasando por la matriz de CombatMath
		# Usamos el elemento que viene definido en el recurso de la Skill
		var final_damage = CombatMath.calculate_skill_damage(
			base_damage, 
			skill.element, 
			target_stats
		)
		
		# 3. Aplicar daño y feedback
		target.get_node("HealthComponent").take_damage(final_damage)
		
		if actor.has_method("spawn_floating_text"):
			# Podemos pasar un color diferente si el daño fue elementalmente fuerte (opcional)
			actor.spawn_floating_text(target.global_position, final_damage, false)
		
		# 4. Aplicar status effects
		if skill.status_effects.size() > 0 and randf() < skill.status_effect_chance:
			_apply_skill_status_effects(target, skill)


func _apply_aoe_damage(center_pos: Vector3, skill: SkillData):
	var enemies = get_tree().get_nodes_in_group("enemy")
	var hit_count = 0
	
	# Daño base antes de los multiplicadores por enemigo
	var base_damage = int(stats.get_atk() * skill.damage_multiplier)
	
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		
		# Exclude the actor (caster) from AOE damage
		if enemy == actor: continue
		
		if enemy.global_position.distance_to(center_pos) <= skill.aoe_radius:
			if enemy.has_node("HealthComponent") and enemy.has_node("StatsComponent"):
				var target_stats = enemy.get_node("StatsComponent") as StatsComponent
				
				# Cada enemigo en el área puede tener un elemento distinto
				# Calculamos el daño específico para este objetivo
				var final_damage = CombatMath.calculate_skill_damage(
					base_damage, 
					skill.element, 
					target_stats
				)
				
				enemy.get_node("HealthComponent").take_damage(final_damage)
				
				if actor.has_method("spawn_floating_text"):
					actor.spawn_floating_text(enemy.global_position, final_damage, false)
				
				# Aplicar status effects
				if skill.status_effects.size() > 0 and randf() < skill.status_effect_chance:
					_apply_skill_status_effects(enemy, skill)
				
				hit_count += 1
	
	if hit_count > 0:
		get_tree().call_group("hud", "add_log_message", 
			"%s golpeó a %d enemigos" % [skill.skill_name, hit_count], 
			Color.YELLOW)

func _apply_skill_status_effects(target: Node3D, skill: SkillData):
	if not is_instance_valid(target): return
	
	if target.has_node("StatusEffectManagerComponent"):
		var status_manager = target.get_node("StatusEffectManagerComponent")
		var effect = skill.status_effects[randi() % skill.status_effects.size()]
		status_manager.add_effect(effect)
		get_tree().call_group("hud", "add_log_message", 
			"%s infligió %s" % [skill.skill_name, effect.effect_name], 
			Color.ORANGE)
