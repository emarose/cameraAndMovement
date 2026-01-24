# Status Effect System - Usage Guide

## Overview
Status effects can now be applied through consumable items and enemy attacks. Enemies can also use skills with randomized behavior.

---

## Consumable Items with Status Effects

### Creating a Status Effect Item

1. **Create a new ConsumableItem resource**
2. **Set the effect type to `STATUS_EFFECT`**
3. **Assign the StatusEffectData resource**

### Example: Blessing Scroll
```
Item Name: Blessing Scroll
Effect Type: STATUS_EFFECT
Status Effect: Blessing.tres
Stackable: true
Max Stack: 10
```

### Available Buff Items
- **BlessingScroll.tres** - Grants Blessing buff (STR +5, DEX +5)
- **SpeedPotion.tres** - Grants Swift Step (AGI +8, +25% speed)
- **BerserkPill.tres** - Grants Power Surge (STR +5, ATK +15)

### Using in Game
Simply consume the item from inventory - the status effect will be automatically applied to the player.

---

## Enemy Status Effect Attacks

### Configuration in EnemyData

Enemies can now inflict status effects when they attack:

```gdscript
@export var attack_status_effects: Array[StatusEffectData] = []
@export var status_effect_chance: float = 0.15  # 15% per attack
```

### How It Works
1. Enemy performs a successful attack
2. Random roll against `status_effect_chance`
3. If successful, applies a random effect from `attack_status_effects` array
4. Player receives log message: "¡[Enemy] te infligió [Effect]!"

### Example Enemies

#### Venomous Spider (VenomousSpider.tres)
- Level 8 Insect
- Can inflict: **Poison** or **Slow Down**
- Status chance: 25%
- Strategy: Fast aggro, applies DoT and movement debuffs

#### Orc Warrior (OrcWarrior.tres)
- Level 12 Brute
- Can inflict: **Stun Shot**
- Status chance: 10%
- Can use skill: **Bash**
- Skill chance: 20%

---

## Enemy Skill Usage

### Configuration

Enemies can now use skills with randomized behavior:

```gdscript
@export var skills: Array[SkillData] = []
@export var skill_use_chance: float = 0.3  # 30% when in combat
```

### Skill Types Support
- **IMMEDIATE** - Instant cast (e.g., self-buffs, AoE)
- **TARGET** - Targeted at player
- **POINT** - Cast at player's location

### Behavior
1. Every combat update, enemy rolls against `skill_use_chance`
2. If successful and SP available, selects random skill
3. Casts appropriate to skill type
4. Respects cooldowns and SP costs

### Setup Requirements

Enemy scene needs:
- `SkillComponent` node
- `SPComponent` (auto-created if missing when enemy has skills)
- Skills assigned in EnemyData resource

---

## Integration Notes

### Automatic Setup
- Enemies with skills automatically get SPComponent in `_ready()` if missing
- SkillComponent is setup with proper references
- No manual configuration needed beyond assigning resources

### Status Effect Manager
Both items and enemy attacks use the same `StatusEffectManager` system:
- Consistent behavior
- Stacking rules apply
- Duration refresh on reapply
- Visual feedback via HUD

### Testing Tips

1. **Test Status Items:**
   - Add to inventory: `inventory.add_item(blessing_scroll, 5)`
   - Use from hotbar or inventory UI
   - Check stats panel for changes

2. **Test Enemy Effects:**
   - Create VenomousSpider enemy instance
   - Let it attack player
   - Watch for status notifications
   - Verify movement/stats changes

3. **Test Enemy Skills:**
   - Use OrcWarrior with Bash skill
   - Monitor SP usage
   - Check cooldown behavior
   - Observe skill randomness

---

## Performance Considerations

- Skill chance check happens per aggro update (not every frame)
- Random skill selection is lightweight (array filter + random)
- Status effects use existing manager (no extra overhead)
- SP auto-creation only for enemies with skills

---

## Future Extensions

### Easy Additions:
- More status effect items (antidote, cure, etc.)
- Enemy-specific skill patterns (boss phases)
- Skill combo systems
- Status resistance stats
- Immunity periods

### Example: Antidote Item
```gdscript
# ConsumableItem with custom logic
effect_type: CUSTOM
# Override use() method to remove poison/bleeding
```
