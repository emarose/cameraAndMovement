extends Node3D

@export var duration: float = 0.3
var elapsed: float = 0.0

func _process(delta):
	elapsed += delta
	if elapsed >= duration:
		queue_free()
