extends State
class_name FlinchState

## Flinch state - character was hit
## Returns to Cast/Attack/Move/Idle when flinch ends

@export var move_threshold: float = 0.1

func enter():
	"""Called when entering flinch state"""
	# Animation handled by StateMachine through AnimationTree
	pass

func update(delta: float):
	if not entity:
		return
	
	if entity.is_flinching:
		return
	
	if entity.is_casting:
		state_machine.change_state("Cast")
		return
	if entity.is_attacking:
		state_machine.change_state("Attack")
		return
	
	var velocity = entity.velocity
	var horizontal_velocity = Vector2(velocity.x, velocity.z)
	if horizontal_velocity.length() > move_threshold:
		state_machine.change_state("Move")
	else:
		state_machine.change_state("Idle")
