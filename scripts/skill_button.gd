extends TextureButton

@export var skill_data: SkillData # Arrastra aquí el recurso Bash.tres o similar

@onready var label = $Label

func _ready():
	add_to_group("skill_buttons")
	update_ui()
	pressed.connect(_on_pressed)

func update_ui():
	if not skill_data: return
	
	var current_level = GameManager.get_skill_level(skill_data.id)
	var can_learn = GameManager.can_learn_skill(skill_data)
	
	# Añadir indicador (PASSIVE) para skills pasivas
	var passive_tag = " (PASSIVE)" if skill_data.is_passive else ""
	label.text = "%s [%d/%d]%s" % [skill_data.skill_name, current_level, skill_data.max_level, passive_tag]
	if skill_data.icon:
		texture_normal = skill_data.icon
	
	# NO USAR disabled = true, ya que bloquea el Drag & Drop.
	# En su lugar, modulamos el color y controlamos el clic manualmente.
	if current_level == 0 and not can_learn:
		modulate = Color(0.3, 0.3, 0.3) # Muy oscuro (Bloqueada y no aprendida)
	elif not can_learn:
		modulate = Color(0.7, 0.7, 0.7) # Grisáceo (Aprendida pero no subible)
	else:
		modulate = Color(1, 1, 1) # Normal (Disponible para subir)

func _on_pressed():
	# El control de "si puedo subirla" lo hacemos aquí ahora que el botón no está disabled
	if GameManager.can_learn_skill(skill_data):
		if GameManager.level_up_skill(skill_data):
			var tree_ui = get_tree().get_first_node_in_group("skill_tree_ui")
			if tree_ui: tree_ui.update_tree_ui()

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
