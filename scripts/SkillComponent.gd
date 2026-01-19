extends Node
class_name SkillComponent

signal skill_state_changed
signal skill_cooldown_started(skill_name: String, duration: float)

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
	if not can_use_skill(skill): return
	armed_skill = skill
	skill_state_changed.emit()

func cancel_cast():
	if armed_skill:
		armed_skill = null
		skill_state_changed.emit()
		get_tree().call_group("hud", "add_log_message", "Cancelado.", Color.GRAY)
		
func execute_armed_skill(target_data) -> void:
	if not armed_skill: return
	
	# Guardamos referencia local porque al final la limpiaremos
	var skill_to_use = armed_skill 
	
	if sp_comp:
		sp_comp.use_sp(skill_to_use.sp_cost)
	
	# Registrar el cooldown también aquí para skills con target/point
	_start_cooldown(skill_to_use)

	match skill_to_use.type:
		SkillData.SkillType.TARGET:
			if target_data is Node3D:
				_apply_damage(target_data, skill_to_use)
				
		SkillData.SkillType.POINT:
			if target_data is Vector3:
				_apply_aoe_damage(target_data, skill_to_use)
				
		SkillData.SkillType.SELF:
			_apply_aoe_damage(actor.global_position, skill_to_use)

	if skill_to_use.effect_scene and target_data:
		var pos = target_data if target_data is Vector3 else target_data.global_position
		var fx = skill_to_use.effect_scene.instantiate()
		get_tree().current_scene.add_child(fx)
		fx.global_position = pos

	armed_skill = null
	skill_state_changed.emit()

# --- FUNCIONES DE DAÑO ACTUALIZADAS ---

# Ahora aceptan 'skill' como argumento para leer el radio y el multiplicador
func _apply_aoe_damage(center_pos: Vector3, skill: SkillData):
	var damage = int(stats.get_atk() * skill.damage_multiplier)
	var enemies = get_tree().get_nodes_in_group("enemy")
	var hit_count = 0
	
	for enemy in enemies:
		if enemy.global_position.distance_to(center_pos) <= skill.aoe_radius:
			if enemy.has_node("HealthComponent"):
				enemy.get_node("HealthComponent").take_damage(damage)
				if actor.has_method("spawn_floating_text"):
					actor.spawn_floating_text(enemy.global_position, damage, false)
				hit_count += 1
	
	if hit_count > 0:
		get_tree().call_group("hud", "add_log_message", "AOE golpeó a %d enemigos" % hit_count, Color.YELLOW)

func _apply_damage(target: Node3D, skill: SkillData):
	var final_damage = int(stats.get_atk() * skill.damage_multiplier)
	if target.has_node("HealthComponent"):
		target.get_node("HealthComponent").take_damage(final_damage)
		if actor.has_method("spawn_floating_text"):
			actor.spawn_floating_text(target.global_position, final_damage, false)
