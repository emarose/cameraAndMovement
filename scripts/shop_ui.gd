extends Control

# Referencia al inventario del jugador
var player_inventory: InventoryComponent

# Referencia al contenedor de la lista visual
@onready var sell_list_container = $Panel/VBoxContainer/TabContainer/Vender/VBoxContainer/ScrollContainer/SellListContainer
@onready var buy_list_container = $Panel/VBoxContainer/TabContainer/Comprar/VBoxContainer/ScrollContainer/BuyListContainer
@onready var close_button = $Panel/VBoxContainer/HBoxContainer/CloseButton
@onready var tab_container = $Panel/VBoxContainer/TabContainer

func _ready():
	if close_button:
		close_button.pressed.connect(close_shop)
	self.visible = false
	
func open_shop(inventory: InventoryComponent):
	self.visible = true
	player_inventory = inventory
	
	# 1. Abrimos también el Inventario del jugador (asumiendo que está en el HUD)
	get_tree().call_group("hud", "open_inventory_window") 
	
	# 2. Llenamos la lista de ventas
	refresh_sell_list()

func close_shop():
	self.visible = false
	player_inventory = null
	# Opcional: Cerrar inventario al cerrar tienda
	# get_tree().call_group("hud", "close_inventory_window")

func refresh_sell_list():
	# 1. Limpiar lista actual
	for child in sell_list_container.get_children():
		child.queue_free()
	
	# 2. Llenar con items vendibles del inventario
	# Iteramos los slots del inventario
	for i in range(player_inventory.slots.size()):
		var slot = player_inventory.slots[i]
		if slot == null:
			continue
		
		var item = slot.item_data
		if item.sell_price <= 0:
			continue # No mostramos items de quest/invendibles
		
		# Crear botón dinámico para vender este item
		var sell_button = Button.new()
		sell_button.text = "Vender %s - %dZ" % [item.item_name, item.sell_price]
		sell_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sell_list_container.add_child(sell_button)
		
		# Conectar click del botón para vender
		sell_button.pressed.connect(_on_item_sell_pressed.bind(item))

func _on_item_sell_pressed(item: ItemData):
	# Vender 1 unidad
	if player_inventory:
		player_inventory.sell_item(item, 1)
		refresh_sell_list() # Refrescar para ver si se acabó el stack
