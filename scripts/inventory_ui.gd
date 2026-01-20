extends Control

@export var player_inventory: InventoryComponent # Lo asignaremos desde el Player o Main
@export var slot_scene: PackedScene

@onready var grid = $Panel/MarginContainer/GridContainer

var ui_slots: Array[InventoryUISlot] = []

func _ready():
	# Si ya tenemos la referencia al inventario, conectamos
	if player_inventory:
		setup_inventory(player_inventory)

func setup_inventory(inventory: InventoryComponent):
	player_inventory = inventory
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
		# CONECTAR SEÑAL DE CLICK
		new_slot.slot_clicked.connect(_on_slot_clicked)

func _on_slot_clicked(index: int, button: int):
	# Si es click derecho (MOUSE_BUTTON_RIGHT), usamos el ítem
	if button == MOUSE_BUTTON_RIGHT:
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
