extends Node
class_name InventoryComponent

signal inventory_changed # Para avisar a la UI

@export var max_slots: int = 20
# Aquí guardamos los objetos reales (InventorySlots)
var slots: Array[InventorySlot] = []

func _ready():
	# Inicializar slots vacíos o predefinidos
	
	slots.resize(max_slots)

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

func has_item(item_data: ItemData) -> bool:
	for slot in slots:
		if slot and slot.item_data == item_data:
			return true
	return false

func get_item_amount(item_data: ItemData) -> int:
	var total = 0
	for slot in slots:
		if slot and slot.item_data == item_data:
			total += slot.quantity
	return total
	
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
