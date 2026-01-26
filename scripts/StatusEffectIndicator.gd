extends Control
class_name StatusEffectIndicator

var status_data: StatusEffectData
var remaining_time: float = 0.0
var duration: float = 0.0

@onready var name_label = $Panel/VBoxContainer/Name
@onready var icon_rect = $Panel/VBoxContainer/Icon
@onready var timer_label = $Panel/VBoxContainer/Timer
@onready var panel = $Panel

func setup(effect_data: StatusEffectData, duration_remaining: float) -> void:
	status_data = effect_data
	remaining_time = duration_remaining
	duration = duration_remaining
	
	# Mostrar nombre del efecto
	name_label.text = effect_data.effect_name
	tooltip_text = effect_data.effect_name
	
	# Color según tipo de efecto
	var color = _get_effect_color(effect_data.type)
	icon_rect.color = color
	panel.self_modulate = Color(1, 1, 1, 0.9)
	
	# Actualizar timer
	_update_timer_display()

func _process(delta: float) -> void:
	if remaining_time > 0:
		remaining_time -= delta
		_update_timer_display()
		
		if remaining_time <= 0:
			queue_free()

func _update_timer_display() -> void:
	if remaining_time > 60:
		timer_label.text = "%dm" % int(remaining_time / 60.0)
	else:
		timer_label.text = "%ds" % int(max(0, remaining_time))
	
	# Flash cuando le quedan pocos segundos
	if remaining_time < 5 and remaining_time > 0:
		var alpha = 0.5 + sin(remaining_time * PI * 2) * 0.3
		panel.self_modulate = Color(1, 0.5, 0.5, alpha)

func refresh_timer(new_duration: float) -> void:
	"""Actualiza el timer cuando el efecto se refresca"""
	remaining_time = new_duration
	duration = new_duration
	_update_timer_display()
	
	# Feedback visual rápido
	var tween = create_tween()
	tween.tween_property(panel, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.1)

func _get_effect_color(effect_type: int) -> Color:
	match effect_type:
		StatusEffectData.EffectType.STAT_MODIFIER:
			return Color(0.4, 0.8, 1.0, 1.0)  # Cyan para buffs
		StatusEffectData.EffectType.DAMAGE_OVER_TIME:
			return Color(0.8, 0.2, 0.2, 1.0)  # Rojo para DoT
		StatusEffectData.EffectType.STUN:
			return Color(1.0, 1.0, 0.0, 1.0)  # Amarillo para stun
		_:
			return Color(0.5, 0.5, 0.5, 1.0)
