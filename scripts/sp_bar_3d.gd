extends Sprite3D

@onready var progress_bar = $SubViewport/ProgressBar
@onready var viewport = $SubViewport

var _initialized: bool = false

func _ready():
	progress_bar.value = 0
	texture = viewport.get_texture()
	await get_tree().process_frame
	var owner_node = get_parent()
	if owner_node:
		var sp_comp = owner_node.get_node_or_null("SPComponent")
		if sp_comp:
			update_bar(sp_comp.current_sp, sp_comp.max_sp)

func update_bar(current, max_val):
	if not progress_bar:
		return

	if max_val <= 0:
		progress_bar.value = 0
		return

	var target_value = (float(current) / max_val) * 100

	if not _initialized:
		progress_bar.value = target_value
		_initialized = true
	else:
		var tween = create_tween()
		tween.tween_property(progress_bar, "value", target_value, 0.2).set_trans(Tween.TRANS_SINE)
