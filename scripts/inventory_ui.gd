extends Control

@export var player_inventory: InventoryComponent # Lo asignaremos desde el Player o Main
@export var slot_scene: PackedScene

@onready var grid = $Panel/MarginContainer/GridContainer
@onready var tooltip = $Tooltip
@onready var tooltip_name = $Tooltip/VBox/NameLabel
@onready var tooltip_desc = $Tooltip/VBox/DescLabel
@onready var panel = $Panel
@onready var close_button = $Panel/TitleBar/CloseButton

var ui_slots: Array[InventoryUISlot] = []
var equipment_component: EquipmentComponent = null
var _dragging = false
var _drag_offset = Vector2.ZERO

func _ready():
	tooltip.visible = false
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	# Si ya tenemos la referencia al inventario, conectamos
	if player_inventory:
		setup_inventory(player_inventory)

func setup_inventory(inventory: InventoryComponent):
	player_inventory = inventory
	# Obtener equipment_component del padre
	var parent = inventory.get_parent()
	if parent:
		equipment_component = parent.get_node_or_null("EquipmentComponent")
	# Conectamos la señal que creamos en el paso anterior
	player_inventory.inventory_changed.connect(_on_inventory_changed)
	
	# Inicializar la grilla visual (crear los slots vacíos)
	_initialize_grid()
	update_grid() # Primera actualización

func _initialize_grid():
	for child in grid.get_children():
		child.queue_free()
	ui_slots.clear()
	
	for i in range(player_inventory.max_slots):
		var new_slot = slot_scene.instantiate()
		grid.add_child(new_slot)
		ui_slots.append(new_slot)
		# Asignar índice y referencia al padre
		new_slot.slot_index = i
		new_slot.parent_inventory_ui = self
		# CONECTAR SEÑAL DE CLICK
		new_slot.slot_clicked.connect(_on_slot_clicked)
		# CONECTAR SEÑALES DE HOVER
		new_slot.slot_hover.connect(_on_slot_hover)
		new_slot.slot_exit.connect(_on_slot_exit)

func _on_slot_clicked(index: int, button: int):
	# Si es click derecho (MOUSE_BUTTON_RIGHT), usamos el ítem
	if button == MOUSE_BUTTON_RIGHT:
		# Bloquear si la tienda está abierta
		var shop_ui = get_tree().get_first_node_in_group("shop_ui")
		if shop_ui and shop_ui.visible:
			return
		
		var player = get_tree().get_first_node_in_group("player")
		player_inventory.use_item_at_index(index, player)
		
func update_grid():
	# Sincronizar datos visuales con los datos lógicos
	for i in range(player_inventory.slots.size()):
		if i < ui_slots.size():
			ui_slots[i].update_slot(player_inventory.slots[i])

func _on_inventory_changed():
	# Esta función se llama cuando el inventario cambia
	# Actualizar la grilla visual
	update_grid()
	
	# Opcional: Reproducir un sonido de recolección/cambio
	# audio_player.play_sound("inventory_change")
	
	# Opcional: Mostrar animación o feedback visual
	# TODO: Agregar efecto visual cuando items se añaden/remuevan

# Función para el botón cerrar (si le pones uno)
func _on_close_button_pressed():
	visible = false

func _on_slot_hover(slot_data: InventorySlot):
	if slot_data and slot_data.item_data:
		tooltip_name.text = slot_data.item_data.item_name
		tooltip_desc.text = slot_data.item_data.description
		tooltip.visible = true

func _on_slot_exit():
	tooltip.visible = false

func _process(_delta):
	if tooltip.visible:
		tooltip.global_position = get_global_mouse_position() + Vector2(10, 10)
	
	if _dragging:
		panel.global_position = get_global_mouse_position() - _drag_offset

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var local_pos = event.position
				if local_pos.y <= 36:
					_dragging = true
					_drag_offset = get_global_mouse_position() - panel.global_position
			else:
				_dragging = false

# Llamado cuando se suelta un item sobre otro slot
func on_item_dropped(from_index: int, to_index: int):
	if player_inventory:
		player_inventory.swap_items(from_index, to_index)

# Llamado cuando se arrastra un item desde el equipo al inventario
func on_item_from_equipment(_item: EquipmentItem, slot_type: EquipmentItem.EquipmentSlot, target_slot_index: int = -1):
	if not equipment_component or not player_inventory:
		return
	
	var old_item = equipment_component.get_equipped_item(slot_type)
	# Remover del equipamiento
	equipment_component.equipped_items[slot_type] = null
	
	# Añadir al inventario en el slot específico si es válido y está vacío
	if target_slot_index >= 0 and target_slot_index < player_inventory.max_slots:
		if player_inventory.slots[target_slot_index] == null:
			# Slot destino vacío: añadir ahí
			player_inventory.slots[target_slot_index] = InventorySlot.new(old_item, 1)
		else:
			# Slot destino ocupado: buscar primer slot vacío
			if not player_inventory.add_item(old_item, 1):
				return
	else:
		# Sin slot específico: buscar primer slot vacío
		if not player_inventory.add_item(old_item, 1):
			return
	
	equipment_component._recalculate_equipment_bonuses()
	equipment_component.equipment_changed.emit()
	player_inventory.inventory_changed.emit()
