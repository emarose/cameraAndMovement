extends Node3D

@onready var label: Label3D = $Label3D

var float_height := 1.2
var duration := 1.0

func _ready():
	label.text = "LEVEL UP!"
	label.modulate = Color(1, 1, 1)
	label.scale = Vector3.ONE * 0.8
	label.transparency = 0.0
	
	animate_and_destroy()

func animate_and_destroy():
	var tween = create_tween().set_parallel(true)

	# Subir
	tween.tween_property(
		label,
		"position:y",
		float_height,
		duration
	).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Agrandar un poco
	tween.tween_property(
		label,
		"scale",
		Vector3.ONE,
		duration * 0.4
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Desvanecer al final
	tween.tween_property(
		label,
		"transparency",
		1.0,
		duration * 0.4
	).set_delay(duration * 0.6)

	tween.chain().tween_callback(queue_free)
