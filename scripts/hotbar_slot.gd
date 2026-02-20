extends Control
class_name HotbarSlot

signal slot_hover(resource: Resource)
signal slot_exit

@onready var shortcut_label = $ShortcutLabel
@onready var cooldown_overlay: TextureProgressBar = $TextureProgressBar
@onready var icon_rect: TextureRect = $Icon
@onready var amount_label = $AmountLabel

var current_skill_name: String = ""
var current_content: Resource = null

var slot_index: int = 0
var parent_hud = null # Referencia al HUD para callbacks
var _last_click_time: float = 0.0
var _double_click_threshold: float = 0.3 # Tiempo máximo entre clicks para doble click

func _ready():
	mouse_entered.connect(_on_mouse_enter)
	mouse_exited.connect(_on_mouse_exit)
	
	# Escuchar cuando se generen íconos 3D
	if not IconGenerator.icon_generated.is_connected(_on_icon_generated):
		IconGenerator.icon_generated.connect(_on_icon_generated)

func setup(index: int, key_text: String):
	slot_index = index
	shortcut_label.text = key_text
	clear_slot()

func _on_mouse_enter():
	if current_content:
		slot_hover.emit(current_content)

func _on_mouse_exit():
	slot_exit.emit()
	
func _on_icon_generated(item_data: ItemData, texture: Texture2D):
	# Si este slot muestra ese item, actualizar el ícono
	if current_content == item_data:
		icon_rect.texture = texture
	
func update_slot(resource, amount: int = 0):
	if resource == null:
		clear_slot()
		return
	
	current_content = resource
	icon_rect.visible = true
	
	# Handle SkillData
	if resource is SkillData:
		current_skill_name = resource.skill_name
		if resource.icon:
			icon_rect.texture = resource.icon
			icon_rect.self_modulate = Color.WHITE
		else:
			icon_rect.texture = null 
			icon_rect.self_modulate = Color.CADET_BLUE
		# Skills don't have amounts
		amount_label.visible = false
			
	# Handle ItemData	
	elif resource is ItemData:
		current_skill_name = resource.item_name
		var item_icon = IconGenerator.get_icon(resource)
		if item_icon:
			icon_rect.texture = item_icon
			icon_rect.self_modulate = Color.WHITE
		else:
			icon_rect.texture = null
			icon_rect.self_modulate = Color.LIGHT_GRAY
		
		# Show amount for stackable items
		if amount > 1:
			amount_label.visible = true
			amount_label.text = str(amount)
		else:
			amount_label.visible = false
		
func clear_slot():
	current_skill_name = ""
	current_content = null
	icon_rect.texture = null
	amount_label.visible = false
	# Asegúrate de ocultar el progreso al limpiar
	cooldown_overlay.visible = false 
	cooldown_overlay.value = 0

func start_cooldown_visual(duration: float):
	cooldown_overlay.max_value = duration
	cooldown_overlay.value = duration
	cooldown_overlay.visible = true
	
	# Creamos un Tween para animar el valor hasta 0
	var tween = create_tween()
	tween.tween_property(cooldown_overlay, "value", 0.0, duration).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(func(): cooldown_overlay.visible = false)

# --- INPUT HANDLING ---

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var current_time = Time.get_ticks_msec() / 1000.0
			
			# Detectar doble click
			if current_time - _last_click_time < _double_click_threshold:
				_on_double_click()
			
			_last_click_time = current_time

func _on_double_click():
	if not current_content:
		return
	
	# Obtener referencia al jugador
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	# Ejecutar según el tipo de contenido
	if current_content is SkillData:
		# Armar la skill como si presionara el shortcut
		player._on_skill_shortcut_pressed(current_content)
	elif current_content is ItemData:
		# Consumir el item como si presionara el shortcut
		player._consume_item_from_inventory(current_content)

# --- DRAG AND DROP DESDE INVENTARIO Y HOTBAR ---

# Permitir arrastrar este slot si tiene contenido
func _get_drag_data(_at_position):
	if not current_content:
		return null
	
	# Crear vista previa
	var preview_texture = TextureRect.new()
	if icon_rect.texture:
		preview_texture.texture = icon_rect.texture
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.custom_minimum_size = Vector2(40, 40)
	
	var preview_control = Control.new()
	preview_control.add_child(preview_texture)
	preview_texture.position = -0.5 * preview_texture.custom_minimum_size
	
	set_drag_preview(preview_control)
	
	# Retornar datos con source "hotbar"
	var data = {
		"source": "hotbar",
		"origin_slot_index": slot_index,
		"content": current_content
	}
	return data

# Aceptar items arrastrados del inventario o de otros slots del hotbar
func _can_drop_data(_at_position, data):
	if typeof(data) == TYPE_DICTIONARY and data.has("source"):
		# Desde inventario: solo consumibles
		if data["source"] == "inventory":
			var item = data.get("item")
			if item and item is ItemData:
				return item.item_type == ItemData.ItemType.CONSUMABLE
		# Desde hotbar: siempre permitir swap
		elif data["source"] == "hotbar":
			return true
		# Desde skills: siempre permitir
		elif data["source"] == "skill":
			return true
	return false

# Soltar item en el slot del hotbar
func _drop_data(_at_position, data):
	# CASO 1: Viene del inventario
	if data["source"] == "inventory":
		var item = data.get("item")
		
		if not item or item.item_type != ItemData.ItemType.CONSUMABLE:
			# Rechazar si no es consumible
			if parent_hud and item:
				parent_hud.reject_non_consumable_item(item)
			return
		
		# Notificar al HUD para que maneje la lógica de duplicados
		if parent_hud:
			parent_hud.on_item_dropped_to_hotbar(slot_index, item)
	
	# CASO 2: Viene de otro slot del hotbar (swap)
	elif data["source"] == "hotbar":
		var origin_slot_index = data.get("origin_slot_index")
		
		# Si soltamos en el mismo slot, no hacer nada
		if origin_slot_index == slot_index:
			return
		
		# Llamar al HUD para hacer el swap
		if parent_hud:
			parent_hud.on_hotbar_slot_swap(origin_slot_index, slot_index)
	
	# CASO 3: Viene del árbol de skills
	elif data["source"] == "skill":
		# Llamamos a la función que ya creaste en el HUD
		var hud = get_tree().get_first_node_in_group("hud")
		if hud:
			# slot_index es una variable que tu slot debería tener (0 a 8)
			hud.on_skill_dropped_to_hotbar(self.slot_index, data["skill"])
