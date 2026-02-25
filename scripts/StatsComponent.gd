extends Node
class_name StatsComponent

# Señales para comunicación con la UI
signal on_level_up(new_level)
signal on_xp_changed(current_xp, max_xp)
signal stats_changed

# Reference to current job data for HP/SP scaling
var current_job_data: JobData = null

# Definiciones de Tipos (Enums)
enum Element { NEUTRAL, WATER, EARTH, FIRE, WIND, POISON, HOLY, SHADOW, GHOST, UNDEAD }
enum Race { FORMLESS, UNDEAD, BRUTE, PLANT, INSECT, FISH, DEMON, DEMI_HUMAN, ANGEL, DRAGON }
enum Size { SMALL, MEDIUM, LARGE }
enum MovementType { SLIDE, JUMP, SLITHER } # Slide (Normal), Jump (Poring), Slither (Fabre)

@export_group("Base Stats")
@export var str_stat: int = 1
@export var agi: int = 1
@export var vit: int = 1
@export var int_stat: int = 1
@export var dex: int = 1
@export var luk: int = 1

@export_group("Progression")
@export var current_level: int = 1
@export var current_job_level: int = 1
@export var current_xp: int = 0
@export var xp_to_next_level: int = 100
@export var stat_points_available: int = 0

@export_group("Atributos de Combate")
@export var element: Element = Element.NEUTRAL
@export var race: Race = Race.FORMLESS
@export var size: Size = Size.MEDIUM

# --- Diccionarios de Bonos (Más limpio que 20 variables sueltas) ---
var equipment_bonuses = {"str": 0, "agi": 0, "vit": 0, "int": 0, "dex": 0, "luk": 0, "atk": 0, "def": 0}
var status_bonuses = {
	# Base Stats
	"str": 0, "agi": 0, "vit": 0, "int": 0, "dex": 0, "luk": 0,
	# Sub Stats (Directos)
	"atk": 0, "matk": 0, "def": 0, "mdef": 0, 
	"hit": 0, "flee": 0, "aspd_fixed": 0,
	# Porcentuales
	"speed_percent": 0.0 # 0.0 es base, 0.1 es +10%
}
var passive_skill_bonuses = {
	# Base Stats
	"str": 0, "agi": 0, "vit": 0, "int": 0, "dex": 0, "luk": 0,
	# Sub Stats (Directos)
	"atk": 0, "matk": 0, "def": 0, "mdef": 0, 
	"hit": 0, "flee": 0, "aspd_fixed": 0,
	# Porcentuales
	"speed_percent": 0.0
}

# --- Elemento del Ataque Físico ---
var weapon_element: Element = Element.NEUTRAL

# --- Diccionarios de Multiplicadores Pasivos (Estilo Cards) ---
# Clave: El ID del enum (int). Valor: El multiplicador (0.2 = +20% daño)
var race_dmg_boosts: Dictionary = {}
var element_dmg_boosts: Dictionary = {}
var size_dmg_boosts: Dictionary = {}

# Función de ayuda para obtener el bono de forma segura
func get_race_modifier(target_race: int) -> float:
	return race_dmg_boosts.get(target_race, 0.0)

func get_element_modifier_bonus(target_elem: int) -> float:
	return element_dmg_boosts.get(target_elem, 0.0)

# Aplicar bonos de equipamiento (Cards, armas, etc)
func apply_equipment_element_bonus(elem_id: int, value: float) -> void:
	element_dmg_boosts[elem_id] = value

func apply_equipment_race_bonus(race_id: int, value: float) -> void:
	race_dmg_boosts[race_id] = value

func clear_equipment_bonuses() -> void:
	race_dmg_boosts.clear()
	element_dmg_boosts.clear()
	weapon_element = Element.NEUTRAL
@export_group("Modificadores de Regeneración")
@export var hp_regen_flat_bonus: int = 0
@export var sp_regen_flat_bonus: int = 0
@export var hp_regen_percent_mod: float = 1.0 # 1.0 = 100% (normal)
@export var sp_regen_percent_mod: float = 1.0
@export var healing_item_bonus: float = 0.0 # Bonus to healing items (0.1 = +10%)

# Otros modificadores
var status_speed_percent_mod: float = 1.0
var is_stunned: bool = false

# Helper function to set current job data (called when player changes job)
func set_current_job(job_data: JobData) -> void:
	current_job_data = job_data
	# Trigger HP/SP recalculation in components
	_update_health_and_sp_components()
	stats_changed.emit()

# Internal helper to update HealthComponent and SPComponent with new max values
func _update_health_and_sp_components():
	var health_comp = get_parent().get_node_or_null("HealthComponent")
	var sp_comp = get_parent().get_node_or_null("SPComponent")
	
	if health_comp:
		# IMPORTANTE: Usa una función que actualice el máximo pero NO recorte la vida todavía
		# si estás en medio de una carga de mapa.
		if health_comp.has_method("set_max_health"):
			health_comp.set_max_health(get_max_hp(), false) # El 'false' evita el clamp
		else:
			health_comp.max_health = get_max_hp()
	if sp_comp:
		if sp_comp.has_method("set_max_sp"):
			sp_comp.set_max_sp(get_max_sp(), false)
		else:
			sp_comp.max_sp = get_max_sp()	
# --- Getters de Totales (SIEMPRE usar estos en los cálculos) ---
func get_total_str() -> int: return str_stat + equipment_bonuses.str + status_bonuses.str + passive_skill_bonuses.str
func get_total_agi() -> int: return agi + equipment_bonuses.agi + status_bonuses.agi + passive_skill_bonuses.agi
func get_total_vit() -> int: return vit + equipment_bonuses.vit + status_bonuses.vit + passive_skill_bonuses.vit
func get_total_int() -> int: return int_stat + equipment_bonuses.int + status_bonuses.int + passive_skill_bonuses.int
func get_total_dex() -> int: return dex + equipment_bonuses.dex + status_bonuses.dex + passive_skill_bonuses.dex
func get_total_luk() -> int: return luk + equipment_bonuses.luk + status_bonuses.luk + passive_skill_bonuses.luk

# --- Atributos Derivados (Fórmulas estilo RO) ---
func get_atk() -> int:
	var t_str = get_total_str()
	# Fórmula: Base (STR) + Equipo + Buffs directos de ATK (Andre Card, Impositio Manus)
	var base = t_str + int(pow(t_str / 10.0, 2))
	return base + equipment_bonuses.atk + status_bonuses.atk + passive_skill_bonuses.atk

func get_matk() -> int:
	var t_int = get_total_int()
	var base = t_int + int(pow(t_int / 8.0, 2))
	# Ahora sumamos buffs de MATK directos si existen
	return base + status_bonuses.matk + passive_skill_bonuses.matk

func get_move_speed_modifier() -> float:
	if is_stunned: return 0.0
	# 1.0 (base) + bonos (ej: 0.25 para Peco Peco Ride). Valores negativos ralentizan.
	# Clamp para evitar velocidades demasiado bajas.
	return max(0.2, 1.0 + status_bonuses.speed_percent + passive_skill_bonuses.speed_percent)
	
func get_def() -> int:
	return get_total_vit() + int(float(current_level) / 2.0) + equipment_bonuses.def + status_bonuses.def + passive_skill_bonuses.def

func get_hit() -> int:
	return current_level + get_total_dex() + status_bonuses.hit + passive_skill_bonuses.hit

func get_flee() -> int:
	return current_level + get_total_agi() + status_bonuses.flee + passive_skill_bonuses.flee

func get_crit() -> int:
	# Crítico basado en LUK: LUK / 3
	return get_total_luk() / 3

# Calculate max HP based on JobData
# Loads base values from Novice JobData, then adds current job bonuses on top
func get_max_hp() -> int:
	# 1. Determinar qué Job usar. Si no hay uno asignado, usamos Novice como fallback.
	var job = current_job_data
	if not job:
		job = load("res://resources/jobs/Novice.tres") as JobData
	
	if not job:
		push_error("No se pudo cargar ningun JobData para el calculo de HP")
		return 60

	# 2. CALCULO ÚNICO (Sin sumas extra)
	# Formula: Base + (Crecimiento * Niveles extra) + (VIT * Factor)
	var hp = job.base_hp + (job.hp_growth * max(0, current_level - 1)) + (get_total_vit() * job.vit_hp_factor)
	
	var debug_str = "HP Calc: job=%s base=%d + growth=(%d*%d) + vit=(%d*%.2f) = %d" % [
		job.job_name,
		job.base_hp,
		job.hp_growth,
		max(0, current_level - 1),
		get_total_vit(),
		job.vit_hp_factor,
		hp
	]
	print(debug_str)
	
	return hp

# Calculate max SP based on JobData
# Loads base values from Novice JobData, then adds current job bonuses on top
func get_max_sp() -> int:
	# Load Novice JobData as the base (guaranteed to exist)
	var novice_job = load("res://resources/jobs/Novice.tres") as JobData
	if not novice_job:
		push_error("Failed to load Novice.tres for SP calculation")
		return 22 # Fallback
	
	# Calculate SP: base + (growth per level above 1) + INT bonus
	# Growth only applies at level 2+, not at initial level 1
	var sp = novice_job.base_sp + (novice_job.sp_growth * max(0, current_level - 1)) + (get_total_int() * novice_job.int_sp_factor)
	
	# If current job is not Novice, ADD job advancement bonuses on top
	if current_job_data and current_job_data.job_name != "Novice":
		sp += (current_job_data.base_sp - novice_job.base_sp)
		sp += (current_job_data.sp_growth - novice_job.sp_growth) * max(0, current_level - 1)
		sp += get_total_int() * (current_job_data.int_sp_factor - novice_job.int_sp_factor)
	
	var debug_str = "SP Calc: base=%d + growth=(%d*%d) + int=(%d*%.2f) = %d" % [
		novice_job.base_sp,
		novice_job.sp_growth,
		max(0, current_level - 1),
		get_total_int(),
		novice_job.int_sp_factor,
		sp
	]
	print(debug_str)
	
	return sp

func get_max_hp_bonus() -> int:
	return get_total_vit() * 15

# Natural HP regeneration per second
func get_hp_regen() -> int:
	# Base: VIT / 5, multiplied by hp_regen_percent_mod
	var base_regen = int(get_total_vit() / 5.0)
	var regen = int(base_regen * hp_regen_percent_mod) + hp_regen_flat_bonus
	return max(0, regen)

# Natural SP regeneration per second
func get_sp_regen() -> int:
	# Base: INT / 6, multiplied by sp_regen_percent_mod
	var base_regen = int(get_total_int() / 6.0)
	var regen = int(base_regen * sp_regen_percent_mod) + sp_regen_flat_bonus
	return max(0, regen)

func get_attack_speed() -> float:
	return max(0.2, 1.0 - (get_total_agi() * 0.01) - (get_total_dex() * 0.005) - status_bonuses.aspd_fixed - passive_skill_bonuses.aspd_fixed)

func get_aspd() -> int:
	return int(200 - (get_attack_speed() * 50))

func get_healing_item_bonus() -> float:
	return healing_item_bonus

func get_hp_regen_percent() -> float:
	return hp_regen_percent_mod

func get_sp_regen_percent() -> float:
	return sp_regen_percent_mod

# --- Lógica de Aplicación ---

func set_equipment_bonuses(new_bonuses: Dictionary):
	# Espera un diccionario con las claves de equipment_bonuses
	for key in new_bonuses:
		if equipment_bonuses.has(key):
			equipment_bonuses[key] = new_bonuses[key]
	_update_health_and_sp_components()
	stats_changed.emit() # Actualiza UI

func apply_status_bonus(stat_name: String, amount): # amount sin tipo fijo (int/float)
	if status_bonuses.has(stat_name):
		status_bonuses[stat_name] += amount
		stats_changed.emit()
	else:
		push_warning("Intentando aplicar buff a stat desconocido: " + stat_name)

# --- Passive Skill Bonuses ---
func apply_passive_skill_bonus(stat_name: String, amount):
	if passive_skill_bonuses.has(stat_name):
		passive_skill_bonuses[stat_name] += amount
		stats_changed.emit()
	else:
		push_warning("Intentando aplicar bonus pasivo a stat desconocido: " + stat_name)

func clear_passive_skill_bonuses():
	# Resetea todos los bonos de skills pasivas (útil al cambiar de job)
	for key in passive_skill_bonuses:
		passive_skill_bonuses[key] = 0
	stats_changed.emit()
# --- Progression ---

func add_xp(amount: int):
	current_xp += amount
	on_xp_changed.emit(current_xp, xp_to_next_level)
	while current_xp >= xp_to_next_level:
		level_up()

func level_up():
	current_level += 1
	current_xp -= xp_to_next_level
	xp_to_next_level = int(xp_to_next_level * 1.5)
	
	# En RO, los puntos ganados también escalan con el nivel
	# Fórmula sugerida: (Nivel / 5) + 3
	var points_to_add = int(current_level / 5.0) + 3
	stat_points_available += points_to_add
	
	# Update HP/SP when leveling up
	_update_health_and_sp_components()
	
	on_level_up.emit(current_level)
	stats_changed.emit()

# Cast de Skills
func get_cast_time_reduction(base_time: float) -> float:
	if base_time <= 0: return 0.0
	
	var total_dex = get_total_dex()
	
	# Fórmula: Tiempo * (1 - (DEX / 150))
	# Clamp para que nunca sea menor a 0
	var reduced_time = base_time * (1.0 - (float(total_dex) / 150.0))
	
	return max(0.0, reduced_time)

# Función para inicializar stats desde un recurso (para enemigos)
func initialize_from_resource(data: EnemyData):

	str_stat = data.str_stat
	agi = data.agi
	vit = data.vit
	int_stat = data.int_stat
	dex = data.dex
	luk = data.luk
	current_level = data.level
	
	# Inicializar atributos de combate
	element = data.element
	race = data.race
	size = data.type

# Devuelve cuánto cuesta subir el stat al siguiente nivel
func get_stat_upgrade_cost(current_base_value: int) -> int:
	# REGLA: Cada 10 puntos el costo sube en 1.
	# Si quieres tu regla específica (<20 cuesta 1, >=20 cuesta 2):
	if current_base_value < 20:
		return 1
	elif current_base_value < 40:
		return 2
	elif current_base_value < 60:
		return 3
	else:
		return 4
	
	# OPCIONAL: Fórmula matemática estilo RO original:
	# return int(floor((current_base_value - 1) / 10.0)) + 2

# Intenta subir un stat consumiendo puntos
func request_stat_increase(stat_name: String) -> bool:
	# 1. Obtener el valor base actual
	var current_val = 0
	match stat_name:
		"str": current_val = str_stat
		"agi": current_val = agi
		"vit": current_val = vit
		"int": current_val = int_stat
		"dex": current_val = dex
		"luk": current_val = luk
		_: return false # Stat no válido
	
	# 2. Calcular costo
	var cost = get_stat_upgrade_cost(current_val)
	
	# 3. Verificar si hay puntos suficientes
	if stat_points_available >= cost:
		stat_points_available -= cost
		
		# 4. Aplicar el incremento
		match stat_name:
			"str": str_stat += 1
			"agi": agi += 1
			"vit": vit += 1
			"int": int_stat += 1
			"dex": dex += 1
			"luk": luk += 1
		
		# Update HP/SP when VIT or INT changes
		if stat_name == "vit" or stat_name == "int":
			_update_health_and_sp_components()
		
		stats_changed.emit()
		return true # Éxito
		
	return false # No hay suficientes puntos
