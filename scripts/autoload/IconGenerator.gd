extends Node

## Sistema de generación automática de íconos desde modelos 3D
## Renderiza modelos en un SubViewport y cachea las texturas resultantes
##
## USO:
##   var icon = IconGenerator.get_icon(item_data)
##   icon_texture.texture = icon
##
## COMPORTAMIENTO:
##   - Si el ícono ya fue generado, se devuelve inmediatamente desde caché
##   - Si el item tiene modelo 3D, se genera en background y se devuelve el ícono estático temporalmente
##   - Cuando la generación 3D termina, se emite la señal icon_generated(item_data, texture)
##   - Si no hay modelo 3D, se usa el ícono estático del ItemData
##
## PRELOAD (Opcional):
##   await IconGenerator.preload_icons_async([item1, item2, item3])
##   # Espera a que todos los íconos se generen (útil en loading screens)

const ICON_SIZE := 128  # Tamaño del ícono generado
const CAMERA_DISTANCE := 2.0
const VIEWPORT_SCENE := preload("res://scenes/IconRenderViewport.tscn")

signal icon_generated(item_data: ItemData, texture: Texture2D)

# Cache de íconos generados {resource_path: ImageTexture}
var _icon_cache: Dictionary = {}
# Items en proceso de generación
var _generating: Dictionary = {}

# Viewport para renderizado
var _viewport: SubViewport
var _camera: Camera3D
var _pivot: Node3D

func _ready():
	_setup_viewport()

## Configura el viewport de renderizado con cámara y luz
func _setup_viewport():
	# Instanciar la escena del viewport
	_viewport = VIEWPORT_SCENE.instantiate()
	add_child(_viewport)
	
	# Obtener referencias a los nodos
	_camera = _viewport.get_node("Camera3D")
	_pivot = _viewport.get_node("Pivot")
	_camera.fov = 50.0

	# Configurar look_at ahora que está en el árbol
	_camera.look_at(Vector3.ZERO, Vector3.UP)

## Genera un ícono desde un modelo 3D o devuelve el ícono estático si no hay modelo
## Retorna inmediatamente con el ícono en caché o fallback, y genera en background si es necesario
func get_icon(item_data: ItemData) -> Texture2D:
	if not item_data:
		return null
	
	# Si ya está en cache, devolverlo inmediatamente
	var cache_key = _get_cache_key(item_data)
	if _icon_cache.has(cache_key):
		return _icon_cache[cache_key]
	
	# Si ya está generándose, devolver el fallback
	if _generating.has(cache_key):
		return item_data.icon if item_data.icon else null
	
	# Si hay un modelo, iniciar generación en background
	if item_data.model:
		_generating[cache_key] = true
		_generate_icon_async(item_data, cache_key)
		# Devolver el ícono estático mientras se genera
		return item_data.icon if item_data.icon else null
	
	# Fallback: usar solo el ícono estático si existe
	if item_data.icon:
		_icon_cache[cache_key] = item_data.icon
		return item_data.icon
	
	return null

## Genera el ícono de manera asíncrona
func _generate_icon_async(item_data: ItemData, cache_key: String):
	var generated_icon = await _generate_icon_from_model(item_data.model)
	
	_generating.erase(cache_key)
	
	if generated_icon:
		_icon_cache[cache_key] = generated_icon
		icon_generated.emit(item_data, generated_icon)

## Genera una textura desde un modelo 3D
func _generate_icon_from_model(model_scene: PackedScene) -> ImageTexture:
	if not model_scene or not _viewport:
		return null
	
	# Instanciar el modelo
	var model_instance = model_scene.instantiate()
	_pivot.add_child(model_instance)
	
	# Esperar un frame para que el modelo se configure
	await get_tree().process_frame
	
	# Calcular el tamaño del modelo para ajustar la cámara
	var aabb = _calculate_model_aabb(model_instance)
	_adjust_camera_to_fit(aabb)
	
	# Forzar actualización del viewport
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	# Esperar a que se renderice (darle tiempo a aplicar la rotación)
	await get_tree().process_frame
	
	# Capturar la imagen
	var viewport_texture = _viewport.get_texture()
	if not viewport_texture:
		print("IconGenerator: Failed to get viewport texture")
		model_instance.queue_free()
		return null
	
	var img = viewport_texture.get_image()
	if not img:
		print("IconGenerator: Failed to get image from texture")
		model_instance.queue_free()
		return null
	
	var texture = ImageTexture.create_from_image(img)
	
	# Limpiar modelo (pero no resetear pivot, ya que no lo usamos para rotación)
	model_instance.queue_free()
	
	# Resetear viewport
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	
	return texture

## Calcula el AABB (bounding box) del modelo y sus hijos
func _calculate_model_aabb(node: Node) -> AABB:
	var result_aabb := AABB()
	var found_any := false
	
	# Recolectar todos los MeshInstance3D
	var meshes = _get_all_mesh_instances(node)
	
	if meshes.is_empty():
		# Usar un AABB por defecto si no hay meshes
		return AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1, 1, 1))
	
	# Combinar AABBs de todos los meshes
	for mesh_instance in meshes:
		var local_aabb = mesh_instance.get_aabb()
		if local_aabb.size.length() < 0.001:
			continue
		
		# Transformar a espacio local del pivot
		var transform = _pivot.global_transform.affine_inverse() * mesh_instance.global_transform
		var transformed_aabb = transform * local_aabb
		
		if not found_any:
			result_aabb = transformed_aabb
			found_any = true
		else:
			result_aabb = result_aabb.merge(transformed_aabb)
	
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

## Ajusta la cámara para que el modelo quepa en el frame
func _adjust_camera_to_fit(aabb: AABB):
	var size = aabb.size.length()
	var center = aabb.get_center()
	
	# Calcular distancia óptima basada en el FOV de la cámara
	# Para una cámara con FOV ~70°, necesitamos más distancia
	var distance = max(size * 1, 0.1)
	
	# Posicionar la cámara en un ángulo diagonal agradable
	var offset = Vector3(0.1, 0.1, 0.9).normalized() * distance
	_camera.position = center + offset
	_camera.look_at(center, Vector3.UP)

## Genera una clave única para el cache
func _get_cache_key(item_data: ItemData) -> String:
	if item_data.model:
		return item_data.model.resource_path
	elif item_data.icon:
		return item_data.icon.resource_path
	else:
		return item_data.resource_path

## Limpia el cache (útil para debugging o cambios en runtime)
func clear_cache():
	_icon_cache.clear()
	_generating.clear()

## Pre-genera íconos para una lista de ítems de manera asíncrona
## Útil para loading screens - espera a que todos se generen
func preload_icons_async(items: Array[ItemData]) -> void:
	var tasks = []
	for item in items:
		if item and item.model:
			var cache_key = _get_cache_key(item)
			if not _icon_cache.has(cache_key) and not _generating.has(cache_key):
				_generating[cache_key] = true
				tasks.append(await _generate_icon_async(item, cache_key))
	
	# Esperar a que todos terminen
	for task in tasks:
		await task

## Versión síncrona que inicia la generación pero no espera
func preload_icons(items: Array[ItemData]):
	for item in items:
		if item:
			get_icon(item)
