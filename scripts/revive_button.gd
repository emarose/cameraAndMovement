extends Button

func _pressed():
	# Recargar la escena actual para reiniciar el juego
	get_tree().reload_current_scene()
