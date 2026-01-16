extends Node
class_name SkillComponent

signal skill_state_changed

var stats: StatsComponent
var sp_comp: SPComponent
var actor: Node3D
var armed_skill: SkillData = null

func setup(actor_node: Node3D, stats_node: StatsComponent, sp_node: SPComponent):
	actor = actor_node
	stats = stats_node
	sp_comp = sp_node

func arm_skill(skill: SkillData):
	if not skill: return

	if sp_comp and sp_comp.current_sp < skill.sp_cost:
		get_tree().call_group("hud", "add_log_message", "SP insuficiente.", Color.RED)
		return

	armed_skill = skill
	skill_state_changed.emit()
	
	var msg = "Selecciona objetivo" if skill.type == SkillData.SkillType.TARGET else "Selecciona área"
	get_tree().call_group("hud", "add_log_message", msg + " para: " + skill.skill_name, Color.CYAN)

func cancel_cast():
	if armed_skill:
		armed_skill = null # Primero limpiamos
		skill_state_changed.emit() # Luego avisamos al Player/HUD
		get_tree().call_group("hud", "add_log_message", "Cancelado.", Color.GRAY)
		
# CAMBIO IMPORTANTE: Quitamos el tipo estático ": Node3D" para aceptar Vector3 también
func execute_armed_skill(target_data) -> void:
	if not armed_skill: return
	
	# Consumo de SP (se cobra una sola vez al ejecutar)
	if sp_comp:
		sp_comp.use_sp(armed_skill.sp_cost)
	
	match armed_skill.type:
		SkillData.SkillType.TARGET:
			# Lógica de siempre (Single Target)
			if target_data is Node3D:
				_apply_damage(target_data)
				
		SkillData.SkillType.POINT:
			# Lógica AOE (target_data es un Vector3 en el suelo)
			if target_data is Vector3:
				_apply_aoe_damage(target_data)
				
		SkillData.SkillType.SELF:
			# Lógica centrada en el jugador (ej: Magnum Break)
			_apply_aoe_damage(actor.global_position)

	# Instanciar efecto visual si existe
	if armed_skill.effect_scene and target_data:
		var pos = target_data if target_data is Vector3 else target_data.global_position
		var fx = armed_skill.effect_scene.instantiate()
		get_tree().current_scene.add_child(fx)
		fx.global_position = pos

	armed_skill = null
	skill_state_changed.emit()

# Función auxiliar para aplicar daño en área
func _apply_aoe_damage(center_pos: Vector3):
	var damage = int(stats.get_atk() * armed_skill.damage_multiplier)
	var enemies = get_tree().get_nodes_in_group("enemy")
	var hit_count = 0
	
	for enemy in enemies:
		# Chequear distancia al centro de la explosión
		if enemy.global_position.distance_to(center_pos) <= armed_skill.aoe_radius:
			if enemy.has_node("HealthComponent"):
				enemy.get_node("HealthComponent").take_damage(damage)
				if actor.has_method("spawn_floating_text"):
					actor.spawn_floating_text(enemy.global_position, damage, false)
				hit_count += 1
	
	if hit_count > 0:
		get_tree().call_group("hud", "add_log_message", "AOE golpeó a %d enemigos" % hit_count, Color.YELLOW)

func _apply_damage(target: Node3D):
	var final_damage = int(stats.get_atk() * armed_skill.damage_multiplier)
	if target.has_node("HealthComponent"):
		target.get_node("HealthComponent").take_damage(final_damage)
		if actor.has_method("spawn_floating_text"):
			actor.spawn_floating_text(target.global_position, final_damage, false)
