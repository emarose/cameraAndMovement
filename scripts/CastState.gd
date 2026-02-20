extends State
class_name CastState

## Cast state - character is casting a skill
## Returns to Move/Idle when casting finishes

@export var move_threshold: float = 0.1

func enter():
	"""Called when entering cast state"""
	# Animation handled by StateMachine through AnimationTree
	pass

func update(delta: float):
	if not entity:
		return
	
	# Flinch overrides cast
	if entity.is_flinching:
		state_machine.change_state("Flinch")
		return
	
	if entity.is_casting:
		return
	
	var velocity = entity.velocity
	var horizontal_velocity = Vector2(velocity.x, velocity.z)
	if horizontal_velocity.length() > move_threshold:
		state_machine.change_state("Move")
	else:
		state_machine.change_state("Idle")
