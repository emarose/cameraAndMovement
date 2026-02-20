extends Node
class_name State

## Base class for all states in the StateMachine
## Individual states should extend this class and override the methods

# Reference to the entity that owns this state
var entity: CharacterBody3D
# Reference to the parent state machine
var state_machine: StateMachine

func setup(p_entity: CharacterBody3D, p_state_machine: StateMachine):
	"""Called by StateMachine to initialize the state"""
	entity = p_entity
	state_machine = p_state_machine

func enter():
	"""Called when entering this state"""
	pass

func exit():
	"""Called when exiting this state"""
	pass

func update(delta: float):
	"""Called every physics frame while in this state"""
	pass
