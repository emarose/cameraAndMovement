extends Area3D
class_name ItemDrop

## Maneja el comportamiento de un item caído por un enemigo
## - Area3D como nodo raíz para detectar al jugador (pickup)
## - Sprite3D para mostrar el icono del item
## - Física del movimiento (salto inicial + deslizamiento horizontal)

@onready var icon_sprite: Sprite3D = $Sprite3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

@export var item_data: ItemData
@export var quantity: int = 1
@export var pickup_delay: float = 0.2  # Tiempo antes de que se pueda recoger
@export var jump_height: float = 2.0
@export var jump_duration: float = 0.3
@export var slide_duration: float = 0.3
@export var slide_distance: float = 2.0
@export var magnet_radius: float = 2.5
@export var magnet_speed: float = 6.0
@export var pickup_distance: float = 0.6


var player: Node3D = null
var can_pickup: bool = false
var has_been_picked: bool = false
var initial_position: Vector3
var _is_attracting: bool = false
var _pickup_fail_cooldown: float = 0.0 # Cooldown entre intentos fallidos

# Efecto visual de hover y rotación
var _hover_time: float = 0.0
var _hover_amplitude: float = 0.15
var _hover_speed: float = 2.0
var _rotation_speed: float = 60.0 # grados por segundo
var _effect_target: Node3D = null

func _ready():
	body_entered.connect(_on_body_entered)
	player = get_tree().get_first_node_in_group("player")
	set_process(true)

	# Buscar el modelo 3D si existe, si no usar el icono
	for child in get_children():
		if child is Node3D and child != icon_sprite and child != collision_shape:
			_effect_target = child
			break
	if not _effect_target:
		_effect_target = icon_sprite

func _process(delta):
	# Efecto visual de hover y rotación
	if _effect_target:
		_hover_time += delta * _hover_speed
		var y_offset = sin(_hover_time) * _hover_amplitude
		var pos = _effect_target.position
		pos.y = y_offset
		_effect_target.position = pos
		_effect_target.rotate_y(deg_to_rad(_rotation_speed * delta))

	if not can_pickup or has_been_picked:
		return
	if not player or not is_instance_valid(player):
		return

	# Actualizar cooldown de intento fallido
	if _pickup_fail_cooldown > 0:
		_pickup_fail_cooldown -= delta
		_is_attracting = false # No atraerse mientras hay cooldown
		return

	var dist_to_player = global_position.distance_to(player.global_position)

	# Si salimos del radio de magnetismo, reseteamos el flag de atracción
	if dist_to_player > magnet_radius:
		_is_attracting = false
		return

	# Estamos dentro del radio, atraerse
	if not _is_attracting:
		_is_attracting = true

	if _is_attracting:
		var target_pos = player.global_position + Vector3(0, 0.6, 0)
		global_position = global_position.lerp(target_pos, clamp(magnet_speed * delta, 0.0, 1.0))
		if global_position.distance_to(target_pos) <= pickup_distance:
			_pickup_item()

## Configura el ItemDrop después de ser añadido al árbol y posicionado
func setup(p_item_data: ItemData, p_quantity: int, custom_delay: float = 0.0):
	item_data = p_item_data
	quantity = p_quantity
	
	if not item_data:
		push_error("ItemDrop: No item_data asignado")
		queue_free()
		return
	
	initial_position = global_position

	# Asignar el icono del item al Sprite3D
	var item_icon = IconGenerator.get_icon(item_data)
	if icon_sprite and item_icon:
		icon_sprite.texture = item_icon

	# Buscar el modelo 3D si existe (ignora icon_sprite y collision_shape)
	var model_node: Node3D = null
	for child in get_children():
		if child is Node3D and child != icon_sprite and child != collision_shape:
			model_node = child
			break

	if model_node:
		_effect_target = model_node
		if icon_sprite:
			icon_sprite.visible = false
	else:
		_effect_target = icon_sprite

	# Iniciar animación de salto y deslizamiento
	_animate_drop()

	# Usar delay personalizado si se proporciona, si no usar el default
	var effective_delay = custom_delay if custom_delay > 0.0 else pickup_delay
	# Timer para permitir pickup después del delay
	await get_tree().create_timer(effective_delay).timeout
	can_pickup = true

## Anima el drop: salto (Y) + deslizamiento horizontal (XZ)
func _animate_drop():
	var tween = create_tween()
	tween.set_parallel(true)

	# Fijo: altura y duración
	var DROP_HEIGHT := 1.5
	var DROP_DURATION := 0.35

	# Buscar el modelo 3D si existe (ignora icon_sprite y collision_shape)
	var model_node: Node3D = null
	for child in get_children():
		if child is Node3D and child != icon_sprite and child != collision_shape:
			model_node = child
			break

	var target_node = model_node if model_node else icon_sprite
	if target_node:
		var start_pos = target_node.position
		target_node.position.y = 0.0
		tween.tween_property(target_node, "position:y", DROP_HEIGHT, DROP_DURATION * 0.5)
		tween.tween_property(target_node, "position:y", 0.0, DROP_DURATION * 0.5).set_delay(DROP_DURATION * 0.5)

	# Deslizamiento horizontal (física del Area3D)
	var random_direction = Vector3(
		randf_range(-1.0, 1.0),
		0.0,
		randf_range(-1.0, 1.0)
	).normalized()
	var slide_target = global_position + random_direction * slide_distance
	tween.tween_property(self, "global_position", slide_target, DROP_DURATION).set_delay(0.0)

## Detecta cuando un cuerpo entra (jugador CharacterBody3D)
func _on_body_entered(body: Node3D):
	if not can_pickup or has_been_picked:
		return
	
	# Verificar si es el jugador
	if body.is_in_group("player"):
		_pickup_item()

## Recoge el item y lo añade al inventario del jugador
func _pickup_item():
	if has_been_picked:
		return
	
	if not player or not player.has_node("InventoryComponent"):
		return
	
	var inventory = player.get_node("InventoryComponent")
	
	# Intentar agregar el item al inventario
	if inventory.add_item(item_data, quantity):
		# Éxito: item agregado
		has_been_picked = true
		_is_attracting = false
		if collision_shape:
			collision_shape.set_deferred("disabled", true)
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		
		get_tree().call_group("hud", "show_pickup_message", item_data.item_name, quantity)
		call_deferred("queue_free")
	else:
		# Fallo: inventario lleno
		get_tree().call_group("hud", "add_log_message", "Inventario lleno!", Color.ORANGE)
		_is_attracting = false
		_pickup_fail_cooldown = 1.0 # Reintentar en 1 segundo
		return

## Devuelve información del drop para debugging
func get_drop_info() -> String:
	return "%sx%d" % [item_data.item_name, quantity]
