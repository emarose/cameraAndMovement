extends Node3D

@onready var label: Label3D = $Label3D

# Configuración de la animación
var float_height: float = 1.5  # Cuánto sube
var duration: float = 0.8      # Cuánto tarda en desaparecer

func _ready():
	# Iniciar la animación tan pronto aparece
	animate_and_destroy()

func set_values_and_animate(value: int, is_miss: bool, is_crit: bool = false, is_player_damage: bool = false):
	if is_miss:
		label.text = "Miss"
		label.modulate = Color(0.7, 0.7, 0.7) # Gris para miss
	else:
		label.text = str(value)
		if is_crit:
			label.modulate = Color(1, 0.2, 0.2) # Rojo para críticos
			label.pixel_size *= 1.5 # Más grande
		elif is_player_damage:
			label.modulate = Color(1, 0.2, 0.2) # Rojo para daño recibido por el jugador
		else:
			label.modulate = Color(0.883, 0.711, 0.061, 1.0) # Blanco normal (enemigos)

	# Asegurarse de que empiece visible
	label.transparency = 0.0
	animate_and_destroy()

func set_regen_text(value: int, regen_type: String):
	label.text = "+" + str(value)
	
	# Color según el tipo de regeneración
	if regen_type == "hp":
		label.modulate = Color(0.2, 0.8, 0.2) # Verde para HP
	elif regen_type == "sp":
		label.modulate = Color(0.2, 0.6, 1.0) # Azul para SP
	else:
		label.modulate = Color.WHITE
	
	# Asegurarse de que empiece visible
	label.transparency = 0.0
	
	animate_and_destroy()

func set_pickup_text(text: String):
	label.text = text
	label.modulate = Color(0.95, 0.82, 0.27)
	label.transparency = 0.0
	animate_and_destroy()

func animate_and_destroy():
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# 1. Flotar hacia arriba
	tween.tween_property(label, "position:y", float_height, duration).as_relative()
	
	# 2. Desvanecer (aumentar transparencia)
	# Empezamos a desvanecer a mitad de camino para que se lea bien al principio
	tween.tween_property(label, "transparency", 1.0, duration * 0.5).set_delay(duration * 0.5)
	
	# 3. Destruir al terminar
	tween.chain().tween_callback(queue_free)
