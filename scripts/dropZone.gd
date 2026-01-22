extends Control

func _can_drop_data(_pos, data):
	return data.has("source") and data["source"] == "inventory"

func _drop_data(_pos, data):
	print("¡Item soltado fuera de la UI!")
	# Aquí abres tu panel de confirmación:
	# ConfirmationPanel.show_confirm("¿Tirar " + data["item"].name + "?", func(): delete_item(data))
