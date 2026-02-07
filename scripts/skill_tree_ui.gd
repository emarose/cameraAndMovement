extends Control

@onready var points_label = $Panel/LabelPoints
@onready var tree_canvas = $Panel/ScrollContainer/TreeCanvas

var skill_buttons_dict = {}
var skill_button_scene = preload("res://scenes/SkillButton.tscn")

# Ajustes de diseño
var column_width = 200
var row_height = 120
var start_offset = Vector2(80, 80)

func _ready():
	visible = false
	add_to_group("skill_tree_ui")
	GameManager.job_changed.connect(_on_job_changed)
	tree_canvas.draw.connect(_on_tree_canvas_draw)
	rebuild_skill_tree()

func _on_job_changed(_new_job):
	rebuild_skill_tree()

# --- ESTA ES LA FUNCIÓN QUE BUSCABA EL BOTÓN ---
func update_tree_ui():
	# 1. Actualizar puntos
	if points_label:
		points_label.text = "Skill Points: %d" % GameManager.player_stats.get("skill_points", 0)
	
	# 2. Refrescar visualmente cada botón (colores, niveles)
	for button in get_tree().get_nodes_in_group("skill_buttons"):
		if button.has_method("update_ui"):
			button.update_ui()
	
	# 3. Redibujar líneas (por si cambian de color al aprenderse)
	tree_canvas.queue_redraw()

func toggle():
	visible = !visible
	if visible:
		rebuild_skill_tree()
		update_tree_ui()
		
func _input(event):
	if event.is_action_pressed("ui_skills"): 
		toggle()
	if event.is_action_pressed("ui_cancel") and visible:
		visible = false
		
func rebuild_skill_tree():
	for child in tree_canvas.get_children():
		child.queue_free()
	skill_buttons_dict.clear()
	
	# CARGAR TODAS LAS SKILLS DE TODOS LOS TRABAJOS DESBLOQUEADOS
	var all_skills: Array[SkillData] = []
	var unlocked_jobs = GameManager.player_stats.get("unlocked_jobs", [])
	
	for job_path in unlocked_jobs:
		var job_res = load(job_path) as JobData
		if job_res:
			for s in job_res.base_skills:
				if not all_skills.has(s): all_skills.append(s)

	# Organizar por Tiers
	var tiers = {}
	for skill in all_skills:
		var depth = _calculate_max_depth(skill)
		if not tiers.has(depth): tiers[depth] = []
		tiers[depth].append(skill)
	
	# Instanciar botones
	for depth in tiers.keys():
		var skill_list = tiers[depth]
		for i in range(skill_list.size()):
			var skill = skill_list[i]
			var btn = skill_button_scene.instantiate()
			
			tree_canvas.add_child(btn)
			btn.skill_data = skill
			
			# Posicionamiento
			var pos_x = start_offset.x + (depth * column_width)
			var pos_y = start_offset.y + (i * row_height)
			
			btn.position = Vector2(pos_x, pos_y)
			# Asegurar tamaño para que sea visible
			btn.custom_minimum_size = Vector2(64, 64) 
			
			skill_buttons_dict[skill] = btn

	tree_canvas.queue_redraw()
	update_tree_ui()

func _calculate_max_depth(skill: SkillData) -> int:
	if skill.required_skills.is_empty():
		return 0
	var max_d = 0
	for req in skill.required_skills:
		max_d = max(max_d, _calculate_max_depth(req))
	return 1 + max_d

func _on_tree_canvas_draw():
	for skill in skill_buttons_dict:
		var btn_child = skill_buttons_dict[skill]
		var is_child_learned = GameManager.get_skill_level(skill.id) > 0
		
		for req_skill in skill.required_skills:
			if skill_buttons_dict.has(req_skill):
				var btn_parent = skill_buttons_dict[req_skill]
				var is_parent_learned = GameManager.get_skill_level(req_skill.id) > 0
				
				# LA LÍNEA ES DORADA SOLO SI AMBAS SKILLS ESTÁN APRENDIDAS
				var line_color = Color(1, 0.84, 0) if (is_child_learned and is_parent_learned) else Color(0.2, 0.2, 0.2)
				var line_width = 4.0 if (is_child_learned and is_parent_learned) else 2.0
				
				_draw_skill_line(btn_parent.position + (btn_parent.size/2), 
								 btn_child.position + (btn_child.size/2), 
								 line_color, line_width)

func _draw_skill_line(start, end, color, width):
	var mid_x = start.x + (end.x - start.x) * 0.5
	tree_canvas.draw_line(start, Vector2(mid_x, start.y), color, width)
	tree_canvas.draw_line(Vector2(mid_x, start.y), Vector2(mid_x, end.y), color, width)
	tree_canvas.draw_line(Vector2(mid_x, end.y), end, color, width)

func _on_btn_close_pressed() -> void:
	toggle()
