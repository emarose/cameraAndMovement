extends ItemData
class_name ConsumableItem

enum ConsumableType { HEAL_HP, HEAL_SP, BUFF_STAT }
enum TargetType { SELF, ENEMY, ALLY }

@export_group("Efecto Consumible")
@export var effect_type: ConsumableType = ConsumableType.HEAL_HP
@export var target_type: TargetType = TargetType.SELF
@export var amount: int = 0 # Cuánto cura o buffea
@export var duration: float = 0.0 # Si es buff

# Sobrescribimos la función use
func use(user: Node, target = null) -> bool:
	# 1. Validar objetivo
	var final_target = user
	if target_type != TargetType.SELF and target != null:
		final_target = target
	
	# 2. Aplicar efecto
	match effect_type:
		ConsumableType.HEAL_HP:
			if final_target.has_node("HealthComponent"):
				final_target.get_node("HealthComponent").heal(amount)
				_create_feedback(user, "HP +%d" % amount, Color.GREEN)
				return true # Éxito
				
		ConsumableType.HEAL_SP:
			if final_target.has_node("SPComponent"):
				final_target.get_node("SPComponent").restore_sp(amount)
				_create_feedback(user, "SP +%d" % amount, Color.BLUE)
				return true

	return false # Si falla algo, devolvemos false para no gastar el item

func _create_feedback(user, text, color):
	# Si tienes un sistema de log centralizado:
	user.get_tree().call_group("hud", "add_log_message", text, color)
