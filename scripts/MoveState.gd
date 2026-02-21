extends State
class_name MoveState

## Move state - character is moving
## Transitions to Idle state when velocity falls below threshold

@export var idle_threshold: float = 0.1

func enter():
	"""Called when entering move state"""
	# Animation will be handled by the StateMachine through AnimationTree
	pass

func update(_delta: float):
	"""Check if we should transition to Idle state"""
	if not entity:
		return

	# Highest priority: attack, cast, flinch
	if entity.is_attacking:
		state_machine.change_state("Attack")
		return
	if entity.is_casting:
		state_machine.change_state("Cast")
		return
	if entity.is_flinching:
		state_machine.change_state("Flinch")
		return
	
	# Check if entity has stopped moving
	var velocity = entity.velocity
	var horizontal_velocity = Vector2(velocity.x, velocity.z)
	
	# Transition to Idle if velocity falls below threshold
	if horizontal_velocity.length() <= idle_threshold:
		state_machine.change_state("Idle")
