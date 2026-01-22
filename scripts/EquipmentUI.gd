extends Control
class_name EquipmentUI

@export var player_path: NodePath
@onready var weapon_slot: EquipmentSlotUI = $Panel/Body/Slots/WeaponSlot
@onready var head_slot: EquipmentSlotUI = $Panel/Body/Slots/HeadSlot
@onready var body_slot: EquipmentSlotUI = $Panel/Body/Slots/BodySlot
@onready var accessory_slot: EquipmentSlotUI = $Panel/Body/Slots/AccessorySlot

var equipment_component: EquipmentComponent = null
var inventory_component: InventoryComponent = null

func _ready():
	_assign_slot_types()
	if player_path != NodePath():
		var p = get_node_or_null(player_path)
		if p:
			set_player(p)
	else:
		_refresh_slots()

func set_player(player: Node) -> void:
	equipment_component = player.get_node_or_null("EquipmentComponent")
	inventory_component = player.get_node_or_null("InventoryComponent")
	if equipment_component and not equipment_component.equipment_changed.is_connected(_refresh_slots):
		equipment_component.equipment_changed.connect(_refresh_slots)
	_refresh_slots()

func _assign_slot_types():
	if weapon_slot:
		weapon_slot.set_slot_type(EquipmentItem.EquipmentSlot.WEAPON)
	if head_slot:
		head_slot.set_slot_type(EquipmentItem.EquipmentSlot.HEAD)
	if body_slot:
		body_slot.set_slot_type(EquipmentItem.EquipmentSlot.BODY)
	if accessory_slot:
		accessory_slot.set_slot_type(EquipmentItem.EquipmentSlot.ACCESSORY)

func _refresh_slots():
	if not equipment_component:
		return
	weapon_slot.set_item(equipment_component.get_equipped_item(EquipmentItem.EquipmentSlot.WEAPON))
	head_slot.set_item(equipment_component.get_equipped_item(EquipmentItem.EquipmentSlot.HEAD))
	body_slot.set_item(equipment_component.get_equipped_item(EquipmentItem.EquipmentSlot.BODY))
	accessory_slot.set_item(equipment_component.get_equipped_item(EquipmentItem.EquipmentSlot.ACCESSORY))
