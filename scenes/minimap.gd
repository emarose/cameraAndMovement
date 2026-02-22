extends Camera3D

var player_target: Node3D
@export var height: float = 100.0  # Camera height for top-down view
@export var zoom_level: float = 30.0  # Orthographic view size (smaller = more zoomed in)

func _ready():
	# Auto-detect player if not already assigned
	if not player_target:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_target = players[0]
		else:
			player_target = null

	# Configure camera for minimap
	if player_target:
		# Position camera above player
		global_position = Vector3(player_target.global_position.x, height, player_target.global_position.z)
		# Point camera down at the player
		look_at(player_target.global_position, Vector3.RIGHT)

func _process(_delta):
	if player_target:
		# 1. Follow player's X and Z position
		global_position.x = player_target.global_position.x
		global_position.z = player_target.global_position.z
		
		# 2. Maintain fixed height for top-down view
		global_position.y = height
		# 3. Fix minimap rotation to -90 degrees (so east is up)
		rotation = Vector3(-PI/2, 0, 0)
