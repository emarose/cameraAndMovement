extends Resource
class_name StatusEffectData

enum EffectType { STAT_MODIFIER, DAMAGE_OVER_TIME, STUN }

@export_group("Visual")
@export var effect_name: String = "Buff"
@export var icon: Texture2D

@export_group("Configuración")
@export var type: EffectType = EffectType.STAT_MODIFIER
@export var duration: float = 30.0
@export var tick_rate: float = 1.0
@export var value: int = 0 # Damage per tick for DAMAGE_OVER_TIME effects

@export_group("Modificadores")
# CLAVE: Nombre exacto del stat (str, agi, atk, matk, speed_mod, etc)
# VALOR: Cantidad a sumar
@export var modifiers: Dictionary = {
	# Base stats
	"str": 0, "agi": 0, "vit": 0, "int": 0, "dex": 0, "luk": 0,
	# Substats directos
	"atk": 0, "matk": 0, "def": 0, "mdef": 0, "hit": 0, "flee": 0, "aspd_fixed": 0,
	# Porcentuales
	"speed_percent": 0.0
}
