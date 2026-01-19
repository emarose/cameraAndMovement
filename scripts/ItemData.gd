extends Resource
class_name ItemData

@export var item_name: String = "Item"
@export var icon: Texture2D
@export var stackable: bool = true
@export_multiline var description: String

# Qué hace el item al usarse (esto lo ampliaremos luego)
func use(_user: Node) -> void:
	print("Usando item: ", item_name)
