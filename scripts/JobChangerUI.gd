extends Control

# Referencia al jugador
var player: Node3D
var available_jobs: Array[JobData] = []

# Referencia al contenedor de la lista visual
@onready var jobs_container = $Panel/VBoxContainer/ScrollContainer/JobsContainer
@onready var close_button = $Panel/VBoxContainer/CloseButton
@onready var title_label = $Panel/VBoxContainer/TitleLabel
@onready var info_label = $Panel/VBoxContainer/InfoPanel/InfoVBox/InfoLabel

@export var job_slot_prefab: PackedScene

func _ready():
	add_to_group("job_changer_ui")
	self.visible = false

func open_job_changer(p_player: Node3D, jobs: Array[JobData]):
	self.visible = true
	player = p_player
	available_jobs = jobs
		# Llenar la lista de trabajos
	refresh_jobs_list()

func refresh_jobs_list():
	# 1. Limpiar
	for child in jobs_container.get_children():
		child.queue_free()
	
	# 2. Llenar con los trabajos disponibles
	for job in available_jobs:
		if job == null: continue
		
		var job_slot = job_slot_prefab.instantiate()
		jobs_container.add_child(job_slot)
		
		job_slot.set_data(job)
		
		# Conectar señal de selección
		job_slot.pressed.connect(_on_job_selected.bind(job))

func _on_job_selected(job: JobData):
	if not player:
		return
	
	# Verificar si el jugador ha alcanzado Job Level 5
	if GameManager.player_stats["job_level"] < 5:
		get_tree().call_group("hud", "add_log_message", "Debes alcanzar Job Level 5 para cambiar de clase", Color.ORANGE)
		return
	
	# Cambiar el trabajo
	GameManager.change_job(job)
	
	# Actualizar la UI
	var bonus_text = "STR: %+d | AGI: %+d | INT: %+d" % [job.str_bonus, job.agi_bonus, job.int_bonus]
	info_label.text = "%s - %s" % [job.job_name, bonus_text]
	
	get_tree().call_group("hud", "add_log_message", "¡Felicidades! Ahora eres un %s" % job.job_name, Color.LIGHT_GREEN)
	
	close_job_changer()

func close_job_changer():
	self.visible = false
	player = null
