extends Control
class_name InventoryUISlot
signal slot_clicked(index: int, button: int)
signal slot_hover(slot_data: InventorySlot)
signal slot_exit()
@onready var icon_rect = $Icon
@onready var amount_label = $AmountLabel

# Guardamos referencia al dato para tooltips o clics futuros
var my_slot_data: InventorySlot
var slot_index: int = -1
var parent_inventory_ui = null

func _ready():
	mouse_entered.connect(_on_mouse_enter)
	mouse_exited.connect(_on_mouse_exit)

func _on_mouse_enter():
	if my_slot_data and my_slot_data.item_data:
		slot_hover.emit(my_slot_data)

func _on_mouse_exit():
	slot_exit.emit()

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		# Detectamos click izquierdo o derecho
		slot_clicked.emit(get_index(), event.button_index)

func update_slot(slot_data: InventorySlot):
	my_slot_data = slot_data
	
	if slot_data == null or slot_data.item_data == null:
		# Slot vacío
		icon_rect.texture = null
		# Mantener visible pero sin textura para recibir eventos de drag and drop
		icon_rect.modulate.a = 0.0 # Hacerlo transparente
		amount_label.visible = false
		return
	
	# Slot ocupado
	icon_rect.modulate.a = 1.0 # Restaurar opacidad
	icon_rect.texture = slot_data.item_data.icon
	
	# Manejo de cantidad
	if slot_data.quantity > 1:
		amount_label.visible = true
		amount_label.text = str(slot_data.quantity)
	else:
		amount_label.visible = false # No mostramos "1"

# --- DRAG AND DROP NATIVO DE GODOT ---

# 1. Cuando el usuario intenta arrastrar este slot
func _get_drag_data(at_position):
	if my_slot_data == null or my_slot_data.item_data == null:
		return null # No arrastrar si está vacío
	
	# A. Crear la vista previa (el icono fantasma que sigue al mouse)
	var preview_texture = TextureRect.new()
	preview_texture.texture = my_slot_data.item_data.icon
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.custom_minimum_size = Vector2(40, 40) # Tamaño del fantasma
	
	# El control debe estar en un nodo Control simple para que se centre bien
	var preview_control = Control.new()
	preview_control.add_child(preview_texture)
	preview_texture.position = -0.5 * preview_texture.custom_minimum_size # Centrar en mouse
	
	# Función nativa para asignar la vista previa
	set_drag_preview(preview_control)
	
	# B. Retornar los datos que "viajan" con el mouse
	# Enviamos un diccionario con todo lo necesario
	var data = {
		"source": "inventory", # Para saber de dónde viene (útil para equipo luego)
		"origin_index": slot_index,
		"item": my_slot_data.item_data
	}
	return data

# 2. Cuando alguien arrastra algo POR ENCIMA de este slot
func _can_drop_data(at_position, data):
	# Verificamos si los datos vienen de nuestro sistema de inventario
	if typeof(data) == TYPE_DICTIONARY and data.has("source"):
		if data["source"] == "inventory":
			return true
		# También aceptar desde equipo (para desequipar items)
		elif data["source"] == "equipment":
			return true
	return false

# 3. Cuando sueltan el click SOBRE este slot
func _drop_data(at_position, data):
	# Si viene del inventario
	if data["source"] == "inventory":
		var origin_index = data["origin_index"]
		
		# Si soltamos en el mismo slot, no hacemos nada
		if origin_index == slot_index:
			return
		
		# Intercambio entre slots del inventario
		if parent_inventory_ui:
			parent_inventory_ui.on_item_dropped(origin_index, slot_index)
	
	# Si viene del equipo
	elif data["source"] == "equipment":
		# Item desequipado: agregarlo al inventario en este slot
		var item = data["item"]
		var slot_type = data["slot_type"]
		if parent_inventory_ui:
			parent_inventory_ui.on_item_from_equipment(item, slot_type, slot_index)
