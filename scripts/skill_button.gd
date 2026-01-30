extends Button

@export var skill_data: SkillData # Arrastra aquí el recurso Bash.tres o similar

func _ready():
	add_to_group("skill_buttons")
	update_ui()
	pressed.connect(_on_pressed)

func _on_pressed():
	if GameManager.level_up_skill(skill_data):
		# Buscamos al padre SkillTreeUI para que refresque todo el árbol
		var tree_ui = get_tree().get_first_node_in_group("skill_tree_ui")
		if tree_ui:
			tree_ui.update_tree_ui()

func update_ui():
	if not skill_data:
		return
	
	var current_level = GameManager.get_skill_level(skill_data.id)
	var can_learn = GameManager.can_learn_skill(skill_data)
	
	# Actualizar el texto del botón
	text = "%s [%d/%d]" % [skill_data.skill_name, current_level, skill_data.max_level]
	
	# Actualizar el estado visual
	disabled = not can_learn
	
	# Opcional: cambiar color o estilo según el estado
	if current_level >= skill_data.max_level:
		modulate = Color(0.5, 1.0, 0.5) # Verde = Maxeada
	elif can_learn:
		modulate = Color(1.0, 1.0, 1.0) # Blanco = Disponible
	else:
		modulate = Color(0.5, 0.5, 0.5) # Gris = Bloqueada
