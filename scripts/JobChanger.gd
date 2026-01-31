extends StaticBody3D

@export var npc_name: String = "Job Master"
@export var interact_distance: float = 8.0 
@export var available_jobs: Array[JobData] = [] # Dragging job resources here

func interact(player: Node3D):
	var dist = global_position.distance_to(player.global_position)
	if dist <= interact_distance:
		_open_job_changer(player)
	else:
		get_tree().call_group("hud", "add_log_message", "Acércate más a %s" % npc_name, Color.GRAY)

func _open_job_changer(player):
	var job_ui = get_tree().get_first_node_in_group("job_changer_ui")
	
	if job_ui:
		job_ui.open_job_changer(player, available_jobs)
