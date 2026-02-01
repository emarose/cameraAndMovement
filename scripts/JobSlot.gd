extends Button

@onready var icon_rect = $HBoxContainer/TextureRect
@onready var name_label = $HBoxContainer/VBoxContainer/JobNameLabel
@onready var bonus_label = $HBoxContainer/VBoxContainer/BonusLabel

func set_data(job: JobData):
	if job.job_icon:
		icon_rect.texture = job.job_icon
	
	name_label.text = job.job_name
	
	# Display stat bonuses
	var bonus_text = "STR%+d AGI%+d INT%+d" % [job.str_bonus, job.agi_bonus, job.int_bonus]
	bonus_label.text = bonus_text
	
	# Color coding based on bonuses
	if job.str_bonus > 0:
		bonus_label.modulate = Color.RED  # STR bonus
	elif job.agi_bonus > 0:
		bonus_label.modulate = Color.YELLOW  # AGI bonus
	elif job.int_bonus > 0:
		bonus_label.modulate = Color.CYAN  # INT bonus
	else:
		bonus_label.modulate = Color.WHITE  # Neutral (Novice)

func set_selected(is_selected: bool):
	if is_selected:
		# Brighten and add border effect for selected
		self_modulate = Color(1.3, 1.3, 1.0, 1.0)  # Slightly golden tint
		custom_minimum_size = Vector2(300, 80)
	else:
		self_modulate = Color.WHITE
		custom_minimum_size = Vector2(300, 80)
