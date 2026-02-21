# Animation Setup Guide for Weapon-Specific Animations

## Architecture Overview

Your animation system uses **two separate components** that work together:

1. **AnimationTree (StateMachine)** - Handles character states (Idle, Move, Cast, Flinch)
2. **AnimationPlayer** - Stores weapon-specific attack animations

## Setup Structure

### AnimationTree StateMachine States

Keep these **general states** in your AnimationTree:

```
StateMachine
├── Idle       → Generic idle animation
├── Move       → Generic walk/run animation  
├── Cast       → Spell casting animation
└── Flinch     → Hit reaction animation
```

**Do NOT include "Attack" in the StateMachine** - weapon attacks are handled separately.

### AnimationPlayer Animations

Store **weapon-specific animations** directly in your AnimationPlayer:

```
AnimationPlayer
├── idle              → Default idle
├── attack_1          → Default/fallback attack
│
├── sword_slash       → Sword attack
├── sword_overhead    → Heavy sword attack
│
├── bow_draw          → Bow draw animation
├── bow_release       → Bow shoot animation
│
├── dagger_stab       → Dagger stab
├── dagger_slash      → Dagger slash
│
├── staff_channel     → Staff charge up
└── staff_cast        → Staff release
```

## Step-by-Step Setup

### 1. Open Your Character Model in Godot

Navigate to: `assets/characters/mannequin_medium.tscn` (or your character model)

### 2. Configure AnimationPlayer

1. Select the **AnimationPlayer** node
2. Import/create animations for each weapon type
3. Name them descriptively (e.g., `bow_draw`, `sword_slash`)

**Important:** Use lowercase with underscores, matching what you put in weapon resources

### 3. Configure AnimationTree

1. Select the **AnimationTree** node
2. In the AnimationTree panel (bottom), ensure your StateMachine has:
   - `Idle` state
   - `Move` state
   - `Cast` state
   - `Flinch` state

3. **Remove "Attack" state** if it exists (attacks bypass the state machine)

### 4. Set Up Weapon Resources

For each weapon, configure the animation names:

**Melee Weapon Example:**
```gdscript
# resources/items/IronSword.tres
idle_animation = &"idle"
attack_start_animation = &"sword_slash"
attack_release_animation = &"sword_slash"
```

**Ranged Weapon Example:**
```gdscript
# resources/items/HunterBow.tres
idle_animation = &"idle"
attack_start_animation = &"bow_draw"
attack_release_animation = &"bow_release"
```

## How It Works

### Normal Movement (StateMachine Control)

When the player is moving around normally:
- StateMachine controls animations via `state_machine_playback.travel()`
- Transitions: Idle ↔ Move ↔ Cast ↔ Flinch

### During Attack (AnimationPlayer Override)

When the player attacks:
1. **Code takes over animation control**
2. Plays weapon-specific animation: `animation_player.play("bow_draw")`
3. After attack completes, StateMachine resumes control
4. Returns to Idle or Move state

### Code Flow

```gdscript
# In execute_attack():
if weapon.attack_start_animation != "":
    animation_player.play(weapon.attack_start_animation)  # Direct play, bypasses StateMachine

await get_tree().create_timer(attack_hit_delay).timeout

if is_ranged:
    animation_player.play(weapon.attack_release_animation)  # Shoot animation
else:
    animation_player.play(weapon.attack_release_animation)  # Melee hit animation

# After attack finishes, StateMachine automatically returns to Idle/Move
```

## Common Animation Naming Conventions

### Swords
- `sword_slash_1`, `sword_slash_2` - Basic attacks
- `sword_overhead` - Heavy attack
- `sword_thrust` - Stab attack

### Bows
- `bow_draw` - Pull back arrow
- `bow_release` - Release arrow
- `bow_idle` - Holding bow

### Daggers
- `dagger_stab` - Quick stab
- `dagger_slash` - Slash attack
- `dagger_backstab` - Critical attack

### Staves
- `staff_idle` - Holding staff
- `staff_channel` - Charge spell
- `staff_cast` - Release spell
- `staff_slam` - Melee attack with staff

### Axes
- `axe_swing` - Horizontal swing
- `axe_overhead` - Vertical chop
- `axe_spin` - Spin attack

## Debugging Tips

### Error: "Animation not found: bow_draw"

**Problem:** Animation exists in StateMachine but not in AnimationPlayer

**Solution:** 
1. Open your character model scene
2. Select AnimationPlayer node
3. Check the animation list - is "bow_draw" there?
4. If not, you need to create/import it as a regular animation

### Error: "Animation not found: Attack"

**Problem:** Code is trying to use a fallback animation that doesn't exist

**Solution:**
- Create a generic `attack_1` animation in AnimationPlayer
- Or update the fallback in the code to use an animation you have

### Animations Play But Look Wrong

**Problem:** Animation exists but doesn't look right for the weapon

**Solution:**
- Adjust timing: `attack_hit_delay` and `attack_animation_duration` in Player inspector
- Match these values to your actual animation lengths
- Test with different values until it feels right

## Advanced: Animation Blending

If you want smooth transitions between weapon stances:

### Option A: Blend Tree (Complex)
- Use AnimationTree's BlendSpace2D
- Blend between weapon idle poses
- More setup, smoother results

### Option B: CrossFade (Simple)
- Use `animation_player.play()` with custom blend time
- Quick transitions between attacks
- Less setup required

Example:
```gdscript
animation_player.play("bow_draw", -1, 1.0, false)  # No blend
animation_player.play("bow_draw", 0.2, 1.0, false)  # 0.2s blend
```

## Testing Your Setup

1. **Create a test weapon** with known animation names:
   ```gdscript
   attack_start_animation = &"attack_1"
   attack_release_animation = &"attack_1"
   ```

2. **Verify the animation exists** in AnimationPlayer

3. **Equip and attack** - it should work

4. **Add weapon-specific animations** once the basic setup works

5. **Update weapon resources** to use new animation names

## File Checklist

- [ ] Character model has AnimationPlayer with weapon animations
- [ ] AnimationTree StateMachine has Idle, Move, Cast, Flinch (NO Attack state)
- [ ] Each weapon resource has animation names set
- [ ] Animation names in weapons match AnimationPlayer animation names exactly
- [ ] Code has proper error handling (checks `has_animation()`)

## Summary

**Split Responsibilities:**
- **StateMachine** = Movement states (Idle, Move, Cast, Flinch)
- **AnimationPlayer** = Weapon-specific attack animations

**During Normal Play:** StateMachine controls everything  
**During Attack:** Code plays weapon animation directly, then returns to StateMachine

This gives you the best of both worlds: smooth state transitions for movement, and flexible weapon-specific attack animations.
