extends Button
# Asigna los nodos hijos aquí arrastrándolos con Ctrl
@onready var icon_rect = $HBoxContainer/TextureRect
@onready var name_label = $HBoxContainer/LabelName
@onready var price_label = $HBoxContainer/LabelPrice

var current_item: ItemData = null

func _ready():
	# Escuchar cuando se generen íconos 3D
	if not IconGenerator.icon_generated.is_connected(_on_icon_generated):
		IconGenerator.icon_generated.connect(_on_icon_generated)

func _on_icon_generated(item_data: ItemData, texture: Texture2D):
	# Si este slot muestra ese item, actualizar el ícono
	if current_item == item_data:
		icon_rect.texture = texture

func set_data(item: ItemData, is_buying: bool):
	current_item = item
	icon_rect.texture = IconGenerator.get_icon(item)
	name_label.text = item.item_name
	
	if is_buying:
		price_label.text = str(item.buy_price) + " Z" # Asumiendo que tienes buy_price
		price_label.modulate = Color.WHITE
	else:
		price_label.text = str(item.sell_price) + " Z"
		price_label.modulate = Color.GREEN # Verde porque ganas dinero
