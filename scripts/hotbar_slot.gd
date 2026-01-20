extends Control
class_name HotbarSlot

@onready var shortcut_label = $ShortcutLabel
@onready var cooldown_overlay: TextureProgressBar = $TextureProgressBar
@onready var icon_rect: TextureRect = $Icon

var current_skill_name: String = ""
var current_content: Resource = null

var slot_index: int = 0

func setup(index: int, key_text: String):
	slot_index = index
	shortcut_label.text = key_text
	clear_slot()
	
func update_slot(resource):
	if resource == null:
		print("Slot %d: resource is NULL" % slot_index)
		clear_slot()
		return
	
	print("Slot %d: Got resource: %s" % [slot_index, resource.get_class()])
	current_content = resource
	icon_rect.visible = true
	
	# Handle SkillData
	if resource is SkillData:
		current_skill_name = resource.skill_name
		print("  Skill: %s, icon exists: %s" % [resource.skill_name, resource.icon != null])
		if resource.icon:
			print("  Setting icon texture: %s" % resource.icon.resource_path)
			icon_rect.texture = resource.icon
			icon_rect.self_modulate = Color.WHITE
		else:
			icon_rect.texture = null 
			icon_rect.self_modulate = Color.CADET_BLUE

func clear_slot():
	current_skill_name = ""
	current_content = null
	icon_rect.texture = null
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
