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

# Helper function to get skill level from GameManager
func _get_skill_level(skill: SkillData) -> int:
	# For player, get from GameManager. For enemies, default to max level
	if actor.is_in_group("player"):
		return GameManager.get_skill_level(skill.id)
	else:
		# Enemies use skills at max level
		return skill.max_level

# Calculate SP cost based on skill level
func _get_skill_sp_cost(skill: SkillData, skill_level: int) -> int:
	if skill.sp_cost_base > 0:
		# Use level-based SP cost
		return skill.sp_cost_base + (skill.sp_cost_per_level * (skill_level - 1))
	else:
		# Use fixed SP cost
		return skill.sp_cost

# Calculate damage multiplier based on skill level
func _get_skill_damage_multiplier(skill: SkillData, skill_level: int) -> float:
	return skill.damage_multiplier + (skill.damage_per_level * (skill_level - 1))

func setup(actor_node: Node3D, stats_node: StatsComponent, sp_node: SPComponent):
	actor = actor_node
	stats = stats_node
	sp_comp = sp_node

func can_use_skill(skill: SkillData) -> bool:
	if not skill: return false
	
	if cooldown_timers.has(skill.skill_name):
		var cooldown_end = cooldown_timers[skill.skill_name]
		var current_time = Time.get_ticks_msec()
		if current_time < cooldown_end:
			var remaining = (cooldown_end - current_time) / 1000.0
			# Only show message for player
			if actor.is_in_group("player"):
				get_tree().call_group("hud", "add_log_message", "Habilidad en cooldown", Color.ORANGE)
			return false
		else:
			# Remove expired cooldown
			cooldown_timers.erase(skill.skill_name)
	
	# Only check SP if this is a player (has sp_comp with actual SP system)
	# Enemies use skills freely without SP cost
	var skill_level = _get_skill_level(skill)
	var sp_cost = _get_skill_sp_cost(skill, skill_level)
	
	if sp_comp and sp_comp.current_sp < sp_cost:
		print("  can_use_skill %s: Insufficient SP (need %d, have %d)" % [skill.skill_name, sp_cost, sp_comp.current_sp])
		# Only show message for player
		if actor.is_in_group("player"):
			get_tree().call_group("hud", "add_log_message", "SP insuficiente", Color.RED)
		return false
	
	return true

func cast_immediate(skill: SkillData):
	if not can_use_skill(skill): return

	var skill_level = _get_skill_level(skill)
	var sp_cost = _get_skill_sp_cost(skill, skill_level)
	
	# Only consume SP for players (enemies use skills for free)
	if sp_comp:
		sp_comp.use_sp(sp_cost)
	
	_start_cooldown(skill)
	
	# SOLUCIÓN ERROR LÍNEA 44: Ahora la función acepta el parámetro skill
	_apply_aoe_damage(actor.global_position, skill, skill_level) 
	
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
	
	# Only show message for player
	if actor.is_in_group("player"):
		get_tree().call_group("hud", "add_log_message", "Cancelado.", Color.GRAY)

	# 2. Si estaba activamente casteando (barra de progreso)
	if is_casting:
		_interrupt_casting()

func execute_armed_skill(target_data) -> void:
	if not armed_skill: 
		print("execute_armed_skill: No armed skill!")
		return
	
	var skill_to_use = armed_skill
	print("execute_armed_skill: Using skill %s with target_data: %s" % [skill_to_use.skill_name, target_data])
	
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
	# Only show message for player
	if actor.is_in_group("player"):
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
	# Only show message for player
	if actor.is_in_group("player"):
		get_tree().call_group("hud", "add_log_message", "¡Casteo interrumpido!", Color.RED)
	
	pending_skill = null
	pending_target = null

# --- EJECUCIÓN FINAL (Lo que antes hacía execute_armed_skill) ---

## Public method for enemies to finalize skill execution after their own casting
func finalize_skill_execution(skill: SkillData, target_data) -> void:
	print("finalize_skill_execution called with skill: %s, target_data: %s, type: %d" % [skill.skill_name, target_data, skill.type])
	_finalize_skill_execution(skill, target_data)

func _finalize_skill_execution(skill: SkillData, target_data):
	var skill_level = _get_skill_level(skill)
	var sp_cost = _get_skill_sp_cost(skill, skill_level)
	
	# Validar SP y Cooldown justo antes de disparar (por si el SP bajó durante el cast)
	# Only for players - enemies don't need SP
	if sp_comp and sp_comp.current_sp < sp_cost:
		# Only show message for player
		if actor.is_in_group("player"):
			get_tree().call_group("hud", "add_log_message", "SP insuficiente al terminar cast", Color.RED)
		return

	# Only consume SP for players (enemies use skills for free)
	if sp_comp:
		sp_comp.use_sp(sp_cost)
	
	_start_cooldown(skill)

	# Lógica de Efectos (Tu código existente)
	match skill.type:
		SkillData.SkillType.TARGET:
			print("_finalize_skill_execution: TARGET type, target_data is Node3D: %s, is_valid: %s" % [target_data is Node3D, is_instance_valid(target_data) if target_data is Node3D else false])
			if target_data is Node3D and is_instance_valid(target_data):
				_apply_damage(target_data, skill, skill_level)
		SkillData.SkillType.POINT:
			print("_finalize_skill_execution: POINT type, target_data is Vector3: %s, position: %s" % [target_data is Vector3, target_data])
			if target_data is Vector3:
				_apply_aoe_damage(target_data, skill, skill_level)
		SkillData.SkillType.SELF:
			print("_finalize_skill_execution: SELF type, applying at actor position: %s" % actor.global_position)
			_apply_aoe_damage(actor.global_position, skill, skill_level)

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

func _apply_damage(target: Node3D, skill: SkillData, skill_level: int = 1):
	if not is_instance_valid(target): return
	
	# Prevent self-targeting for damage skills (allow self-targeting for healing)
	if target == actor and not skill.heals: return
	
	if target.has_node("HealthComponent") and target.has_node("StatsComponent"):
		var target_stats = target.get_node("StatsComponent") as StatsComponent
		var target_health = target.get_node("HealthComponent")
		
		# Check if this is a healing skill
		if skill.heals:
			var heal_amount = _calculate_healing(skill, skill_level, target_stats, target_health)
			target_health.heal(heal_amount)
			
			if actor.has_method("spawn_floating_text"):
				actor.spawn_floating_text(target.global_position, heal_amount, false)
			
			if actor.is_in_group("player"):
				get_tree().call_group("hud", "add_log_message", 
					"%s curó %d HP" % [skill.skill_name, heal_amount], 
					Color.GREEN)
		else:
			# Damage skill
			var damage_multiplier = _get_skill_damage_multiplier(skill, skill_level)
			var base_damage = int(stats.get_atk() * damage_multiplier)
			
			var final_damage = CombatMath.calculate_skill_damage(
				base_damage, 
				skill.element, 
				target_stats
			)
			
			target_health.take_damage(final_damage)
			
			if actor.has_method("spawn_floating_text"):
				actor.spawn_floating_text(target.global_position, final_damage, false)
		
		# Apply status effects or stat buffs
		if skill.status_effects.size() > 0 and randf() < skill.status_effect_chance:
			_apply_skill_status_effects(target, skill)
		
		if skill.applies_stat_buff:
			_apply_stat_buffs(target, skill, skill_level)


func _apply_aoe_damage(center_pos: Vector3, skill: SkillData, skill_level: int = 1):
	var enemies = get_tree().get_nodes_in_group("enemy")
	var player = get_tree().get_first_node_in_group("player")
	var hit_count = 0
	
	var damage_multiplier = _get_skill_damage_multiplier(skill, skill_level)
	var base_damage = int(stats.get_atk() * damage_multiplier)
	
	print("_apply_aoe_damage: actor=%s, atk=%d, multiplier=%.2f, base_damage=%d, center_pos=%s, radius=%.1f, heals=%s" % [
		stats.actor_name if stats.has_meta("actor_name") else "unknown",
		stats.get_atk(),
		damage_multiplier,
		base_damage,
		center_pos,
		skill.aoe_radius,
		skill.heals
	])
	
	# For healing skills, heal allies; for damage skills, damage enemies
	if skill.heals:
		# Heal the caster (SELF type healing)
		if actor.has_node("HealthComponent") and actor.has_node("StatsComponent"):
			var caster_health = actor.get_node("HealthComponent")
			var caster_stats = actor.get_node("StatsComponent") as StatsComponent
			var heal_amount = _calculate_healing(skill, skill_level, caster_stats, caster_health)
			caster_health.heal(heal_amount)
			
			if actor.has_method("spawn_floating_text"):
				actor.spawn_floating_text(actor.global_position, heal_amount, false)
			
			if actor.is_in_group("player"):
				get_tree().call_group("hud", "add_log_message", 
					"%s curó %d HP" % [skill.skill_name, heal_amount], 
					Color.GREEN)
		
		# Apply stat buffs if this is a buff skill
		if skill.applies_stat_buff:
			_apply_stat_buffs(actor, skill, skill_level)
	else:
		# Damage enemies
		for enemy in enemies:
			if not is_instance_valid(enemy): continue
			
			# Exclude the actor (caster) from AOE damage
			if enemy == actor: continue
			
			if enemy.global_position.distance_to(center_pos) <= skill.aoe_radius:
				if enemy.has_node("HealthComponent") and enemy.has_node("StatsComponent"):
					var target_stats = enemy.get_node("StatsComponent") as StatsComponent
					
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
		
		# Also damage player if actor is an enemy and player is in range
		if player and is_instance_valid(player) and actor != player:
			if player.global_position.distance_to(center_pos) <= skill.aoe_radius:
				if player.has_node("HealthComponent") and player.has_node("StatsComponent"):
					var player_stats = player.get_node("StatsComponent") as StatsComponent
					print("_apply_aoe_damage -> Player hit! distance=%.1f, skill_radius=%.1f, player_def=%d" % [
						player.global_position.distance_to(center_pos),
						skill.aoe_radius,
						player_stats.get_def()
					])
					var final_damage = CombatMath.calculate_skill_damage(
						base_damage,
						skill.element,
						player_stats
					)
					
					print("  Before DEF: base=%d, after element calc: %d" % [base_damage, final_damage])
					
					player.get_node("HealthComponent").take_damage(final_damage)
					print("  FINAL damage to player: %d" % final_damage)
					
					if actor.has_method("spawn_floating_text"):
						actor.spawn_floating_text(player.global_position, final_damage, false)
					
					# Aplicar status effects
					if skill.status_effects.size() > 0 and randf() < skill.status_effect_chance:
						_apply_skill_status_effects(player, skill)
					
					hit_count += 1
		
		# Only show message for player
		if hit_count > 0 and actor.is_in_group("player"):
			get_tree().call_group("hud", "add_log_message", 
				"%s golpeó a %d enemigos" % [skill.skill_name, hit_count], 
				Color.YELLOW)

func _apply_skill_status_effects(target: Node3D, skill: SkillData):
	if not is_instance_valid(target): return
	
	# Validate status effects exist
	if skill.status_effects.is_empty():
		print("_apply_skill_status_effects: No status effects configured for %s" % skill.skill_name)
		return
	
	if target.has_node("StatusEffectManagerComponent"):
		var status_manager = target.get_node("StatusEffectManagerComponent")
		var effect = skill.status_effects[randi() % skill.status_effects.size()]
		
		# Validate effect resource is not nil
		if effect == null:
			print("_apply_skill_status_effects: Effect resource is null for %s" % skill.skill_name)
			return
		
		print("_apply_skill_status_effects: Applying %s to %s" % [effect.effect_name, target.name])
		status_manager.add_effect(effect)
		# Only show message for player
		if actor.is_in_group("player"):
			get_tree().call_group("hud", "add_log_message", 
				"%s infligió %s" % [skill.skill_name, effect.effect_name], 
				Color.ORANGE)
	else:
		print("_apply_skill_status_effects: Target %s has no StatusEffectManagerComponent" % target.name)

# Calculate healing amount based on skill data and level
func _calculate_healing(skill: SkillData, skill_level: int, target_stats: StatsComponent, target_health) -> int:
	var heal_amount: float = skill.heal_base + (skill.heal_per_level * skill_level)
	
	# Add INT scaling: (BaseLV + INT) / 8 * factor
	if skill.heal_int_scaling > 0:
		var int_factor = (stats.current_level + stats.get_total_int()) / 8.0
		heal_amount += int_factor * skill.heal_int_scaling * skill_level
	
	# Add base level scaling
	if skill.heal_base_level_scaling > 0:
		heal_amount += stats.current_level * skill.heal_base_level_scaling * skill_level
	
	# Add percentage of target's max HP
	if skill.heal_target_max_hp_percent > 0:
		heal_amount += target_health.max_health * skill.heal_target_max_hp_percent * skill_level
	
	# Apply healing item bonus if target has it (from passive skills like HP Recovery)
	if target_stats.has_method("get_healing_item_bonus"):
		var bonus_multiplier = target_stats.get_healing_item_bonus()
		heal_amount *= (1.0 + bonus_multiplier)
	
	return int(heal_amount)

# Apply stat buffs through status effects or directly
func _apply_stat_buffs(target: Node3D, skill: SkillData, skill_level: int):
	if not is_instance_valid(target): return
	if not target.has_node("StatsComponent"): return
	
	var target_stats = target.get_node("StatsComponent") as StatsComponent
	
	# Calculate buff amounts based on skill level
	var buff_data = {}
	if skill.buff_str_per_level > 0:
		buff_data["str"] = skill.buff_str_per_level * skill_level
	if skill.buff_dex_per_level > 0:
		buff_data["dex"] = skill.buff_dex_per_level * skill_level
	if skill.buff_int_per_level > 0:
		buff_data["int"] = skill.buff_int_per_level * skill_level
	if skill.buff_agi_per_level > 0:
		buff_data["agi"] = skill.buff_agi_per_level * skill_level
	if skill.buff_vit_per_level > 0:
		buff_data["vit"] = skill.buff_vit_per_level * skill_level
	if skill.buff_luk_per_level > 0:
		buff_data["luk"] = skill.buff_luk_per_level * skill_level
	
	if buff_data.size() > 0:
		# If there's a StatusEffectManagerComponent, we could create a buff effect
		# For now, apply directly to stats (you may want to create a proper StatusEffect for this)
		if target.has_node("StatusEffectManagerComponent") and skill.buff_duration > 0:
			# TODO: Create a dynamic status effect for stat buffs with duration
			# For now, create a status effect on the fly if needed
			print("_apply_stat_buffs: Applying buffs %s to %s (duration: %.1fs)" % [buff_data, target.name, skill.buff_duration])
			# This would require a BlessingSE.tres or similar - for now we just apply instantly
		
		# Apply buffs directly (or create a temporary status effect)
		for stat_name in buff_data:
			var bonus = buff_data[stat_name]
			if target_stats.has_method("apply_temporary_stat_bonus"):
				target_stats.apply_temporary_stat_bonus(stat_name, bonus, skill.buff_duration)
			else:
				# Fallback: apply as permanent bonus (could be improved)
				print("  Applying %d %s to %s" % [bonus, stat_name, target.name])
		
		if actor.is_in_group("player"):
			var buff_desc = ""
			for stat_name in buff_data:
				buff_desc += "+%d %s " % [buff_data[stat_name], stat_name.to_upper()]
			get_tree().call_group("hud", "add_log_message", 
				"%s: %s" % [skill.skill_name, buff_desc], 
				Color.CYAN)
