extends StaticBody3D

@export var npc_name: String = "Shop"
@export var interact_distance: float = 8.0 
@export var items_for_sale: Array[ItemData] = [] # Arrastra pociones, espadas, etc aquí

func interact(player: Node3D):
	var dist = global_position.distance_to(player.global_position)
	if dist <= interact_distance:
		_open_shop(player)
	else:
		get_tree().call_group("hud", "add_log_message", "Acércate más a %s" % npc_name, Color.GRAY)

func _open_shop(player):
	var shop_ui = get_tree().get_first_node_in_group("shop_ui")
	
	if shop_ui:
		var inv = player.get_node("InventoryComponent")
		shop_ui.open_shop(inv, items_for_sale)
	
