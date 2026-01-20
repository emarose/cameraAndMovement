extends Control
class_name InventoryUISlot
signal slot_clicked(index: int, button: int)
@onready var icon_rect = $Icon
@onready var amount_label = $AmountLabel

# Guardamos referencia al dato para tooltips o clics futuros
var my_slot_data: InventorySlot

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		# Detectamos click izquierdo o derecho
		slot_clicked.emit(get_index(), event.button_index)

func update_slot(slot_data: InventorySlot):
	my_slot_data = slot_data
	
	if slot_data == null or slot_data.item_data == null:
		# Slot vacío
		icon_rect.texture = null
		icon_rect.visible = false
		amount_label.visible = false
		return
	
	# Slot ocupado
	icon_rect.visible = true
	icon_rect.texture = slot_data.item_data.icon
	
	# Manejo de cantidad
	if slot_data.quantity > 1:
		amount_label.visible = true
		amount_label.text = str(slot_data.quantity)
	else:
		amount_label.visible = false # No mostramos "1"
