extends State
class_name IdleState

## Idle state - character is standing still
## Transitions to Move state when velocity > threshold

@export var move_threshold: float = 0.1

func enter():
	"""Called when entering idle state"""
	# Animation will be handled by the StateMachine through AnimationTree
	pass

func update(_delta: float):
	"""Check if we should transition to Move state"""
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
	
	# Check if entity is moving
	var velocity = entity.velocity
	var horizontal_velocity = Vector2(velocity.x, velocity.z)
	
	# Transition to Move if velocity exceeds threshold
	if horizontal_velocity.length() > move_threshold:
		state_machine.change_state("Move")
