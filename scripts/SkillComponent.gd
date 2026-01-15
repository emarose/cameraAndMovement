extends Node
class_name SkillComponent
signal skill_state_changed

var stats: StatsComponent
var sp_comp: SPComponent
var actor: Node3D

# --- NUEVO: Estado de la Skill ---
var armed_skill: SkillData = null

func setup(actor_node: Node3D, stats_node: StatsComponent, sp_node: SPComponent):
	actor = actor_node
	stats = stats_node
	sp_comp = sp_node

# Paso 1: "Armar" la skill
func arm_skill(skill: SkillData):
	if not skill: return
	
	# Verificar SP antes de siquiera dejarle seleccionar
	if sp_comp.current_sp < skill.sp_cost:
		get_tree().call_group("hud", "add_log_message", "SP insuficiente para " + skill.skill_name, Color.RED)
		return
	armed_skill = skill
	skill_state_changed.emit()
	print("[SkillSystem] Skill Armada: ", skill.skill_name)
	get_tree().call_group("hud", "add_log_message", "Selecciona objetivo para: " + skill.skill_name, Color.CYAN)

# Paso 2: Cancelar
func cancel_cast():
	if armed_skill:
		print("[SkillSystem] Cast Cancelado")
		armed_skill = null
		skill_state_changed.emit()
		get_tree().call_group("hud", "add_log_message", "Habilidad cancelada", Color.GRAY)
		
# Paso 3: Ejecutar (El click izquierdo llama aquí)
func execute_armed_skill(target: Node3D):
	if not armed_skill or not target: return
	
	# Ejecutar daño (tu lógica actual)
	var final_damage = int(stats.get_atk() * armed_skill.damage_multiplier)
	if target.has_node("HealthComponent"):
		target.get_node("HealthComponent").take_damage(final_damage)
		sp_comp.use_sp(armed_skill.sp_cost)
		
		if actor.has_method("spawn_floating_text"):
			actor.spawn_floating_text(target.global_position, final_damage, false)
	
	# Muy importante: Limpiar después de usar
	armed_skill = null
	skill_state_changed.emit()
