extends Control
class_name EquipmentUI

@export var player_path: NodePath
@onready var weapon_slot: EquipmentSlotUI = $Panel/Body/Slots/WeaponSlot
@onready var head_slot: EquipmentSlotUI = $Panel/Body/Slots/HeadSlot
@onready var body_slot: EquipmentSlotUI = $Panel/Body/Slots/BodySlot
@onready var accessory_slot: EquipmentSlotUI = $Panel/Body/Slots/AccessorySlot
@onready var panel = $Panel
@onready var close_button: Button = $Panel/CloseButton

var equipment_component: EquipmentComponent = null
var inventory_component: InventoryComponent = null
var _dragging = false
var _drag_offset = Vector2.ZERO

func _ready():
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
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
		weapon_slot.parent_equipment_ui = self
	if head_slot:
		head_slot.set_slot_type(EquipmentItem.EquipmentSlot.HEAD)
		head_slot.parent_equipment_ui = self
	if body_slot:
		body_slot.set_slot_type(EquipmentItem.EquipmentSlot.BODY)
		body_slot.parent_equipment_ui = self
	if accessory_slot:
		accessory_slot.set_slot_type(EquipmentItem.EquipmentSlot.ACCESSORY)
		accessory_slot.parent_equipment_ui = self

func _refresh_slots():
	if not equipment_component:
		return
	weapon_slot.set_item(equipment_component.get_equipped_item(EquipmentItem.EquipmentSlot.WEAPON))
	head_slot.set_item(equipment_component.get_equipped_item(EquipmentItem.EquipmentSlot.HEAD))
	body_slot.set_item(equipment_component.get_equipped_item(EquipmentItem.EquipmentSlot.BODY))
	accessory_slot.set_item(equipment_component.get_equipped_item(EquipmentItem.EquipmentSlot.ACCESSORY))

func _process(_delta):
	if _dragging:
		panel.global_position = get_global_mouse_position() - _drag_offset

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var local_pos = event.position
				if local_pos.y <= 36:
					_dragging = true
					_drag_offset = get_global_mouse_position() - panel.global_position
			else:
				_dragging = false

func _on_close_button_pressed():
	visible = false

# Llamado cuando se arrastra un item del inventario a un slot de equipo
func on_item_from_inventory(item: EquipmentItem, slot_type: EquipmentItem.EquipmentSlot, origin_index: int):
	if equipment_component and inventory_component:
		# Primero remover del inventario
		inventory_component.slots[origin_index] = null
		inventory_component.inventory_changed.emit()
		# Luego equipar (esto devolverá el item viejo al inventario si existe)
		equipment_component.equip_item(item)

# Llamado cuando se intercambian dos slots de equipo
func on_equipment_swapped(from_slot: EquipmentItem.EquipmentSlot, to_slot: EquipmentItem.EquipmentSlot):
	if not equipment_component or not inventory_component:
		return
	
	var from_item = equipment_component.get_equipped_item(from_slot)
	var to_item = equipment_component.get_equipped_item(to_slot)
	
	# Intercambiar items entre slots
	equipment_component.equipped_items[from_slot] = to_item
	equipment_component.equipped_items[to_slot] = from_item
	
	# Recalcular bonos y emitir señal
	equipment_component._recalculate_equipment_bonuses()
	equipment_component.equipment_changed.emit()

# Llamado cuando se hace click izquierdo para desequipar
func on_unequip_clicked(slot_type: EquipmentItem.EquipmentSlot):
	if equipment_component:
		equipment_component.unequip_slot(slot_type)
