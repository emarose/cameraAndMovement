# Skill Level Scaling System Guide

## Overview
Skills now support level-based scaling for SP costs, damage, healing, stat buffs, and passive effects. This allows skills to become more powerful as the player levels them up through the skill tree.

## Key Features

### 1. **Level-Based SP Costs**
Skills can have dynamic SP costs that increase with skill level:
- `sp_cost_base`: Base SP cost at level 1
- `sp_cost_per_level`: Additional SP per skill level
- **Formula**: `SP Cost = sp_cost_base + (sp_cost_per_level × (SkillLevel - 1))`

**Example (Heal):**
```
sp_cost_base = 13
sp_cost_per_level = 2

Level 1: 13 SP
Level 5: 13 + (2 × 4) = 21 SP
Level 10: 13 + (2 × 9) = 31 SP
```

### 2. **Healing Skills**
Skills can now heal HP instead of dealing damage:
- `heals = true`: Marks this as a healing skill
- `heal_base`: Base healing amount
- `heal_per_level`: Additional healing per skill level
- `heal_int_scaling`: Healing from (BaseLV + INT) / 8 × factor
- `heal_base_level_scaling`: Healing from caster's base level
- `heal_target_max_hp_percent`: Percentage of target's max HP healed

**Example (Heal skill - based on RO formula):**
```gdscript
# Heal: [(BaseLV + INT) / 8] × (4 + 8 × SkillLV)
heals = true
heal_base = 0.0
heal_per_level = 8.0          # 8 × SkillLV
heal_int_scaling = 4.0         # 4 + 8×SkillLV factor
heal_base_level_scaling = 0.125  # (1/8) × BaseLV

# At Level 10 Heal, INT 50, BaseLV 40:
# Healing = [(40 + 50) / 8] × (4 + 8 × 10)
#         = 11.25 × 84
#         = 945 HP
```

### 3. **Stat Buffs**
Skills can apply temporary stat buffs:
- `applies_stat_buff = true`: Enable stat buffs
- `buff_str_per_level`: STR increase per skill level
- `buff_dex_per_level`: DEX increase per skill level
- `buff_int_per_level`: INT increase per skill level
- `buff_agi_per_level`: AGI increase per skill level
- `buff_vit_per_level`: VIT increase per skill level
- `buff_luk_per_level`: LUK increase per skill level
- `buff_duration`: Duration in seconds (0 = permanent via status effect)

**Example (Blessing):**
```gdscript
# Blessing: Increases STR, DEX, and INT by 1 × SkillLV
applies_stat_buff = true
buff_str_per_level = 1
buff_dex_per_level = 1
buff_int_per_level = 1
buff_duration = 60.0  # Lasts 60 seconds

# At Level 10 Blessing:
# +10 STR, +10 DEX, +10 INT for 60 seconds
```

### 4. **Enhanced Passive Skills**
Passive skills now scale properly per level:
- `passive_hp_regen`: Flat HP regeneration **PER LEVEL**
- `passive_sp_regen`: Flat SP regeneration **PER LEVEL**
- `passive_hp_regen_percent`: % HP regen **PER LEVEL** (0.002 = +0.2% per level)
- `passive_sp_regen_percent`: % SP regen **PER LEVEL**
- `passive_healing_item_bonus`: Healing item effectiveness **PER LEVEL** (0.1 = +10% per level)
- `passive_stat_bonuses`: Dictionary of stat bonuses **PER LEVEL**

**Example (HP Recovery):**
```gdscript
# HP Recovery: Heals (5 × SkillLV) + (MaxHP × 0.002 × SkillLV) per tick
# Also increases healing item effectiveness by 10% × SkillLV
is_passive = true
passive_stat_bonuses = {"vit": 1}  # +1 VIT per level
passive_hp_regen = 5                # +5 HP per level
passive_hp_regen_percent = 0.002    # +0.2% MaxHP per level
passive_healing_item_bonus = 0.1    # +10% healing items per level

# At Level 10 HP Recovery with 5000 Max HP:
# - Passive regen: 50 + (5000 × 0.02) = 150 HP per tick
# - Healing items: +100% effectiveness (2× healing)
# - +10 VIT
```

### 5. **Damage Scaling**
Damage skills can scale with level:
- `damage_per_level`: Additional damage multiplier per level
- **Formula**: `Damage Multiplier = damage_multiplier + (damage_per_level × (SkillLevel - 1))`

**Example (Bash):**
```gdscript
damage_multiplier = 1.5
damage_per_level = 0.2

Level 1: ATK × 1.5
Level 5: ATK × (1.5 + 0.2 × 4) = ATK × 2.3
Level 10: ATK × (1.5 + 0.2 × 9) = ATK × 3.3
```

## Implementation Examples

### Creating a Heal Skill
```gdscript
# resources/skills/Heal.tres
id = "heal"
skill_name = "Heal"
type = 2  # SELF
sp_cost_base = 13
sp_cost_per_level = 2
heals = true
heal_base = 0.0
heal_per_level = 8.0
heal_int_scaling = 4.0
heal_base_level_scaling = 0.125
cooldown = 3.0
max_level = 10
```

### Creating a Buff Skill
```gdscript
# resources/skills/Blessing.tres
id = "blessing"
skill_name = "Blessing"
type = 2  # TARGET (can target allies)
sp_cost_base = 28
sp_cost_per_level = 3
applies_stat_buff = true
buff_str_per_level = 1
buff_dex_per_level = 1
buff_int_per_level = 1
buff_duration = 60.0
max_level = 10
```

### Creating a Passive Skill
```gdscript
# resources/skills/HPRecovery.tres
id = "hp_recovery"
skill_name = "HP Recovery"
is_passive = true
sp_cost = 0
passive_stat_bonuses = {"vit": 1}
passive_hp_regen = 5
passive_hp_regen_percent = 0.002
passive_healing_item_bonus = 0.1
max_level = 10
required_job_level = 5
```

## System Architecture

### Skill Level Tracking
- Skill levels are stored in `GameManager.player_stats["learned_skills"]`
- Format: `{"skill_id": level}` (e.g., `{"heal": 5, "blessing": 3}`)
- Players learn/level up skills through the Skill Tree UI

### Automatic Scaling
The `SkillComponent` automatically:
1. Retrieves the current skill level from GameManager
2. Calculates SP cost based on level
3. Calculates damage/healing based on level
4. Applies buffs with level-appropriate strength

### Player vs Enemy Behavior
- **Players**: Use skills at their learned level with SP costs
- **Enemies**: Use skills at max level without SP costs

## Healing Item Bonus System

The `passive_healing_item_bonus` field affects consumable healing items:

```gdscript
# HP Recovery at Level 10 gives +100% healing from items
passive_healing_item_bonus = 0.1  # +10% per level

# A Red Potion that normally heals 100 HP:
# With Level 10 HP Recovery: 100 × (1 + 1.0) = 200 HP
```

This bonus is applied in `ConsumableItem.use()` when using HP healing items.

## Formula Reference

### Heal Skill (Ragnarok Online style)
```
Healing = [(BaseLV + INT) / 8] × (4 + 8 × SkillLV)

In our system:
heal_base_level_scaling = 0.125  # (1/8)
heal_int_scaling = 4.0          # Base factor
heal_per_level = 8.0            # Per level factor
```

### HP Recovery Passive
```
HP Regen = (5 × SkillLV) + (MaxHP × 0.002 × SkillLV) per tick
Healing Item Bonus = 10% × SkillLV

In our system:
passive_hp_regen = 5
passive_hp_regen_percent = 0.002
passive_healing_item_bonus = 0.1
```

### Blessing Buff
```
STR/DEX/INT increase = 1 × SkillLV
Duration = 60 seconds

In our system:
buff_str_per_level = 1
buff_dex_per_level = 1
buff_int_per_level = 1
buff_duration = 60.0
```

## Testing Your Skills

1. **Learn the skill** through the Skill Tree UI (press K)
2. **Check SP cost** - should match the formula
3. **Use the skill** - effects should scale with your skill level
4. **Level up the skill** - effects should increase

## Notes

- Skills with `heals = true` can target self or allies (won't damage enemies)
- Passive skills apply their bonuses automatically when learned
- Stat buffs currently apply directly (TODO: integrate with StatusEffectData for timed buffs)
- The system supports mixing healing, damage, buffs, and status effects in one skill

## Future Enhancements

- [ ] Dynamic StatusEffect creation for stat buffs with durations
- [ ] AoE healing skills (heal multiple allies)
- [ ] Conditional scaling (e.g., extra healing on undead enemies)
- [ ] Skill synergies (bonus effects when multiple skills are learned)
