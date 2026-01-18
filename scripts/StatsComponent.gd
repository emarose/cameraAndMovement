extends Node
class_name StatsComponent

signal on_level_up(new_level)
signal on_xp_changed(current_xp, max_xp)

@export_group("Base Stats")
@export var str_stat: int = 1  # Fuerza -> Aumenta ATK
@export var agi: int = 1  # Agilidad -> Aumenta ASPD y FLEE
@export var vit: int = 1  # Vitalidad -> Aumenta MaxHP y DEF física
@export var int_stat: int = 1 # Inteligencia -> MATK y MaxSP
@export var dex: int = 1  # Destreza -> HIT y daño mínimo
@export var luk: int = 1  # Suerte -> Críticos y evasión perfecta

# Modificadores de Regeneración
@export_group("Modificadores de Regeneración")
@export var hp_regen_flat_bonus: int = 0
@export var sp_regen_flat_bonus: int = 0
@export var hp_regen_percent_mod: float = 1.0 # 1.0 = 100% (normal)
@export var sp_regen_percent_mod: float = 1.0

@export_group("Current Resources") # Para que no se pierdan con los base stats

@export_group("Progression")
@export var current_level: int = 1
@export var current_xp: int = 0
@export var xp_to_next_level: int = 100
@export var stat_points_available: int = 0

# --- Atributos Derivados (Calculados) ---
func get_total_vit() -> int: return vit # Es esto lo mismo que get_max_hp_bonus?
func get_total_int() -> int: return int_stat

func get_atk() -> int:
	# Fórmula RO simplificada: STR + (STR/10)^2
	return str_stat + int(pow(str_stat / 10.0, 2))
	
func get_matk() -> int:
	return int_stat + int(pow(int_stat / 8.0, 2))

func get_hit() -> int:
	# HIT = Nivel + DEX
	return current_level + dex

func get_flee() -> int:
	# FLEE = Nivel + AGI
	return current_level + agi

func get_max_hp_bonus() -> int:
	# Vida extra por vitalidad
	return vit * 15

func get_attack_speed() -> float:
	# Cuanto más AGI, menor es el tiempo entre ataques (cooldown)
	# Retorna segundos. Ejemplo: 1.0s base, baja a 0.5s con mucha AGI.
	return max(0.2, 1.0 - (agi * 0.01) - (dex * 0.005))

func get_aspd() -> int:
	# Una fórmula simple para transformar el cooldown en un valor de 140-190
	var cooldown = get_attack_speed()
	return int(200 - (cooldown * 50))

func calculate_hit_chance(attacker_hit: int, defender_flee: int) -> float:
	var chance = 0.8 + (float(attacker_hit - defender_flee) / 100.0)
	return clamp(chance, 0.05, 0.95)

func get_def() -> int:
	return vit + (current_level / 2)

# --- Lógica de Nivel ---

func get_max_sp() -> int:
	# Fórmula RO: INT * 10 + Nivel * 2
	return (int_stat * 10) + (current_level * 2)

func add_xp(amount: int):
	# Log de experiencia ganada
	get_tree().call_group("hud", "add_log_message", "Has ganado %d de experiencia." % amount, Color.CHARTREUSE)
	
	current_xp += amount
	on_xp_changed.emit(current_xp, xp_to_next_level)
	
	while current_xp >= xp_to_next_level:
		level_up()

func level_up():
	current_level += 1
	current_xp -= xp_to_next_level
	xp_to_next_level = int(xp_to_next_level * 1.5)
	stat_points_available += 5
	
	# Emitimos la señal (El HUD la escucha y actualiza el label de nivel y puntos)
	on_level_up.emit(current_level)

# Función para inicializar stats desde un recurso (para enemigos)
func initialize_from_resource(data: EnemyData):
	str_stat = data.str_stat
	agi = data.agi
	vit = data.vit
	int_stat = data.int_stat
	dex = data.dex
	luk = data.luk
	current_level = data.level
	# Puedes inicializar más cosas si el recurso las tiene
