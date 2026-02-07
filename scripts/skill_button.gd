extends TextureButton

@export var skill_data: SkillData # Arrastra aquí el recurso Bash.tres o similar
@onready var skill_level_label: Label = $Panel/SkillLevel

func _ready():
	add_to_group("skill_buttons")
	# Forzamos que el material sea único al iniciar
	if material:
		material = material.duplicate()
	update_ui()
	pressed.connect(_on_pressed)

func update_ui():
	if not skill_data: return
	
	var current_level = GameManager.get_skill_level(skill_data.id)
	var can_learn = GameManager.can_learn_skill(skill_data)
	
	# 1. Actualizar el icono
	if skill_data.icon:
		texture_normal = skill_data.icon
	
	# 2. Actualizar el Label de Nivel (Estilo 0/5)
	if skill_level_label:
		skill_level_label.text = "%d/%d" % [current_level, skill_data.max_level]
	
	# 3. Aplicar Shader (Outline y Redondeado)
	if material is ShaderMaterial:
		material.set_shader_parameter("is_passive", skill_data.is_passive)
		material.set_shader_parameter("is_learned", current_level > 0)

	# 4. Feedback visual de disponibilidad
	if current_level == 0 and not can_learn:
		modulate = Color(0.2, 0.2, 0.2) # Bloqueada (Muy oscuro)
	elif current_level == 0 and can_learn:
		modulate = Color(0.5, 0.5, 0.5) # Disponible pero no comprada (Gris)
	else:
		modulate = Color(1, 1, 1) # Aprendida (Full color)

func _on_pressed():
	if GameManager.can_learn_skill(skill_data):
		if GameManager.level_up_skill(skill_data):
			# Usamos call_group para avisar a la UI que refresque todo
			get_tree().call_group("skill_tree_ui", "update_tree_ui")

# --- DRAG AND DROP PARA SKILLS ---
func _get_drag_data(_at_position):
	if skill_data == null:
		return null
	
	# Las skills pasivas no pueden arrastrarse
	if skill_data.is_passive:
		return null
	
	var current_level = GameManager.get_skill_level(skill_data.id)
	if current_level == 0:
		return null # No arrastrar si no tienes la skill
	
	# Crear vista previa del icono (siguiendo el mismo patrón que inventory_ui_slot)
	var preview_texture = TextureRect.new()
	if skill_data.icon:
		preview_texture.texture = skill_data.icon
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.custom_minimum_size = Vector2(40, 40)
	
	var preview_control = Control.new()
	preview_control.add_child(preview_texture)
	preview_texture.position = -0.5 * preview_texture.custom_minimum_size
	
	set_drag_preview(preview_control)
	
	# Retornar datos con source "skill"
	var data = {
		"source": "skill",
		"skill": skill_data
	}
	return data
