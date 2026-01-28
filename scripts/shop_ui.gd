extends Control

# Referencia al inventario del jugador
var player_inventory: InventoryComponent

# Referencia al contenedor de la lista visual
@onready var sell_list_container = $Panel/VBoxContainer/TabContainer/Vender/VBoxContainer/ScrollContainer/SellListContainer
@onready var buy_list_container = $Panel/VBoxContainer/TabContainer/Comprar/VBoxContainer/ScrollContainer/BuyListContainer
@onready var close_button = $Panel/VBoxContainer/HBoxContainer/CloseButton
@onready var tab_container = $Panel/VBoxContainer/TabContainer
@export var shop_slot_prefab: PackedScene
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
	for child in sell_list_container.get_children():
		child.queue_free()
	
	for i in range(player_inventory.slots.size()):
		var slot_data = player_inventory.slots[i] # Ojo con el nombre para no confundir con la UI
		if slot_data == null: continue
		
		var item = slot_data.item_data
		if item.sell_price <= 0: continue
		
		# USANDO EL PREFAB
		var ui_slot = shop_slot_prefab.instantiate()
		sell_list_container.add_child(ui_slot)
		
		# Configuramos visualmente
		ui_slot.set_data(item, false) # false = estamos vendiendo
		
		# Conectamos señal
		ui_slot.pressed.connect(_on_item_sell_pressed.bind(item))
		
func _on_item_sell_pressed(item: ItemData):
	# Vender 1 unidad
	if player_inventory:
		player_inventory.sell_item(item, 1)
		refresh_sell_list() # Refrescar para ver si se acabó el stack
