extends Control
class_name HotbarSlot

@onready var icon_rect = $Icon
@onready var shortcut_label = $ShortcutLabel
# @onready var cooldown_overlay = $CooldownOverlay (Lo usaremos luego)

var slot_index: int = 0

func setup(index: int, key_text: String):
	slot_index = index
	shortcut_label.text = key_text
	clear_slot()

func update_slot(resource):
	if resource == null:
		clear_slot()
		return
	
	# Detectar si es Skill o Item para sacar el icono
	if resource is SkillData:
		# Asumiendo que SkillData tiene var icon: Texture2D (si no, agrégasela)
		# icon_rect.texture = resource.icon 
		pass # Descomenta cuando agregues iconos a tus Skills
	elif resource is ItemData:
		icon_rect.texture = resource.icon
	
	# Si no tienes iconos aún, usa un color o placeholder
	icon_rect.visible = (icon_rect.texture != null)

func clear_slot():
	icon_rect.visible = false
