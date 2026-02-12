extends Node3D

@export var mouse_sensitivity := 0.005
@export var min_pitch := deg_to_rad(-60)
@export var max_pitch := deg_to_rad(-40)

@export var min_distance := 4.0
@export var max_distance := 15.0
@export var zoom_speed := 1.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var player := get_parent()

var yaw := 0.0
var pitch := deg_to_rad(-35)

func _ready():
	top_level = true

	# Estado inicial limpio
	global_rotation = Vector3.ZERO
	spring_arm.rotation = Vector3(pitch, 0, 0)
	spring_arm.spring_length = 8.0

func _process(_delta):
	# seguir SOLO la posición
	global_position = player.global_position + Vector3(0, 1.5, 0)

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, min_pitch, max_pitch)

		global_rotation.y = yaw
		spring_arm.rotation.x = pitch

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_arm.spring_length = clamp(
				spring_arm.spring_length - zoom_speed,
				min_distance,
				max_distance
			)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_arm.spring_length = clamp(
				spring_arm.spring_length + zoom_speed,
				min_distance,
				max_distance
			)
