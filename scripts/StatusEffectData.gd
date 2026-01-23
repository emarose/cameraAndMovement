extends Resource
class_name StatusEffectData

enum EffectType { 
	STAT_MODIFIER, # Ejemplo: +10 STR (Blessing)
	DAMAGE_OVER_TIME, # Ejemplo: Poison
	STUN, # Impide movimiento y acciones
	SLOW # Reduce velocidad de movimiento
}

@export var effect_name: String = "Nuevo Estado"
@export var type: EffectType = EffectType.STAT_MODIFIER
@export var icon: Texture2D
@export var duration: float = 10.0 # Segundos (-1 para permanente)

@export_group("Configuración Específica")
@export var stat_to_modify: String = "atk" # "atk", "def", "speed", etc.
@export var value: float = 0.0 # Cuánto suma/resta o cuánto daño hace por tick
@export var tick_rate: float = 1.0 # Para venenos: daño cada X segundos
