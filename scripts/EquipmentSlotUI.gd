extends PanelContainer
class_name EquipmentSlotUI

@export var slot_type: EquipmentItem.EquipmentSlot = EquipmentItem.EquipmentSlot.WEAPON

@onready var icon: TextureRect = $Icon
var current_item: EquipmentItem = null
var parent_equipment_ui = null
var slot_index: int = -1 # Índice en el diccionario de equipamiento

func set_slot_type(new_type: EquipmentItem.EquipmentSlot):
	slot_type = new_type
	slot_index = new_type # Usamos el enum como índice

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

# --- DRAG AND DROP NATIVO DE GODOT ---

# 1. Cuando el usuario intenta arrastrar este slot
func _get_drag_data(_pos):
	if current_item == null:
		return null
	
	# Crear la vista previa (icono fantasma)
	var preview_texture = TextureRect.new()
	preview_texture.texture = current_item.icon
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.custom_minimum_size = Vector2(40, 40)
	
	var preview_control = Control.new()
	preview_control.add_child(preview_texture)
	preview_texture.position = -0.5 * preview_texture.custom_minimum_size
	
	set_drag_preview(preview_control)
	
	# Retornar datos con source "equipment"
	var data = {
		"source": "equipment",
		"slot_type": slot_type,
		"item": current_item
	}
	return data

# 2. Cuando alguien arrastra algo POR ENCIMA de este slot
func _can_drop_data(_at_position, data):
	if typeof(data) == TYPE_DICTIONARY and data.has("source"):
		# Aceptar desde inventario (items de equipo)
		if data["source"] == "inventory":
			if data.has("item") and data["item"].item_type == ItemData.ItemType.EQUIPMENT:
				var item: EquipmentItem = data["item"]
				# Solo si el item va en este slot
				if item.slot == slot_type:
					return true
		# Aceptar intercambio entre slots de equipo
		elif data["source"] == "equipment":
			return true
	return false

# 3. Cuando sueltan el click SOBRE este slot
func _drop_data(_at_position, data):
	if not parent_equipment_ui:
		return
	
	if data["source"] == "inventory":
		# Viene del inventario: equipar el item
		var item = data["item"]
		var origin_index = data["origin_index"]
		parent_equipment_ui.on_item_from_inventory(item, slot_type, origin_index)
	elif data["source"] == "equipment":
		# Viene de otro slot de equipo: intercambiar
		var origin_slot = data["slot_type"]
		if origin_slot == slot_type:
			return # No hacer nada si es el mismo slot
		parent_equipment_ui.on_equipment_swapped(origin_slot, slot_type)

# Click derecho para desequipar
func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if current_item and parent_equipment_ui:
				parent_equipment_ui.on_unequip_clicked(slot_type)
