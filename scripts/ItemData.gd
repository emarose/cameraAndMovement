extends Resource
class_name ItemData

enum ItemType { CONSUMABLE, EQUIPMENT, MISC, QUEST }

@export_group("Datos Generales")
@export var item_name: String = "Item"
@export var icon: Texture2D
@export var description: String = ""
@export var item_type: ItemType = ItemType.MISC
@export var stackable: bool = true
@export var max_stack_size: int = 99
@export var sell_price: int = 10

# Función base virtual (se sobrescribe en los hijos)
func use(_user: Node, _target = null) -> bool:
	print("Este item no tiene uso definido.")
	return false
