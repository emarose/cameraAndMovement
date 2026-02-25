extends Node3D
## Component that displays a casting circle indicator on the ground during skill casting
## 
## This component handles the visibility and positioning of a casting circle visual
## that appears when the player is casting a skill. It automatically follows the AOE
## indicator positioning logic: at mouse position for POINT skills, at player position otherwise.

@onready var casting_circle: Node3D = $CastingCircle
@onready var player: CharacterBody3D = get_parent()
@onready var skill_component = player.get_node("SkillComponent")

func _ready():
	if not player or not skill_component:
		push_error("CastingCircleComponent: Player or SkillComponent not found")
		return
	
	# Connect to skill state changes
	skill_component.skill_state_changed.connect(_on_skill_state_changed)

func _physics_process(_delta):
	if not casting_circle or not player or not skill_component:
		return
	
	_update_casting_circle()

func _update_casting_circle():
	"""Update the casting circle visibility and position during the cast_time window"""
	if not skill_component or not casting_circle:
		return
	
	if not skill_component.is_casting:
		casting_circle.visible = false
		return
	
	var skill = skill_component.pending_skill
	var target = skill_component.pending_target
	
	if not skill:
		casting_circle.visible = false
		return
	
	# During cast_time, lock the circle to the selected target position
	var s = skill.aoe_radius
	if s > 0:
		casting_circle.scale = Vector3(s, 1, s)
	if skill.type == SkillData.SkillType.POINT:
		if target is Vector3:
			casting_circle.visible = true
			casting_circle.global_position = target + Vector3(0, 0.1, 0)
		else:
			casting_circle.visible = false
	else:
		# For TARGET/SELF skills, show at the target or player position
		casting_circle.visible = true
		if target is Node3D:
			casting_circle.global_position = target.global_position + Vector3(0, 0.1, 0)
		else:
			casting_circle.global_position = player.global_position + Vector3(0, 0.1, 0)

func _get_mouse_world_interaction():
	"""Get the world position where the mouse is pointing"""
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return null
	
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 2000
	var space_state = get_world_3d().direct_space_state

	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true  
	query.collide_with_bodies = true
	query.exclude = [player.get_rid()]
	var result = space_state.intersect_ray(query)
	
	return result if result else null

func _on_skill_state_changed():
	"""Called when skill state changes, ensures circle updates visibility"""
	_update_casting_circle()
