extends ItemData
class_name EquipmentItem

enum EquipmentSlot { WEAPON, HEAD, BODY, ACCESSORY }
enum WeaponAttachment { RIGHT_HAND, LEFT_HAND, LEFT_ARM, HEAD }

@export_group("Stats de Equipo")
@export var slot: EquipmentSlot = EquipmentSlot.WEAPON
@export var atk_bonus: int = 0
@export var def_bonus: int = 0
@export var str_bonus: int = 0
@export var vit_bonus: int = 0
@export var is_ranged: bool = false
@export var attack_range: float = 1.5
@export var projectile_scene: PackedScene

@export_group("Visual")
@export var weapon_attachment: WeaponAttachment = WeaponAttachment.RIGHT_HAND

@export_group("Animaciones de Combate")
## Recurso de animación para idle (opcional)
@export var idle_animation_resource: Animation

## Recurso de animación para inicio de ataque (opcional)
@export var attack_start_animation_resource: Animation

## Recurso de animación para liberación del ataque (opcional)
@export var attack_release_animation_resource: Animation

func _init():
	item_type = ItemType.EQUIPMENT
	stackable = false # El equipo generalmente no se stackea en RPGs tipo RO
