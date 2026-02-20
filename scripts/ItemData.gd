extends Resource
class_name ItemData

enum ItemType { CONSUMABLE, EQUIPMENT, MISC, QUEST }

@export_group("Datos Generales")
@export var item_name: String = "Item"
@export var icon: Texture2D
@export var model: PackedScene
@export var description: String = ""
@export var item_type: ItemType = ItemType.MISC
@export var stackable: bool = true
@export var max_stack_size: int = 99
@export var sell_price: int = 10
@export var buy_price: int = 20
@export var weapon_element: StatsComponent.Element = StatsComponent.Element.NEUTRAL
# Para las cartas o bonos específicos, podrías usar un array de recursos o un diccionario
@export var race_bonus: StatsComponent.Race
@export var race_bonus_value: float = 0.0 # 0.2 para 20%
@export var element_bonus: StatsComponent.Element = StatsComponent.Element.NEUTRAL
@export var element_bonus_value: float = 0.0 # 0.2 para 20%

# Función base virtual (se sobrescribe en los hijos)
func use(_user: Node, _target = null) -> bool:
	print("Este item no tiene uso definido.")
	return false
