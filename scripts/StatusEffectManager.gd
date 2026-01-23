extends Node
class_name StatusEffectManager

signal effect_added(effect_instance)
signal effect_removed(effect_instance)

# Guardamos los efectos activos. 
# Usamos un diccionario para refrescar duración si se aplica el mismo efecto.
var active_effects: Dictionary = {}

func _process(delta):
	var to_remove = []
	
	for effect_id in active_effects:
		var effect = active_effects[effect_id]
		
		# Solo descontar tiempo si no es permanente (-1)
		if effect.remaining_duration > 0:
			effect.remaining_duration -= delta
			if effect.remaining_duration <= 0:
				to_remove.append(effect_id)
		
		# Lógica de Daño por Tiempo (DOT)
		if effect.data.type == StatusEffectData.EffectType.DAMAGE_OVER_TIME:
			effect.tick_timer += delta
			if effect.tick_timer >= effect.data.tick_rate:
				_apply_dot(effect)
				effect.tick_timer = 0.0

	for id in to_remove:
		remove_effect(id)

func add_effect(data: StatusEffectData):
	if active_effects.has(data.effect_name):
		# Si ya existe, refrescamos la duración (estilo RO)
		active_effects[data.effect_name].remaining_duration = data.duration
	else:
		# Crear nueva instancia de efecto
		var new_instance = {
			"data": data,
			"remaining_duration": data.duration,
			"tick_timer": 0.0
		}
		active_effects[data.effect_name] = new_instance
		_on_effect_started(new_instance)
		effect_added.emit(new_instance)

func remove_effect(effect_name: String):
	if active_effects.has(effect_name):
		var effect = active_effects[effect_name]
		_on_effect_ended(effect)
		active_effects.erase(effect_name)
		effect_removed.emit(effect)

# --- Lógica Interna ---

func _on_effect_started(effect):
	var data = effect.data
	match data.type:
		StatusEffectData.EffectType.STAT_MODIFIER:
			_modify_stat(data.stat_to_modify, data.value)
		StatusEffectData.EffectType.STUN:
			_set_stun(true)

func _on_effect_ended(effect):
	var data = effect.data
	match data.type:
		StatusEffectData.EffectType.STAT_MODIFIER:
			_modify_stat(data.stat_to_modify, -data.value) # Revertimos el bono
		StatusEffectData.EffectType.STUN:
			_set_stun(false)

func _modify_stat(stat_name: String, amount: float):
	# Aquí conectamos con tu StatsComponent
	var stats = get_parent().get_node_or_null("StatsComponent")
	if stats and stats.has_method("modify_stat"):
		stats.modify_stat(stat_name, amount)

func _set_stun(active: bool):
	# El Player o Enemigo debe chequear esta variable para poder moverse/atacar
	get_parent().set("is_stunned", active)

func _apply_dot(effect):
	var health = get_parent().get_node_or_null("HealthComponent")
	if health:
		health.take_damage(effect.data.value)
