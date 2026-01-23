extends Node
class_name StatusEffectManager

# Señales para que el HUD dibuje/borre los iconos
signal effect_started(status_data)
signal effect_ended(status_data)

# Referencias
@onready var stats_comp: StatsComponent = get_parent().get_node("StatsComponent")
@onready var health_comp: HealthComponent = get_parent().get_node("HealthComponent")

# Diccionario para controlar los efectos activos
# Clave: Nombre del efecto. Valor: Diccionario con datos de instancia (tiempo restante, etc)
var active_effects: Dictionary = {}

func _process(delta: float):
	# Recorremos los efectos activos para reducir su tiempo
	# Usamos active_effects.keys() para poder modificar el diccionario dentro del loop de forma segura si es necesario
	var keys = active_effects.keys()
	
	for id in keys:
		var instance = active_effects[id]
		
		# 1. Lógica de Tiempo
		if instance.duration > 0: # Si no es infinito
			instance.remaining -= delta
			
			if instance.remaining <= 0:
				remove_effect(id)
				continue # Saltamos al siguiente

		# 2. Lógica de Daño por Tiempo (DoT)
		if instance.data.type == StatusEffectData.EffectType.DAMAGE_OVER_TIME:
			instance.tick_timer += delta
			if instance.tick_timer >= instance.data.tick_rate:
				instance.tick_timer = 0.0
				_apply_dot_damage(instance.data.value)

## Función principal para recibir un efecto
func add_effect(data: StatusEffectData):
	print("add effect", data)
	if active_effects.has(data.effect_name):
		# CASO A: Ya lo tengo -> Refrescar duración (Reset timer)
		active_effects[data.effect_name].remaining = data.duration
		print("Efecto refrescado: ", data.effect_name)
		# Nota: En RO algunos buffs no se refrescan, pero lo estándar hoy día es que sí.
	else:
		# CASO B: Es nuevo -> Aplicar y guardar
		var new_instance = {
			"data": data,
			"remaining": data.duration,
			"duration": data.duration, # Guardamos el total para barras de progreso
			"tick_timer": 0.0
		}
		active_effects[data.effect_name] = new_instance
		_apply_effect_logic(data, true) # true = aplicar
		
		effect_started.emit(data)
		print("Efecto iniciado: ", data.effect_name)

## Función para quitar un efecto forzosamente o por tiempo
func remove_effect(effect_name: String):
	if active_effects.has(effect_name):
		var instance = active_effects[effect_name]
		_apply_effect_logic(instance.data, false) # false = remover
		
		active_effects.erase(effect_name)
		effect_ended.emit(instance.data)
		print("Efecto finalizado: ", effect_name)

# --- Lógica Interna de Aplicación ---

func _apply_effect_logic(data: StatusEffectData, is_applying: bool):
	var mult = 1 if is_applying else -1
	
	match data.type:
		StatusEffectData.EffectType.STAT_MODIFIER:
			# Recorremos el diccionario de modificadores
			for stat_name in data.modifiers:
				var value = data.modifiers.get(stat_name, 0)
				
				if stats_comp:
					stats_comp.apply_status_bonus(stat_name, value * mult)
		
		StatusEffectData.EffectType.STUN:
			if stats_comp:
				stats_comp.is_stunned = is_applying
				stats_comp.stats_changed.emit()

func _apply_dot_damage(damage: int):
	print("Sufriendo daño por veneno/quemadura: ", damage)
	if health_comp:
		health_comp.take_damage(damage)
