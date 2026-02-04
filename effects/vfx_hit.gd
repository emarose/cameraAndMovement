extends GPUParticles3D

func _ready():
	emitting = true # Asegura que empiece al instanciarse
	finished.connect(_on_finished)

func _on_finished():
	queue_free() # Se borra a sí mismo de la memoria
