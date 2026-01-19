extends Control
class_name HotbarSlot

@onready var icon_rect = $Icon
@onready var shortcut_label = $ShortcutLabel
@onready var cooldown_overlay: TextureProgressBar = $TextureProgressBar

var current_skill_name: String = ""

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
	
	# Guardar el nombre para identificación
	if resource is SkillData:
		current_skill_name = resource.skill_name
		# Resetear cooldown visual si cambiamos de skill
		cooldown_overlay.value = 0
	else:
		current_skill_name = ""
		cooldown_overlay.value = 0
		
func start_cooldown_visual(duration: float):
	cooldown_overlay.max_value = duration
	cooldown_overlay.value = duration
	cooldown_overlay.visible = true
	
	# Creamos un Tween para animar el valor hasta 0
	var tween = create_tween()
	tween.tween_property(cooldown_overlay, "value", 0.0, duration).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(func(): cooldown_overlay.visible = false)
	
func clear_slot():
	icon_rect.visible = false
