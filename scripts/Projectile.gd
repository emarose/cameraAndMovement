extends Node3D
class_name Projectile

## Base projectile class for ranged attacks
## Handles movement towards target and damage application

@export var speed: float = 15.0
@export var max_lifetime: float = 5.0  # Auto-destroy after this time
@export var rotate_towards_target: bool = true

var target: Node3D = null
var damage: int = 0
var shooter: Node3D = null
var lifetime: float = 0.0

func _ready():
	# Auto-destroy after max_lifetime to prevent orphaned projectiles
	await get_tree().create_timer(max_lifetime).timeout
	if is_instance_valid(self):
		queue_free()

## Setup the projectile with target, damage, and shooter info
func setup(p_target: Node3D, p_damage: int, p_shooter: Node3D) -> void:
	target = p_target
	damage = p_damage
	shooter = p_shooter
	
	# Face the target initially
	if target and is_instance_valid(target):
		look_at(target.global_position, Vector3.UP)

## Alternative setup method for simpler projectiles
func set_target(p_target: Node3D) -> void:
	target = p_target
	if target and is_instance_valid(target):
		look_at(target.global_position, Vector3.UP)

func _physics_process(delta: float) -> void:
	lifetime += delta
	
	# Check if target is still valid
	if not target or not is_instance_valid(target):
		queue_free()
		return
	
	# Move towards target
	var direction = (target.global_position - global_position).normalized()
	global_position += direction * speed * delta
	
	# Optionally rotate to face target
	if rotate_towards_target:
		look_at(target.global_position, Vector3.UP)
	
	# Check if we've reached the target
	var distance_to_target = global_position.distance_to(target.global_position)
	if distance_to_target < 0.5:  # Hit threshold
		_on_hit_target()

## Called when projectile hits the target
func _on_hit_target() -> void:
	if not target or not is_instance_valid(target):
		queue_free()
		return
	
	# Apply damage if target has HealthComponent
	var health_component = target.get_node_or_null("HealthComponent")
	if health_component and health_component.has_method("take_damage"):
		# Calculate final damage using CombatMath if shooter has stats
		var final_damage = damage
		
		if shooter and shooter.has_node("StatsComponent"):
			var shooter_stats = shooter.get_node("StatsComponent")
			var target_stats = target.get_node_or_null("StatsComponent")
			
			if shooter_stats:
				# Use CombatMath for element/race bonuses
				final_damage = CombatMath.calculate_final_damage(
					damage,
					shooter_stats,
					target_stats,
					-1  # Use weapon element
				)
		
		# Apply target defense if it has EnemyData
		if target.has_node("../") and target.get("data"):
			var enemy_data = target.data
			if enemy_data:
				final_damage = max(1, final_damage - enemy_data.def)
		
		health_component.take_damage(final_damage)
		
		# Spawn floating text
		if shooter and shooter.has_method("spawn_floating_text"):
			shooter.spawn_floating_text(target.global_position, final_damage, false)
	
	# Destroy the projectile
	queue_free()
