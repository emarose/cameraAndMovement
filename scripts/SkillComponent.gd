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
	if not skill:
		return

	# Validar sp_comp seguro
	if sp_comp and sp_comp.current_sp < skill.sp_cost:
		get_tree().call_group("hud", "add_log_message", "SP insuficiente para " + skill.skill_name, Color.RED)
		return

	armed_skill = skill
	skill_state_changed.emit()
	get_tree().call_group("hud", "add_log_message", "Selecciona objetivo para: " + skill.skill_name, Color.CYAN)

func cancel_cast():
	if armed_skill:
		armed_skill = null
		skill_state_changed.emit()
		get_tree().call_group("hud", "add_log_message", "Habilidad cancelada", Color.GRAY)

func execute_armed_skill(target: Node3D) -> void:
	if not armed_skill:
		return
	if not target or not is_instance_valid(target):
		return
	var final_damage = int(stats.get_atk() * armed_skill.damage_multiplier)

	if target.has_node("HealthComponent"):
		target.get_node("HealthComponent").take_damage(final_damage)
		if sp_comp:
			sp_comp.use_sp(armed_skill.sp_cost)
			
		if actor and actor.has_method("spawn_floating_text"):
			actor.spawn_floating_text(target.global_position, final_damage, false)

	armed_skill = null
	skill_state_changed.emit()
