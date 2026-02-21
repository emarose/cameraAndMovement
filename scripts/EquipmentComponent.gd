extends Node
class_name EquipmentComponent

## Gestiona los slots de equipamiento del jugador/personaje
## y calcula los bonos totales aplicados por el equipo

signal equipment_changed # Para avisar a la UI

# Diccionario que mapea cada slot a un item equipado (o null)
var equipped_items: Dictionary = {
	EquipmentItem.EquipmentSlot.WEAPON: null,
	EquipmentItem.EquipmentSlot.HEAD: null,
	EquipmentItem.EquipmentSlot.BODY: null,
	EquipmentItem.EquipmentSlot.ACCESSORY: null
}

# Diccionario de referencias a los attachment points del esqueleto
var bone_attachments: Dictionary = {}

# Referencias a otros componentes del jugador
var stats_component: StatsComponent = null
var inventory_component: InventoryComponent = null
var parent_entity: Node3D = null

func _ready():
	# Buscamos los componentes hermanos
	parent_entity = get_parent()
	if parent_entity:
		stats_component = parent_entity.get_node_or_null("StatsComponent")
		inventory_component = parent_entity.get_node_or_null("InventoryComponent")
		_initialize_bone_attachments()

## Equipar un ítem desde el inventario
func equip_item(item: EquipmentItem) -> bool:
	if not item or item.item_type != ItemData.ItemType.EQUIPMENT:
		return false
	
	var slot_type = item.slot
	
	# Si ya hay algo equipado en ese slot, lo guardamos para intercambio
	var old_item = equipped_items[slot_type]

	# Limpiar el modelo visual anterior (puede estar en otro attachment)
	if old_item:
		_clear_equipment_visuals(slot_type, old_item)
	
	# Equipamos el nuevo item
	equipped_items[slot_type] = item
	
	# Si había un item viejo, lo devolvemos al inventario
	if old_item and inventory_component:
		inventory_component.add_item(old_item, 1)
	
	# Recalculamos stats (incluyendo limpiar bonos previos y aplicar nuevos)
	_recalculate_equipment_bonuses()
	equipment_changed.emit()
	
	# Actualizar el modelo visual del equipo
	_update_equipment_visuals(item, slot_type)

	return true

## Desequipar un ítem de un slot específico
func unequip_slot(slot_type: EquipmentItem.EquipmentSlot) -> bool:
	var item = equipped_items[slot_type]
	
	if not item:
		return false
	
	# Verificar si hay espacio en el inventario
	if inventory_component and not inventory_component.add_item(item, 1):
		return false
	
	# Remover del slot
	equipped_items[slot_type] = null
	
	# Limpiar el modelo visual del equipo
	_clear_equipment_visuals(slot_type, item)
	
	# Recalcular stats (esto limpiará todos los bonos y los recalculará)
	_recalculate_equipment_bonuses()
	equipment_changed.emit()
	
	return true

## Obtener el item equipado en un slot específico
func get_equipped_item(slot_type: EquipmentItem.EquipmentSlot) -> EquipmentItem:
	return equipped_items[slot_type]

## Recalcula y aplica todos los bonos del equipamiento a StatsComponent
func _recalculate_equipment_bonuses():
	if not stats_component:
		return
	
	# Resetear bonos de equipo (diccionarios)
	var total_atk_bonus = 0
	var total_def_bonus = 0
	var total_str_bonus = 0
	var total_vit_bonus = 0
	
	# También limpiar los bonos de raza/elemento antes de recalcular
	stats_component.clear_equipment_bonuses()
	
	# Sumar bonos de cada item equipado
	for slot_type in equipped_items:
		var item: EquipmentItem = equipped_items[slot_type]
		if item:
			total_atk_bonus += item.atk_bonus
			total_def_bonus += item.def_bonus
			total_str_bonus += item.str_bonus
			total_vit_bonus += item.vit_bonus
			
			# Aplicar bono de raza si existe
			if item.race_bonus_value > 0:
				stats_component.apply_equipment_race_bonus(item.race_bonus, item.race_bonus_value)
			
			# Aplicar bono de elemento si existe
			if item.element_bonus_value > 0:
				stats_component.apply_equipment_element_bonus(item.element_bonus, item.element_bonus_value)
			
			# Aplicar elemento del arma (último arma equipada)
			if slot_type == EquipmentItem.EquipmentSlot.WEAPON:
				stats_component.weapon_element = item.weapon_element
	
	# Aplicar los bonos de stats al StatsComponent
	if stats_component.has_method("set_equipment_bonuses"):
		var bonuses = {
		"atk": total_atk_bonus,
		"def": total_def_bonus,
		"str": total_str_bonus,
		"vit": total_vit_bonus
		}
		stats_component.set_equipment_bonuses(bonuses)

## Obtener resumen de stats totales del equipo
func get_total_equipment_stats() -> Dictionary:
	var totals = {
		"atk": 0,
		"def": 0,
		"str": 0,
		"vit": 0
	}
	
	for slot_type in equipped_items:
		var item: EquipmentItem = equipped_items[slot_type]
		if item:
			totals["atk"] += item.atk_bonus
			totals["def"] += item.def_bonus
			totals["str"] += item.str_bonus
			totals["vit"] += item.vit_bonus
	
	return totals

## Inicializa referencias a los attachment points del esqueleto
func _initialize_bone_attachments():
	# Buscar el modelo del personaje (primera opción: Mannequin_Medium)
	var model = parent_entity.get_node_or_null("Mannequin_Medium")
	if not model:
		# Intentar encontrar cualquier modelo con AnimationTree
		for child in parent_entity.get_children():
			if child is Node3D and child.has_node("AnimationTree"):
				model = child
				break
	
	if not model:
		push_error("EquipmentComponent: Cannot find character model")
		return
	
	# Buscar el skeleton con los attachment points
	var skeleton_path: String = "Rig_Medium/Skeleton3D"
	var skeleton = model.get_node_or_null(skeleton_path)
	
	if not skeleton:
		push_error("EquipmentComponent: Cannot find skeleton at path: ", skeleton_path)
		return
	
	# Mapear los attachment points disponibles
	var attachment_names = ["RightHand", "LeftHand", "LeftArm", "Head"]
	for attachment_name in attachment_names:
		var attachment = skeleton.get_node_or_null(attachment_name)
		if attachment:
			var position_node = attachment.get_node_or_null("position")
			bone_attachments[attachment_name] = position_node if position_node else attachment

func _update_equipment_visuals(item: EquipmentItem, slot_type: EquipmentItem.EquipmentSlot) -> void:
	"""Instancia y posiciona el modelo visual del equipo"""
	var model_scene = item.model
	if not model_scene:
		return
	
	# Determinar el attachment point según el slot y el item
	var attachment_key: String = _get_attachment_for_slot(slot_type, item)
	if not attachment_key or not bone_attachments.has(attachment_key):
		push_warning("EquipmentComponent: No attachment found for slot ", slot_type)
		return
	
	var attachment = bone_attachments[attachment_key]
	
	# Limpiar modelos anteriores
	for child in attachment.get_children():
		child.queue_free()
	
	# Instanciar y añadir el nuevo modelo
	var model_instance = model_scene.instantiate()
	attachment.add_child(model_instance)

func _clear_equipment_visuals(slot_type: EquipmentItem.EquipmentSlot, item: EquipmentItem = null) -> void:
	"""Remueve el modelo visual del equipo"""
	var attachment_key: String = _get_attachment_for_slot(slot_type, item)
	if not attachment_key or not bone_attachments.has(attachment_key):
		return
	
	var attachment = bone_attachments[attachment_key]
	for child in attachment.get_children():
		child.queue_free()

func _get_attachment_for_slot(slot_type: EquipmentItem.EquipmentSlot, item: EquipmentItem = null) -> String:
	"""Retorna el nombre del attachment point para un slot de equipo"""
	match slot_type:
		EquipmentItem.EquipmentSlot.WEAPON:
			if item:
				match item.weapon_attachment:
					EquipmentItem.WeaponAttachment.LEFT_HAND:
						return "LeftHand"
					EquipmentItem.WeaponAttachment.LEFT_ARM:
						return "LeftArm"
					EquipmentItem.WeaponAttachment.HEAD:
						return "Head"
					_:
						return "RightHand"
			return "RightHand"
		EquipmentItem.EquipmentSlot.HEAD:
			return "Head"
		EquipmentItem.EquipmentSlot.BODY:
			return "Skeleton3D" # Body is handled differently
		EquipmentItem.EquipmentSlot.ACCESSORY:
			return "LeftHand" # Or a custom attachment
		_:
			return ""
