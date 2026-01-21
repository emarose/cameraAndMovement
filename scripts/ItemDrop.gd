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

func _ready():
	body_entered.connect(_on_body_entered)
	player = get_tree().get_first_node_in_group("player")
	set_process(true)

func _process(delta):
	if not can_pickup or has_been_picked:
		return
	if not player or not is_instance_valid(player):
		return

	var dist_to_player = global_position.distance_to(player.global_position)
	if dist_to_player <= magnet_radius:
		_is_attracting = true

	if _is_attracting:
		var target_pos = player.global_position + Vector3(0, 0.6, 0)
		global_position = global_position.lerp(target_pos, clamp(magnet_speed * delta, 0.0, 1.0))
		if global_position.distance_to(target_pos) <= pickup_distance:
			_pickup_item()

## Configura el ItemDrop después de ser añadido al árbol y posicionado
func setup(p_item_data: ItemData, p_quantity: int):
	item_data = p_item_data
	quantity = p_quantity
	
	if not item_data:
		push_error("ItemDrop: No item_data asignado")
		queue_free()
		return
	
	initial_position = global_position
	
	# Asignar el icono del item al Sprite3D
	if icon_sprite and item_data.icon:
		icon_sprite.texture = item_data.icon

	# Iniciar animación de salto y deslizamiento
	_animate_drop()
	
	# Timer para permitir pickup después del delay
	await get_tree().create_timer(pickup_delay).timeout
	can_pickup = true

## Anima el drop: salto (Y) + deslizamiento horizontal (XZ)
func _animate_drop():
	var tween = create_tween()
	tween.set_parallel(true)  # Ejecutar animaciones en paralelo
	
	# Salto en el eje Y (visual del sprite)
	tween.tween_property(icon_sprite, "position:y", jump_height, jump_duration / 2)
	tween.tween_property(icon_sprite, "position:y", 0.0, jump_duration / 2).set_delay(jump_duration / 2)
	
	# Deslizamiento horizontal (física del Area3D)
	var random_direction = Vector3(
		randf_range(-1.0, 1.0),
		0.0,
		randf_range(-1.0, 1.0)
	).normalized()
	
	var slide_target = global_position + random_direction * slide_distance
	tween.tween_property(self, "global_position", slide_target, slide_duration).set_delay(0.0)

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
	has_been_picked = true
	_is_attracting = false
	# Usamos deferred para evitar modificar el estado mientras se procesan queries de física
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	if player and player.has_node("InventoryComponent"):
		var inventory = player.get_node("InventoryComponent")
		inventory.add_item(item_data, quantity)
		get_tree().call_group("hud", "show_pickup_message", item_data.item_name, quantity)
	
	call_deferred("queue_free")

## Devuelve información del drop para debugging
func get_drop_info() -> String:
	return "%sx%d" % [item_data.item_name, quantity]
