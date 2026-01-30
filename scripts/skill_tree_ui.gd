extends Control

@onready var points_label = $Panel/LabelPoints
@onready var skills_container = $Panel/ScrollContainer/GridContainer # O donde estén tus botones

func _ready():
	# Empezamos ocultos
	visible = false
	add_to_group("skill_tree_ui")
	update_tree_ui()

# Función para abrir/cerrar
func toggle():
	visible = !visible
	if visible:
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

func update_tree_ui():
	# 1. Actualizar el texto de puntos disponibles
	points_label.text = "Skill Points: %d" % GameManager.player_stats["skill_points"]
	
	# 2. Recorrer todos los SkillButtons y pedirles que se refresquen
	# Esto sirve para que si desbloqueaste una skill, la siguiente se ponga "en color"
	for button in get_tree().get_nodes_in_group("skill_buttons"):
		if button.has_method("update_ui"):
			button.update_ui()
