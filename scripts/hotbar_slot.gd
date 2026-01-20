extends Control
class_name HotbarSlot

@onready var shortcut_label = $ShortcutLabel
@onready var cooldown_overlay: TextureProgressBar = $TextureProgressBar
@onready var icon_rect: TextureRect = $Icon
@onready var amount_label = $AmountLabel

var current_skill_name: String = ""
var current_content: Resource = null

var slot_index: int = 0

func setup(index: int, key_text: String):
	slot_index = index
	shortcut_label.text = key_text
	clear_slot()
	
func update_slot(resource, amount: int = 0):
	if resource == null:
		clear_slot()
		return
	
	current_content = resource
	icon_rect.visible = true
	
	# Handle SkillData
	if resource is SkillData:
		current_skill_name = resource.skill_name
		if resource.icon:
			icon_rect.texture = resource.icon
			icon_rect.self_modulate = Color.WHITE
		else:
			icon_rect.texture = null 
			icon_rect.self_modulate = Color.CADET_BLUE
		# Skills don't have amounts
		amount_label.visible = false
			
	# Handle ItemData	
	elif resource is ItemData:
		current_skill_name = resource.item_name

		if resource.icon:
			icon_rect.texture = resource.icon
			icon_rect.self_modulate = Color.WHITE
		else:
			icon_rect.texture = null
			icon_rect.self_modulate = Color.LIGHT_GRAY
		
		# Show amount for stackable items
		if amount > 1:
			amount_label.visible = true
			amount_label.text = str(amount)
		else:
			amount_label.visible = false
		
func clear_slot():
	current_skill_name = ""
	current_content = null
	icon_rect.texture = null
	amount_label.visible = false
	# Asegúrate de ocultar el progreso al limpiar
	cooldown_overlay.visible = false 
	cooldown_overlay.value = 0

func start_cooldown_visual(duration: float):
	cooldown_overlay.max_value = duration
	cooldown_overlay.value = duration
	cooldown_overlay.visible = true
	
	# Creamos un Tween para animar el valor hasta 0
	var tween = create_tween()
	tween.tween_property(cooldown_overlay, "value", 0.0, duration).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(func(): cooldown_overlay.visible = false)
