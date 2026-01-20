extends Resource
class_name InventorySlot

@export var item_data: ItemData
@export var quantity: int = 0

func _init(p_item = null, p_amount = 0):
	item_data = p_item
	quantity = p_amount
