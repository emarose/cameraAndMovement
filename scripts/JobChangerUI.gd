extends Control

# Referencia al jugador
var player: Node3D
var available_jobs: Array[JobData] = []

# Referencia al contenedor de la lista visual
@onready var jobs_container = $Panel/VBoxContainer/ScrollContainer/JobsContainer
@onready var close_button = $Panel/VBoxContainer/CloseButton
@onready var title_label = $Panel/VBoxContainer/TitleLabel
@onready var info_label = $Panel/VBoxContainer/InfoPanel/InfoVBox/InfoLabel

# Cargar el prefab directamente
var job_slot_prefab: PackedScene = preload("res://scenes/JobSlot.tscn")

func _ready():
	add_to_group("job_changer_ui")
	self.visible = false

func open_job_changer(p_player: Node3D, jobs: Array[JobData]):
	self.visible = true
	player = p_player
	available_jobs = jobs
	
	# Mostrar mensaje según el estado del jugador
	var current_job = GameManager.player_stats["job_name"]
	var current_level = GameManager.player_stats["job_level"]
	
	if current_job == "Novice":
		title_label.text = "Elige tu Primera Clase (Lvl %d/5)" % current_level
		info_label.text = "Alcanza Job Level 5 para elegir tu clase inicial"
	else:
		title_label.text = "Transcender a Nueva Clase (Lvl %d/40)" % current_level
		info_label.text = "Alcanza Job Level 40 para transcender a una nueva clase"
	
	# Llenar la lista de trabajos
	refresh_jobs_list()

func refresh_jobs_list():
	# 1. Limpiar
	for child in jobs_container.get_children():
		child.queue_free()
	
	var current_job_name = GameManager.player_stats["job_name"]
	
	# 2. Llenar con los trabajos disponibles
	for job in available_jobs:
		if job == null: continue
		
		var job_slot = job_slot_prefab.instantiate()
		jobs_container.add_child(job_slot)
		
		job_slot.set_data(job)
		
		# Marcar si es la clase actual
		if job.job_name == current_job_name:
			job_slot.set_selected(true)
		
		# Conectar señal de selección
		job_slot.pressed.connect(_on_job_selected.bind(job))

func _on_job_selected(job: JobData):
	if not player:
		return
	
	# Determine required level based on current job
	var required_level = 5 if GameManager.player_stats["job_name"] == "Novice" else 40
	var current_level = GameManager.player_stats["job_level"]
	
	# Verificar si el jugador ha alcanzado el nivel requerido
	if current_level < required_level:
		var message = "Debes alcanzar Job Level %d para %s" % [
			required_level,
			"elegir tu clase inicial" if required_level == 5 else "transcender"
		]
		get_tree().call_group("hud", "add_log_message", message, Color.ORANGE)
		return
	
	# Cambiar el trabajo
	GameManager.change_job(job)
	
	# Actualizar la UI con información del nuevo job
	var bonus_text = "STR: %+d | AGI: %+d | INT: %+d" % [job.str_bonus, job.agi_bonus, job.int_bonus]
	info_label.text = "%s - %s\n(Nivel 1/40)" % [job.job_name, bonus_text]
	
	get_tree().call_group("hud", "add_log_message", "¡Felicidades! Ahora eres un %s - Nivel 1/40" % job.job_name, Color.LIGHT_GREEN)
	
	close_job_changer()

func close_job_changer():
	self.visible = false
	player = null
