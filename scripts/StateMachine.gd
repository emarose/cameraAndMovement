extends Node
class_name StateMachine

## Generic State Machine that manages states and transitions
## Works with both Player and Enemy entities

# Reference to the entity (Player or Enemy)
var entity: CharacterBody3D
# Reference to the AnimationTree for playing animations
var animation_tree: AnimationTree
# Reference to the AnimationState machine within the tree
var state_machine_playback: AnimationNodeStateMachinePlayback

# Dictionary of available states
var states: Dictionary = {}
# Current active state
var current_state: State

# Signal emitted when state changes
signal state_changed(old_state: String, new_state: String)

func _ready():
	# Wait for entity to be set before initializing
	pass

func setup(p_entity: CharacterBody3D, p_animation_tree: AnimationTree):
	"""Initialize the state machine with entity and animation tree"""
	entity = p_entity
	animation_tree = p_animation_tree
	
	if animation_tree:
		animation_tree.active = true
		state_machine_playback = animation_tree.get("parameters/StateMachine/playback")
	
	# Initialize all child states
	for child in get_children():
		if child is State:
			states[child.name] = child
			child.setup(entity, self)
	
	# Start with the first state if available
	if states.size() > 0:
		var first_state = states.values()[0]
		change_state(first_state.name)

func _physics_process(delta):
	if current_state:
		current_state.update(delta)

func change_state(new_state_name: String):
	"""Change to a new state by name"""
	if not states.has(new_state_name):
		push_warning("State %s not found in StateMachine" % new_state_name)
		return
	
	var old_state_name: String
	if current_state:
		old_state_name = str(current_state.name)
	else:
		old_state_name = "none"

	
	# Exit current state
	if current_state:
		current_state.exit()
	
	# Enter new state
	current_state = states[new_state_name]
	current_state.enter()
	
	# Update animation if we have a state machine playback
	if state_machine_playback:
		state_machine_playback.travel(new_state_name)
	
	# Emit signal
	state_changed.emit(old_state_name, new_state_name)

func get_current_state_name() -> String:
	"""Returns the name of the current state"""
	return str(current_state.name) if current_state else ""
