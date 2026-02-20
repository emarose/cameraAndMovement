extends Control

var _player: Node
var item_drop_scene: PackedScene = preload("res://scenes/ItemDrop.tscn")

func _ready():
	# Obtener referencia al jugador
	_player = get_tree().get_first_node_in_group("player")

func _can_drop_data(_pos, data):
	# Aceptar solo datos del inventario
	return typeof(data) == TYPE_DICTIONARY and data.has("source") and data["source"] == "inventory"

func _drop_data(_pos, data):
	if not _player or not _player.has_node("InventoryComponent"):
		return
	
	var inventory = _player.get_node("InventoryComponent")
	var item_data = data.get("item")
	var slot_index = data.get("origin_index", -1)
	
	if not item_data or slot_index < 0 or slot_index >= inventory.slots.size():
		return
	
	# Obtener la cantidad del item
	var slot = inventory.slots[slot_index]
	var quantity = 1
	if slot and slot.item_data == item_data:
		quantity = slot.quantity
	print(slot.item_data)
	# Remover del inventario
	inventory.slots[slot_index] = null
	inventory.inventory_changed.emit()
	
	# Dropear el item al suelo en la posición del jugador
	var drop_position = _player.global_position + Vector3(0, 0.5, 0)
	_drop_item_to_ground(item_data, quantity, drop_position)
	
	# Mensaje de feedback
	get_tree().call_group("hud", "add_log_message", 
		"Has descartado %s" % item_data.item_name, 
		Color.LIGHT_CORAL)

func _drop_item_to_ground(item_data: ItemData, quantity: int, pos: Vector3):
	if not item_drop_scene:
		push_error("ItemDrop scene not found!")
		return
	
	var drop_instance = item_drop_scene.instantiate()
	get_tree().current_scene.add_child(drop_instance)
	drop_instance.global_position = pos

	var has_model = false
	# Instanciar el modelo 3D del ítem
	if item_data.model:
		var model_instance = item_data.model.instantiate()
		drop_instance.add_child(model_instance)
		has_model = true

	# Si hay modelo, ocultar el Sprite3D (icono)
	if has_model and drop_instance.has_node("Sprite3D"):
		drop_instance.get_node("Sprite3D").visible = false

	drop_instance.setup(item_data, quantity, 1.5)
