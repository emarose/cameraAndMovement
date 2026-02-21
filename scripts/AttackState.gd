extends State
class_name AttackState

## Attack state - character is attacking
## Returns to Move/Idle when attack finishes

@export var move_threshold: float = 0.1

func enter():
	"""Called when entering attack state"""
	# Animation handled by StateMachine through AnimationTree
	pass

func update(_delta: float):
	if not entity:
		return
	
	# Allow the attack to finish even if a flinch is queued
	if entity.is_casting:
		state_machine.change_state("Cast")
		return
	
	if entity.is_attacking:
		return
	
	var velocity = entity.velocity
	var horizontal_velocity = Vector2(velocity.x, velocity.z)
	if horizontal_velocity.length() > move_threshold:
		state_machine.change_state("Move")
	else:
		state_machine.change_state("Idle")
