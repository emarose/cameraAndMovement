extends Control

# Referencia al inventario del jugador
var player_inventory: InventoryComponent
var current_shop_items: Array[ItemData] = []

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
	
	# Asegurar que la UI bloquee eventos del mouse
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent):
	# Consumir eventos de scroll cuando el mouse está sobre la UI
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			accept_event()  # Consumir el evento aquí para que no llegue a la cámara


func open_shop(inventory: InventoryComponent, shop_items: Array[ItemData]):
	self.visible = true
	player_inventory = inventory
	current_shop_items = shop_items
	
	# Abrir también el inventario del jugador
	get_tree().call_group("hud", "open_inventory_window")
	
	# Llenar ambas listas
	refresh_buy_list()
	refresh_sell_list()
	
func refresh_buy_list():
	# 1. Limpiar
	for child in buy_list_container.get_children():
		child.queue_free()
		
	# 2. Llenar con la lista que nos pasó el NPC
	for item in current_shop_items:
		if item == null: continue
		var ui_slot = shop_slot_prefab.instantiate()
		buy_list_container.add_child(ui_slot)
		
		ui_slot.set_data(item, true) # true = estamos comprando
		
		# Conectar señal de compra
		ui_slot.pressed.connect(_on_item_buy_pressed.bind(item))

func _on_item_buy_pressed(item: ItemData):
	if not player_inventory: return
	
	# 1. Verificar si tiene dinero
	# (buy_price debe estar en ItemData, si no usa sell_price * 2)
	var price = item.buy_price 
	
	if player_inventory.has_zeny(price):
		# 2. Verificar si cabe en inventario (opcional pero recomendado)
		# if player_inventory.can_add_item(item): ...
		
		# 3. Transacción
		player_inventory.remove_zeny(price)
		player_inventory.add_item(item, 1) # Añadir 1 unidad
		
		get_tree().call_group("hud", "add_log_message", "Compraste %s" % item.item_name, Color.WHITE)
	else:
		get_tree().call_group("hud", "add_log_message", "No tienes suficiente Zeny", Color.RED)

func close_shop():
	self.visible = false
	player_inventory = null
	get_tree().call_group("hud", "close_inventory_window")

func refresh_sell_list():
	for child in sell_list_container.get_children():
		child.queue_free()
	
	for i in range(player_inventory.slots.size()):
		var slot_data = player_inventory.slots[i]
		if slot_data == null: continue
		
		var item = slot_data.item_data
		
		# Skip items with no sell value
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
