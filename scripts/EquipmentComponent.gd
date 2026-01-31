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

# Referencias a otros componentes del jugador
var stats_component: StatsComponent = null
var inventory_component: InventoryComponent = null

func _ready():
	# Buscamos los componentes hermanos
	var parent = get_parent()
	if parent:
		stats_component = parent.get_node_or_null("StatsComponent")
		inventory_component = parent.get_node_or_null("InventoryComponent")

## Equipar un ítem desde el inventario
func equip_item(item: EquipmentItem) -> bool:
	if not item or item.item_type != ItemData.ItemType.EQUIPMENT:
		return false
	
	var slot_type = item.slot
	
	# Si ya hay algo equipado en ese slot, lo guardamos para intercambio
	var old_item = equipped_items[slot_type]
	
	# Equipamos el nuevo item
	equipped_items[slot_type] = item
	
	# Si había un item viejo, lo devolvemos al inventario
	if old_item and inventory_component:
		inventory_component.add_item(old_item, 1)
		
	# Agregar elemento
	stats_component.weapon_element = item.weapon_element
	
	# Bonus por raza
	if item.race_bonus_value > 0:
		stats_component.race_dmg_boosts[item.race_bonus] = item.race_bonus_value
		
	# Recalculamos stats
	_recalculate_equipment_bonuses()
	equipment_changed.emit()
	
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
	
	# Limpiar bonos de elemento si era un arma
	if slot_type == EquipmentItem.EquipmentSlot.WEAPON:
		stats_component.weapon_element = StatsComponent.Element.NEUTRAL
	
	# Recalcular stats
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
	
	# Resetear bonos de equipo (asumiendo que tendremos variables para esto en StatsComponent)
	var total_atk_bonus = 0
	var total_def_bonus = 0
	var total_str_bonus = 0
	var total_vit_bonus = 0
	
	# Sumar bonos de cada item equipado
	for slot_type in equipped_items:
		var item: EquipmentItem = equipped_items[slot_type]
		if item:
			total_atk_bonus += item.atk_bonus
			total_def_bonus += item.def_bonus
			total_str_bonus += item.str_bonus
			total_vit_bonus += item.vit_bonus
	
	# Aplicar los bonos al StatsComponent
	# NOTA: Necesitaremos agregar estas variables en StatsComponent
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
