extends Node3D

@onready var player := $Player
@onready var camera := $Player/CameraPivot/SpringArm3D/Camera3D

func _unhandled_input(event):
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:

		var space_state = get_world_3d().direct_space_state
		var mouse_pos = event.position

		var from = camera.project_ray_origin(mouse_pos)
		var to = from + camera.project_ray_normal(mouse_pos) * 1000

		var query = PhysicsRayQueryParameters3D.create(from, to)
		query.collide_with_areas = false

		var result = space_state.intersect_ray(query)

		if result:
			var nav = get_world_3d().navigation_map
			var target_on_nav = NavigationServer3D.map_get_closest_point(nav, result.position)
			player.nav_agent.target_position = target_on_nav
