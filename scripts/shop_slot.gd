extends Button
# Asigna los nodos hijos aquí arrastrándolos con Ctrl
@onready var icon_rect = $HBoxContainer/TextureRect
@onready var name_label = $HBoxContainer/LabelName
@onready var price_label = $HBoxContainer/LabelPrice

func set_data(item: ItemData, is_buying: bool):
	icon_rect.texture = item.icon
	name_label.text = item.item_name
	
	if is_buying:
		price_label.text = str(item.buy_price) + " Z" # Asumiendo que tienes buy_price
		price_label.modulate = Color.WHITE
	else:
		price_label.text = str(item.sell_price) + " Z"
		price_label.modulate = Color.GREEN # Verde porque ganas dinero
