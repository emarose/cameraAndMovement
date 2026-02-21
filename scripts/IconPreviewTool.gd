extends Control

@onready var item_path_edit: LineEdit = $VBoxContainer/PathContainer/ItemPath
@onready var browse_button: Button = $VBoxContainer/PathContainer/BrowseButton
@onready var load_button: Button = $VBoxContainer/LoadButton
@onready var file_dialog: FileDialog = $VBoxContainer/FileDialog
@onready var viewport: SubViewport = $VBoxContainer/PreviewRect/SubViewport
@onready var rotation_x_slider: HSlider = $VBoxContainer/RotationX/SliderX
@onready var rotation_y_slider: HSlider = $VBoxContainer/RotationY/SliderY
@onready var rotation_z_slider: HSlider = $VBoxContainer/RotationZ/SliderZ
@onready var rotation_x_value: Label = $VBoxContainer/RotationX/ValueX
@onready var rotation_y_value: Label = $VBoxContainer/RotationY/ValueY
@onready var rotation_z_value: Label = $VBoxContainer/RotationZ/ValueZ
@onready var copy_button: Button = $VBoxContainer/ButtonsContainer/CopyButton
@onready var save_button: Button = $VBoxContainer/ButtonsContainer/SaveButton
@onready var camera: Camera3D = viewport.get_node("Camera3D")
@onready var pivot: Node3D = viewport.get_node("Pivot")

var current_item: ItemData = null
var current_model: Node3D = null

func _ready():
	# Get pivot from viewport
	pivot = viewport.get_node("Pivot")
	
	# Connect signals
	load_button.pressed.connect(_on_load_pressed)
	browse_button.pressed.connect(_on_browse_pressed)
	file_dialog.file_selected.connect(_on_file_selected)
	rotation_x_slider.value_changed.connect(_on_rotation_changed)
	rotation_y_slider.value_changed.connect(_on_rotation_changed)
	rotation_z_slider.value_changed.connect(_on_rotation_changed)
	copy_button.pressed.connect(_on_copy_pressed)
	save_button.pressed.connect(_on_save_pressed)
	
	# Enable viewport rendering
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	print("Icon Preview Tool ready.")
	print("Instructions:")
	print("  1. Click Browse or drag an ItemData resource (.tres) from FileSystem")
	print("  2. Click Load Item")
	print("  3. Adjust rotation sliders")
	print("  4. Click Save to Resource when satisfied")

func _can_drop_data(_at_position: Vector2, data) -> bool:
	# Accept files dropped from Godot's FileSystem dock
	if typeof(data) == TYPE_DICTIONARY:
		if data.has("type") and data["type"] == "files":
			if data.has("files") and data["files"].size() > 0:
				var file = data["files"][0]
				return file.ends_with(".tres")
	return false

func _drop_data(_at_position: Vector2, data) -> void:
	if typeof(data) == TYPE_DICTIONARY:
		if data.has("type") and data["type"] == "files":
			if data.has("files") and data["files"].size() > 0:
				var file = data["files"][0]
				if file.ends_with(".tres"):
					item_path_edit.text = file
					_load_item(file)

func _on_browse_pressed():
	file_dialog.popup_centered(Vector2i(800, 600))

func _on_file_selected(path: String):
	item_path_edit.text = path
	_load_item(path)

func _on_drag_started():
	pass

func _on_load_pressed():
	_load_item(item_path_edit.text)

func _load_item(path: String):
	if path.is_empty():
		print("✗ Please enter an item path")
		return
	
	if not path.ends_with(".tres"):
		print("✗ Invalid file type. Please load an ItemData resource (.tres file)")
		print("  You tried to load: ", path)
		print("  Example: res://resources/items/HunterBow.tres")
		return
	
	if not FileAccess.file_exists(path):
		print("✗ File not found: ", path)
		return
		
	var item = load(path)
	if item is ItemData:
		current_item = item
		print("✓ Loaded item: ", item.item_name)
		_display_model()
		
		# Set sliders to current icon rotation
		rotation_x_slider.value = item.icon_rotation.x
		rotation_y_slider.value = item.icon_rotation.y
		rotation_z_slider.value = item.icon_rotation.z
		_update_labels()
	else:
		print("✗ Failed to load ItemData from: ", path)
		print("  The file exists but is not an ItemData resource")
		print("  Make sure you're loading an item resource (.tres), not a model file")

func _display_model():
	# Clear previous model
	if current_model:
		pivot.remove_child(current_model)
		current_model.queue_free()
		current_model = null
	
	if current_item and current_item.model:
		current_model = current_item.model.instantiate()
		pivot.add_child(current_model)
		_update_rotation()
		print("Model loaded and displayed")
	else:
		print("No model found for this item")

func _on_rotation_changed(_value):
	_update_rotation()
	_update_labels()

func _update_rotation():
	if current_model:
		# Aplicar rotación al modelo
		current_model.rotation_degrees = Vector3(
			rotation_x_slider.value,
			rotation_y_slider.value,
			rotation_z_slider.value
		)
		
		# Recalcular AABB y ajustar cámara
		var aabb = _calculate_model_aabb(current_model)
		_adjust_camera_to_fit(aabb)

func _calculate_model_aabb(node: Node) -> AABB:
	var result_aabb := AABB()
	var found_any := false
	var meshes = _get_all_mesh_instances(node)

	if meshes.is_empty():
		return AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1, 1, 1))

	for mesh_instance in meshes:
		var local_aabb = mesh_instance.get_aabb()
		if local_aabb.size.length() < 0.001:
			continue

		var transform = pivot.global_transform.affine_inverse() * mesh_instance.global_transform
		var transformed_aabb = transform * local_aabb

		if found_any:
			result_aabb = result_aabb.merge(transformed_aabb)
		else:
			result_aabb = transformed_aabb
			found_any = true

	if not found_any:
		result_aabb = AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1, 1, 1))

	return result_aabb

func _get_all_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		meshes.append_array(_get_all_mesh_instances(child))
	return meshes

func _adjust_camera_to_fit(aabb: AABB):
	var size = aabb.size.length()
	var center = aabb.get_center()
	var distance = max(size * 1, 0.1)
	var offset = Vector3(0.1, 0.1, 0.9).normalized() * distance
	camera.position = center + offset
	camera.look_at(center, Vector3.UP)


func _update_labels():
	rotation_x_value.text = "%.1f" % rotation_x_slider.value
	rotation_y_value.text = "%.1f" % rotation_y_slider.value
	rotation_z_value.text = "%.1f" % rotation_z_slider.value

func _on_copy_pressed():
	var rot_vec = Vector3(
		rotation_x_slider.value,
		rotation_y_slider.value,
		rotation_z_slider.value
	)
	DisplayServer.clipboard_set("Vector3(%.1f, %.1f, %.1f)" % [rot_vec.x, rot_vec.y, rot_vec.z])
	print("Copied to clipboard: Vector3(%.1f, %.1f, %.1f)" % [rot_vec.x, rot_vec.y, rot_vec.z])

func _on_save_pressed():
	if current_item:
		current_item.icon_rotation = Vector3(
			rotation_x_slider.value,
			rotation_y_slider.value,
			rotation_z_slider.value
		)
		var result = ResourceSaver.save(current_item, current_item.resource_path)
		if result == OK:
			print("✓ Saved rotation to: ", current_item.resource_path)
			print("  Vector3(%.1f, %.1f, %.1f)" % [current_item.icon_rotation.x, current_item.icon_rotation.y, current_item.icon_rotation.z])
			# Clear icon cache so it regenerates with new rotation
			if IconGenerator:
				IconGenerator.clear_cache()
				print("  Icon cache cleared - icons will regenerate")
		else:
			print("✗ Failed to save resource")
	else:
		print("No item loaded")
