extends PanelContainer
class_name EquipmentSlotUI

@export var slot_type: EquipmentItem.EquipmentSlot = EquipmentItem.EquipmentSlot.WEAPON

@onready var icon: TextureRect = $Icon
var current_item: EquipmentItem = null

func set_slot_type(new_type: EquipmentItem.EquipmentSlot):
	slot_type = new_type

func set_item(item: EquipmentItem) -> void:
	# Solo acepta equipo y que coincida con el slot
	if item and item.item_type == ItemData.ItemType.EQUIPMENT and item.slot == slot_type:
		current_item = item
		icon.texture = item.icon
		icon.modulate = Color.WHITE
	else:
		current_item = null
		icon.texture = null
		icon.modulate = Color(1, 1, 1, 0.3)

func get_drag_data(_pos):
	if current_item:
		return current_item
	return null
