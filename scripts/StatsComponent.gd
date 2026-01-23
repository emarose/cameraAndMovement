extends Node
class_name StatsComponent

# Señales para comunicación con la UI
signal on_level_up(new_level)
signal on_xp_changed(current_xp, max_xp)
signal stats_changed # <-- NUEVA: Avisa a la UI que cualquier stat cambió

@export_group("Base Stats")
@export var str_stat: int = 1
@export var agi: int = 1
@export var vit: int = 1
@export var int_stat: int = 1
@export var dex: int = 1
@export var luk: int = 1

@export_group("Progression")
@export var current_level: int = 1
@export var current_xp: int = 0
@export var xp_to_next_level: int = 100
@export var stat_points_available: int = 0

# --- Diccionarios de Bonos (Más limpio que 20 variables sueltas) ---
var equipment_bonuses = {"str": 0, "agi": 0, "vit": 0, "int": 0, "dex": 0, "luk": 0, "atk": 0, "def": 0}
var status_bonuses = {"str": 0, "agi": 0, "vit": 0, "int": 0, "dex": 0, "luk": 0, "atk": 0, "def": 0}
# Modificadores de Regeneración

@export_group("Modificadores de Regeneración")
@export var hp_regen_flat_bonus: int = 0
@export var sp_regen_flat_bonus: int = 0
@export var hp_regen_percent_mod: float = 1.0 # 1.0 = 100% (normal)
@export var sp_regen_percent_mod: float = 1.0

# Otros modificadores
var status_speed_percent_mod: float = 1.0
var is_stunned: bool = false

# --- Getters de Totales (SIEMPRE usar estos en los cálculos) ---
func get_total_str() -> int: return str_stat + equipment_bonuses.str + status_bonuses.str
func get_total_agi() -> int: return agi + equipment_bonuses.agi + status_bonuses.agi
func get_total_vit() -> int: return vit + equipment_bonuses.vit + status_bonuses.vit
func get_total_int() -> int: return int_stat + equipment_bonuses.int + status_bonuses.int
func get_total_dex() -> int: return dex + equipment_bonuses.dex + status_bonuses.dex
func get_total_luk() -> int: return luk + equipment_bonuses.luk + status_bonuses.luk

# --- Atributos Derivados (Fórmulas estilo RO) ---
func get_atk() -> int:
	var t_str = get_total_str()
	return t_str + int(pow(t_str / 10.0, 2)) + equipment_bonuses.atk + status_bonuses.atk
	
func get_matk() -> int:
	var t_int = get_total_int()
	return t_int + int(pow(t_int / 8.0, 2))

func get_def() -> int:
	return get_total_vit() + (current_level / 2) + equipment_bonuses.def + status_bonuses.def

func get_hit() -> int:
	return current_level + get_total_dex()

func get_flee() -> int:
	return current_level + get_total_agi()

func get_max_sp() -> int:
	return (get_total_int() * 10) + (current_level * 2)

func get_max_hp_bonus() -> int:
	return get_total_vit() * 15

func get_attack_speed() -> float:
	return max(0.2, 1.0 - (get_total_agi() * 0.01) - (get_total_dex() * 0.005))

func get_aspd() -> int:
	return int(200 - (get_attack_speed() * 50))

func get_move_speed_modifier() -> float:
	return 0.0 if is_stunned else status_speed_percent_mod

# --- Lógica de Aplicación ---

func set_equipment_bonuses(new_bonuses: Dictionary):
	# Espera un diccionario con las claves de equipment_bonuses
	for key in new_bonuses:
		if equipment_bonuses.has(key):
			equipment_bonuses[key] = new_bonuses[key]
	stats_changed.emit() # Actualiza UI

func apply_status_bonus(stat_name: String, amount: int):
	if status_bonuses.has(stat_name):
		status_bonuses[stat_name] += amount
		stats_changed.emit() # <-- Esto hará que tu UI se refresque sola
		print("Status: %s modificado por %d. ATK Total: %d" % [stat_name, amount, get_atk()])

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
	stat_points_available += 5
	on_level_up.emit(current_level)
	stats_changed.emit()

# Función para inicializar stats desde un recurso (para enemigos)

func initialize_from_resource(data: EnemyData):

	str_stat = data.str_stat
	agi = data.agi
	vit = data.vit
	int_stat = data.int_stat
	dex = data.dex
	luk = data.luk
	current_level = data.level
