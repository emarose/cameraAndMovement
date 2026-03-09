# Animation State Machine Guide

## Overview

This project uses a reusable state machine system that works with both the Player and enemies. The state machine automatically handles animation transitions through Godot's AnimationTree.

## Current Implementation

### State Machine Components

1. **StateMachine.gd** - Core state machine that manages states and transitions
2. **State.gd** - Base class that all states inherit from
3. **IdleState.gd** - Handles idle/standing animations
4. **MoveState.gd** - Handles walking/running animations

### How It Works

The state machine is velocity-based:
- **Idle → Move**: When the character's horizontal velocity exceeds 0.1 units/sec
- **Move → Idle**: When the character's horizontal velocity falls below 0.1 units/sec

The state machine automatically plays the correct animation through the AnimationTree's state machine playback.

## Adding New Animations & States

### Step 1: Create the Animation State Script

Create a new script in `scripts/` folder (e.g., `AttackState.gd`):

```gdscript
extends State
class_name AttackState

## Attack state - character is performing an attack

func enter():
	"""Called when entering attack state"""
	# You can add additional logic here
	# Animation is automatically handled by StateMachine
	pass

func exit():
	"""Called when exiting attack state"""
	# Clean up any attack-specific state
	pass

func update(delta: float):
	"""Called every physics frame while in attack state"""
	if not entity:
		return
	
	# Add your transition logic here
	# For example, check if attack animation finished:
	# if entity.attack_finished:
	#     state_machine.change_state("Idle")
	pass
```

### Step 2: Add Animation to AnimationTree

1. Open `assets/characters/mannequin_medium.tscn`
2. Select the AnimationTree node
3. In the Animation panel:
   - Add your new animation (e.g., "Player/Attack_A") to the AnimationLibrary
   - Add a new state to the AnimationNodeStateMachine
   - Create transitions between states

### Step 3: Add State to Scene

For **Player** (`scenes/Player.tscn`):
1. Add an ExtResource for your new state script:
   ```
   [ext_resource type="Script" path="res://scripts/AttackState.gd" id="24_attackstate"]
   ```
2. Add the state node as a child of StateMachine:
   ```
   [node name="Attack" type="Node" parent="StateMachine"]
   script = ExtResource("24_attackstate")
   ```

For **Enemy** (`scenes/Enemy.tscn`):
- Follow the same pattern

### Step 4: Trigger State Transitions

In your player or enemy script, call the state machine to change states:

```gdscript
# In player.gd or enemy.gd
func execute_attack(target):
	# Change to attack state
	if state_machine:
		state_machine.change_state("Attack")
	
	# Your attack logic...
```

## Example: Adding a Death State

### 1. Create DeathState.gd:

```gdscript
extends State
class_name DeathState

var death_timer: float = 0.0
var death_duration: float = 2.0  # How long death animation lasts

func enter():
	# Disable entity's collision
	if entity.has_node("CollisionShape3D"):
		entity.get_node("CollisionShape3D").disabled = true
	death_timer = 0.0

func update(delta: float):
	death_timer += delta
	
	# After death animation completes, you could:
	# - Queue free the entity
	# - Respawn
	# - Show game over screen, etc.
	if death_timer >= death_duration:
		# Handle death completion
		pass
```

### 2. Add to Scenes:

**Player.tscn** and **Enemy.tscn**:
```
[ext_resource type="Script" path="res://scripts/DeathState.gd" id="25_deathstate"]

[node name="Death" type="Node" parent="StateMachine"]
script = ExtResource("25_deathstate")
```

### 3. Trigger on Death:

In the death handler:
```gdscript
func _on_player_death():
	is_dead = true
	if state_machine:
		state_machine.change_state("Death")
	# Rest of death logic...
```

## Advanced: Conditional Transitions

You can make states smarter by checking multiple conditions:

```gdscript
extends State
class_name CombatIdleState

func update(delta: float):
	if not entity:
		return
	
	# Check for different transitions
	var velocity = entity.velocity
	var horizontal_velocity = Vector2(velocity.x, velocity.z)
	
	# Is moving?
	if horizontal_velocity.length() > 0.1:
		state_machine.change_state("Move")
		return
	
	# Is attacking?
	if entity.is_attacking:
		state_machine.change_state("Attack")
		return
	
	# Is casting?
	if entity.skill_component and entity.skill_component.is_casting:
		state_machine.change_state("Cast")
		return
```

## Tips

1. **Keep states focused**: Each state should handle one animation/behavior
2. **Use signals**: States can emit signals for game logic events
3. **Export variables**: Use @export in state scripts for designer-friendly tuning
4. **State names must match**: The state node name in the scene tree must match the animation state name in the AnimationTree

## Debugging

To see which state is currently active:
```gdscript
print("Current animation state: ", state_machine.get_current_state_name())
```

You can also listen to state changes:
```gdscript
state_machine.state_changed.connect(_on_state_changed)

func _on_state_changed(old_state: String, new_state: String):
	print("State changed from %s to %s" % [old_state, new_state])
```
