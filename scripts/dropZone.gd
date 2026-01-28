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
	# Pasar delay de 1.5 segundos para items descartados (vs 0.2s para drops de enemigos)
	drop_instance.setup(item_data, quantity, 1.5)
