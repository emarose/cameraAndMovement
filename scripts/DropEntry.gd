extends Resource
class_name DropEntry

## Entrada de la tabla de drops para un enemigo
## Define qué item cae, con qué probabilidad y en qué cantidad

@export var item_data: ItemData
@export var drop_chance: float = 0.5  # 0.0 a 1.0 (50% = 0.5)
@export var min_quantity: int = 1
@export var max_quantity: int = 1

func _init(p_item: ItemData = null, p_chance: float = 0.5, p_min: int = 1, p_max: int = 1):
	item_data = p_item
	drop_chance = clamp(p_chance, 0.0, 1.0)
	min_quantity = max(1, p_min)
	max_quantity = max(min_quantity, p_max)

## Calcula si este drop debe ocurrir
func should_drop() -> bool:
	return randf() < drop_chance

## Devuelve la cantidad de items a dropear
func get_drop_quantity() -> int:
	if min_quantity == max_quantity:
		return min_quantity
	return randi_range(min_quantity, max_quantity)
