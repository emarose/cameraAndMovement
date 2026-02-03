extends Control

@onready var points_label = $Panel/LabelPoints
@onready var skills_container = $Panel/ScrollContainer/SkillTreeList # Ahora es un VBoxContainer

var skill_button_scene = preload("res://scenes/SkillButton.tscn")

func _ready():
	# Empezamos ocultos
	visible = false
	add_to_group("skill_tree_ui")
	
	# Connect to job changed signal
	GameManager.job_changed.connect(_on_job_changed)
	
	# Initialize the tree if we already have job data
	rebuild_skill_tree()
	update_tree_ui()

func _on_job_changed(_new_job):
	rebuild_skill_tree()
	update_tree_ui()

# Función para abrir/cerrar
func toggle():
	visible = !visible
	if visible:
		# Actualizar el árbol cada vez que se abre para asegurar que coincida con el job actual
		rebuild_skill_tree()
		update_tree_ui()
		# Opcional: Pausar el juego o liberar el mouse
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event):
	# Si presionas "S" (o la tecla que definas), abre el árbol
	if event.is_action_pressed("ui_skills"): # Configura "ui_skills" en el Input Map como 'S' o 'K'
		toggle()
	
	# Si presionas ESC y el árbol está abierto, ciérralo
	if event.is_action_pressed("ui_cancel") and visible:
		visible = false

func rebuild_skill_tree():
	# 1. Limpiar secciones existentes
	for child in skills_container.get_children():
		child.queue_free()
	
	# 2. Recorrer todos los trabajos desbloqueados
	var unlocked_job_paths = GameManager.player_stats.get("unlocked_jobs", [])
	
	# Ordenar para que Novice siempre salga primero si se desea
	# (Aquí asumimos que el orden en el array es el orden de obtención)
	
	for job_path in unlocked_job_paths:
		var job_res = load(job_path) as JobData
		if not job_res: continue
		
		# Crear una sección para este trabajo
		_create_job_section(job_res)

func _create_job_section(job_res: JobData):
	# Skip if no skills
	if job_res.base_skills.is_empty():
		return

	# 1. Crear el Título de la Clase
	var header = Label.new()
	header.text = "--- %s SKILLS ---" % job_res.job_name.to_upper()
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 18)
	header.modulate = Color(1, 0.8, 0) # Dorado para resaltar
	skills_container.add_child(header)
	
	# 2. Crear el GridContainer para los botones de esta clase
	var grid = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	skills_container.add_child(grid)
	
	# 3. Añadir los botones de skills a este grid
	for skill in job_res.base_skills:
		if skill:
			var btn = skill_button_scene.instantiate()
			# IMPORTANTE: Asignar la data ANTES de add_child
			btn.skill_data = skill
			grid.add_child(btn)

func update_tree_ui():
	# 1. Actualizar el texto de puntos disponibles
	if points_label:
		points_label.text = "Skill Points: %d" % GameManager.player_stats["skill_points"]
	
	# 2. Recorrer todos los SkillButtons y pedirles que se refresquen
	# Esto sirve para que si desbloqueaste una skill, la siguiente se ponga "en color"
	if not is_inside_tree():
		return
		
	for button in get_tree().get_nodes_in_group("skill_buttons"):
		if button.has_method("update_ui"):
			button.update_ui()
