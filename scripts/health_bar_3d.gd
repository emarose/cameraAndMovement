extends Sprite3D

@onready var progress_bar = $SubViewport/ProgressBar
@onready var viewport = $SubViewport

func _ready():
	# 1. Forzar que la barra empiece llena
	progress_bar.value = 100
	
	# 2. Asegurar que la textura esté vinculada
	texture = viewport.get_texture()
	
	# 3. TRUCO: Esperar un frame y refrescar para evitar el glitch de "barra vacía"
	await get_tree().process_frame
	update_bar(100, 100)

func update_bar(current, max_val):
	if not progress_bar: return
	
	var target_value = (float(current) / max_val) * 100
	
	# Animación suave
	var tween = create_tween()
	tween.tween_property(progress_bar, "value", target_value, 0.2).set_trans(Tween.TRANS_SINE)
	
	# Cambiar color si queda poca vida
	if target_value < 30:
		progress_bar.modulate = Color(1, 0.3, 0.3) # Rojo
	else:
		progress_bar.modulate = Color(1, 1, 1) # Blanco (color original del StyleBox)
