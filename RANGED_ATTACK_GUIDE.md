# Ranged Attack System Implementation Guide

This guide explains how to use the ranged attack system for equipment items in your Godot game.

## Overview

The ranged attack system allows weapons to have different attack ranges and shoot projectiles instead of performing melee attacks. The system automatically detects if a weapon is ranged and handles the appropriate attack behavior.

## How It Works

### 1. Equipment Item Setup

The `EquipmentItem` class has three key properties for ranged weapons:

```gdscript
@export var is_ranged: bool = false           # Mark weapon as ranged
@export var attack_range: float = 1.5         # Custom attack range
@export var projectile_scene: PackedScene     # Projectile to spawn
```

### 2. Attack Range Calculation

The player now uses `get_effective_attack_range()` which:
- Checks if a weapon is equipped
- Returns the weapon's `attack_range` if equipped
- Falls back to the player's base `attack_range` if no weapon is equipped

### 3. Attack Execution

When attacking, the system:
1. Checks if the equipped weapon is ranged
2. **Ranged weapons**: Spawns a projectile using `_shoot_projectile()`
3. **Melee weapons**: Applies damage directly as before

## Creating a Ranged Weapon

### Step 1: Create a Projectile Scene

Example: `scenes/Arrow.tscn`

The projectile should have the `Projectile.gd` script attached. The base projectile class handles:
- Movement towards target
- Damage calculation with CombatMath
- Element and race bonuses
- Auto-destruction
- Hit detection

**Required Script Methods:**
```gdscript
func setup(target: Node3D, damage: int, shooter: Node3D) -> void
# OR
func set_target(target: Node3D) -> void
```

### Step 2: Create an Equipment Resource

Example: `resources/items/HunterBow.tres`

```gdscript
[resource]
script = ExtResource("EquipmentItem.gd")
item_name = "Hunter's Bow"
description = "A longbow for ranged combat. +20 ATK, 8.0 range"
slot = 0  # WEAPON slot
atk_bonus = 20
is_ranged = true              # Mark as ranged
attack_range = 8.0            # Custom range
projectile_scene = ExtResource("Arrow.tscn")  # Reference projectile
```

### Step 3: Add to Game

Add the weapon to the player's initial inventory or place it in a shop/loot drop.

## Customizing Projectiles

### Basic Projectile Properties

```gdscript
@export var speed: float = 15.0          # Movement speed
@export var max_lifetime: float = 5.0   # Auto-destroy timer
@export var rotate_towards_target: bool = true  # Face target while moving
```

### Creating Custom Projectiles

You can extend the `Projectile` class to create custom behavior:

```gdscript
extends Projectile
class_name FireballProjectile

func _ready():
	super._ready()
	# Add particle effects, trails, etc.

func _on_hit_target():
	# Custom hit behavior (explosion, AoE, etc.)
	super._on_hit_target()  # Still call parent to apply damage
```

## Code Structure

### Files Modified

1. **`scripts/player.gd`**
   - Added `equipment_component` reference
   - Added `get_effective_attack_range()` method
   - Added `_shoot_projectile()` method
   - Modified `execute_attack()` to support ranged weapons
   - Updated movement code to use effective attack range

2. **`scripts/EquipmentItem.gd`** (already had the properties)
   - `is_ranged`: Boolean flag
   - `attack_range`: Float value
   - `projectile_scene`: PackedScene reference

### Files Created

1. **`scripts/Projectile.gd`** - Base projectile class
2. **`scenes/Arrow.tscn`** - Example arrow projectile
3. **`resources/items/HunterBow.tres`** - Example ranged weapon

## Example Usage

```gdscript
# The player code automatically handles ranged attacks:
# When execute_attack() is called:

var weapon = equipment_component.get_equipped_item(EquipmentItem.EquipmentSlot.WEAPON)
if weapon and weapon.is_ranged:
    var dist = global_position.distance_to(enemy.global_position)
    if dist <= weapon.attack_range:
        _shoot_projectile(enemy, weapon.projectile_scene)
else:
    # Melee attack logic
```

## Features

✅ **Dynamic Attack Range**: Each weapon can have its own range  
✅ **Ranged/Melee Detection**: Automatic behavior based on weapon type  
✅ **Projectile System**: Reusable projectile base class  
✅ **Damage Calculation**: Uses existing CombatMath system  
✅ **Element/Race Bonuses**: Full support for weapon elements  
✅ **Visual Feedback**: Floating damage text, combat log messages  
✅ **Fallback Support**: Works even without equipment component  

## Testing

1. Add the `HunterBow` to your inventory
2. Equip it via the equipment UI
3. Attack an enemy from a distance (up to 8.0 units)
4. The arrow projectile should spawn and fly to the target
5. Damage is calculated and applied on hit

## Troubleshooting

**Projectile doesn't spawn:**
- Check that `projectile_scene` is set in the equipment resource
- Verify the projectile scene path is correct
- Ensure `is_ranged = true` on the weapon

**No damage applied:**
- Verify target has a `HealthComponent`
- Check that projectile has `Projectile.gd` script attached
- Ensure `setup()` or `set_target()` is implemented

**Range doesn't work:**
- Check `attack_range` value on the weapon
- Verify `get_effective_attack_range()` is being called
- Test with different range values

## Future Enhancements

Possible additions:
- Projectile pooling for performance
- AoE projectiles (explosion on hit)
- Piercing projectiles (hit multiple enemies)
- Homing projectiles (curved trajectory)
- Charge attacks (hold to increase power)
- Ammo system (limited arrows/bullets)
