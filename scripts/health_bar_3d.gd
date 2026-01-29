extends Sprite3D

@onready var progress_bar = $SubViewport/ProgressBar
@onready var viewport = $SubViewport

var _initialized: bool = false

func _ready():
	# 1. Empezar en 0 para evitar el salto visual al primer update
	progress_bar.value = 0
	
	# 2. Asegurar que la textura esté vinculada
	texture = viewport.get_texture()
	
	# 3. Esperar un frame para asegurar que el viewport esté listo
	await get_tree().process_frame
	# 4. Inicializar con la vida real del dueño (si existe)
	var owner_node = get_parent()
	if owner_node:
		var health_comp = owner_node.get_node_or_null("HealthComponent")
		if health_comp:
			update_bar(health_comp.current_health, health_comp.max_health)

func update_bar(current, max_val):
	if not progress_bar: return
	
	var target_value = (float(current) / max_val) * 100

	# Primera vez: setear directo sin animación
	if not _initialized:
		progress_bar.value = target_value
		_initialized = true
	else:
		# Animación suave
		var tween = create_tween()
		tween.tween_property(progress_bar, "value", target_value, 0.2).set_trans(Tween.TRANS_SINE)
	
	# Cambiar color si queda poca vida
	if target_value < 30:
		progress_bar.modulate = Color(1, 0.3, 0.3) # Rojo
	else:
		progress_bar.modulate = Color(1, 1, 1) # Blanco (color original del StyleBox)
