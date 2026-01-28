extends Node
class_name InventoryComponent

signal inventory_changed # Para avisar a la UI
signal zeny_changed(current_zeny)
signal transaction_failed(reason: String) # Útil para feedback de UI

@export var max_slots: int = 20
@export var zeny: int = 0

# Aquí guardamos los objetos reales (InventorySlots)
var slots: Array[InventorySlot] = []

func _ready():
	# Inicializar slots vacíos o predefinidos
	call_deferred("emit_signal", "zeny_changed", zeny)
	slots.resize(max_slots)

# --- SISTEMA DE ZENY ---

func add_zeny(amount: int):
	zeny += abs(amount)
	zeny_changed.emit(zeny)

func remove_zeny(amount: int) -> bool:
	amount = abs(amount)
	if zeny >= amount:
		zeny -= amount
		zeny_changed.emit(zeny)
		return true
	else:
		transaction_failed.emit("No tienes suficiente Zeny.")
		return false

func has_zeny(amount: int) -> bool:
	return zeny >= abs(amount)

# --- LÓGICA DE VENTA (Simplificada) ---

func sell_item(item: ItemData, quantity: int = 1):
	if has_item(item, quantity):
		var total_value = item.sell_price * quantity
		
		# 1. Quitar item
		remove_item(item, quantity)
		
		# 2. Dar dinero
		add_zeny(total_value)
		
		get_tree().call_group("hud", "add_log_message", "Vendiste %s x%d por %d Z" % [item.item_name, quantity, total_value], Color.GOLD)
	else:
		transaction_failed.emit("No tienes el item para vender.")
	
# Función principal para recoger objetos
func add_item(item: ItemData, amount: int = 1) -> bool:

	# CASO 1: El item es STACKABLE (Pociones, Loot)
	if item.stackable:
		# Buscamos si ya existe un slot con este item
		for slot in slots:
			if slot and slot.item_data == item:
				if slot.quantity < item.max_stack_size:
					slot.quantity += amount
					inventory_changed.emit()
					return true # Añadido al stack existente
		
	# CASO 2: No existe stack previo o no es stackeable (Equipo)
	# Buscamos el primer hueco vacío
	for i in range(slots.size()):
		if slots[i] == null:
			slots[i] = InventorySlot.new(item, amount)
			inventory_changed.emit()
			return true
			
	print("Inventario lleno!")
	return false

# Función para usar un item desde el índice del inventario
func use_item_at_index(index: int, user: Node) -> void:
	if index < 0 or index >= slots.size() or slots[index] == null:
		return
		
	var slot = slots[index]
	var item = slot.item_data
	
	# CASO ESPECIAL: Item de Equipamiento
	if item.item_type == ItemData.ItemType.EQUIPMENT:
		var equipment_comp = user.get_node_or_null("EquipmentComponent")
		if equipment_comp:
			# IMPORTANTE: Primero removemos del inventario, luego equipamos
			# Esto asegura que si hay swap, el item viejo tenga espacio
			slots[index] = null # Remover del inventario
			inventory_changed.emit()
			
			# Equipar (si hay algo en ese slot, EquipmentComponent lo devolverá al inventario)
			equipment_comp.equip_item(item)
		return
	
	# CASO NORMAL: Consumibles y otros
	# Intentamos usar el item
	if item.use(user):
		# Si se usó con éxito y es consumible, restamos cantidad
		if item.item_type == ItemData.ItemType.CONSUMABLE:
			slot.quantity -= 1
			if slot.quantity <= 0:
				slots[index] = null # Eliminar slot si llega a 0
			inventory_changed.emit()

func has_item(item_data: ItemData, amount: int = 1) -> bool:
	# Devuelve true si la cantidad total del item en el inventario
	# es mayor o igual a 'amount'. Por defecto, verifica existencia (>=1).
	return get_item_amount(item_data) >= abs(amount)

func get_item_amount(item_data: ItemData) -> int:
	var total = 0
	for slot in slots:
		if slot and slot.item_data == item_data:
			total += slot.quantity
	return total

# Remueve hasta 'quantity' unidades del item. Devuelve true si pudo
# remover la cantidad solicitada completa, false si faltó inventario.
func remove_item(item_data: ItemData, quantity: int = 1) -> bool:
	quantity = abs(quantity)
	var remaining = quantity
	var changed = false
	for i in range(slots.size()):
		var slot = slots[i]
		if slot == null:
			continue
		if slot.item_data != item_data:
			continue
		if slot.quantity > remaining:
			slot.quantity -= remaining
			remaining = 0
			changed = true
			break
		elif slot.quantity == remaining:
			slots[i] = null
			remaining = 0
			changed = true
			break
		else:
			# slot.quantity < remaining
			remaining -= slot.quantity
			slots[i] = null
			changed = true

	if changed:
		inventory_changed.emit()

	return remaining == 0
	
# Mueve un item de un índice a otro. Si el destino tiene algo, los intercambia.
func swap_items(from_index: int, to_index: int):
	# Validar rangos
	if from_index < 0 or from_index >= slots.size() or to_index < 0 or to_index >= slots.size():
		return
	
	if from_index == to_index:
		return

	# Intercambio simple en el array
	var temp = slots[to_index]
	slots[to_index] = slots[from_index]
	slots[from_index] = temp
	
	# Avisamos a la UI que hubo cambios
	inventory_changed.emit()
