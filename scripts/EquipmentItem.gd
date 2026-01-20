extends ItemData
class_name EquipmentItem

enum EquipmentSlot { WEAPON, HEAD, BODY, ACCESSORY }

@export_group("Stats de Equipo")
@export var slot: EquipmentSlot = EquipmentSlot.WEAPON
@export var atk_bonus: int = 0
@export var def_bonus: int = 0
@export var str_bonus: int = 0
@export var vit_bonus: int = 0
# ... agrega los stats que necesites

func _init():
	item_type = ItemType.EQUIPMENT
	stackable = false # El equipo generalmente no se stackea en RPGs tipo RO
