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
			print("Item añadido en slot %d: %s x%d" % [i, item.item_name, amount])
			return true
			
	print("Inventario lleno!")
	return false

# Función para usar un item desde el índice del inventario
func use_item_at_index(index: int, user: Node) -> void:
	if index < 0 or index >= slots.size() or slots[index] == null:
		return
		
	var slot = slots[index]
	var item = slot.item_data
	
	# Intentamos usar el item
	if item.use(user):
		# Si se usó con éxito y es consumible, restamos cantidad
		if item.item_type == ItemData.ItemType.CONSUMABLE:
			slot.quantity -= 1
			if slot.quantity <= 0:
				slots[index] = null # Eliminar slot si llega a 0
			inventory_changed.emit()
