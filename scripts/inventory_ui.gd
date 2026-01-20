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
	player_inventory.inventory_changed.connect(update_grid)
	
	# Inicializar la grilla visual (crear los slots vacíos)
	_initialize_grid()
	update_grid() # Primera actualización

func _initialize_grid():
	# Limpiar por si acaso
	for child in grid.get_children():
		child.queue_free()
	ui_slots.clear()
	
	# Crear tantos slots visuales como slots lógicos tenga el componente
	for i in range(player_inventory.max_slots):
		var new_slot = slot_scene.instantiate()
		grid.add_child(new_slot)
		ui_slots.append(new_slot)

func update_grid():
	# Sincronizar datos visuales con los datos lógicos
	for i in range(player_inventory.slots.size()):
		if i < ui_slots.size():
			ui_slots[i].update_slot(player_inventory.slots[i])

# Función para el botón cerrar (si le pones uno)
func _on_close_button_pressed():
	visible = false
