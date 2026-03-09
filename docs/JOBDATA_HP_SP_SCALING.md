# StatComponent Job-Based HP/SP Scaling System

## Overview

Updated `StatsComponent` to support job-based HP and SP growth mechanics. Each job now defines its own scaling parameters that determine how HP and SP grow with level and base stats.

## JobData Properties (Added)

### HP Configuration
```gdscript
@export var base_hp: int = 40         # Base HP at level 1
@export var hp_growth: int = 5        # Additional HP per level
@export var vit_hp_factor: int = 15   # HP bonus per VIT point
```

### SP Configuration
```gdscript
@export var base_sp: int = 10         # Base SP at level 1
@export var sp_growth: int = 2        # Additional SP per level
@export var int_sp_factor: int = 10   # SP bonus per INT point
```

## HP/SP Calculation Formulas

### Maximum HP
```
MaxHP = base_hp + (hp_growth × Level) + (Total VIT × vit_hp_factor)
```

**Examples:**
- **Novice at Level 1, VIT 5**: 40 + (5 × 1) + (5 × 15) = 130 HP
- **Swordsman at Level 10, VIT 10**: 50 + (7 × 10) + (10 × 15) = 290 HP
- **Mage at Level 10, VIT 3**: 30 + (3 × 10) + (3 × 15) = 105 HP

### Maximum SP
```
MaxSP = base_sp + (sp_growth × Level) + (Total INT × int_sp_factor)
```

**Examples:**
- **Novice at Level 1, INT 5**: 10 + (2 × 1) + (5 × 10) = 62 SP
- **Mage at Level 10, INT 15**: 40 + (5 × 10) + (15 × 10) = 240 SP
- **Swordsman at Level 10, INT 3**: 5 + (1 × 10) + (3 × 10) = 45 SP

## New Methods in StatsComponent

### `set_current_job(job_data: JobData) -> void`
Sets the current job and updates stats accordingly.

```gdscript
func set_current_job(job_data: JobData) -> void:
    current_job_data = job_data
    stats_changed.emit()
```

**Usage:**
```gdscript
# When player changes jobs
var job_data = load("res://resources/jobs/Swordsman.tres")
player_stats.set_current_job(job_data)
```

### `get_max_hp() -> int`
Calculates maximum HP based on current job and stats.

```gdscript
func get_max_hp() -> int:
    if current_job_data:
        var hp = current_job_data.base_hp
        hp += current_job_data.hp_growth * current_level
        hp += get_total_vit() * current_job_data.vit_hp_factor
        return hp
    else:
        # Fallback if no job data
        return 40 + (5 * current_level) + (get_total_vit() * 15)
```

### `get_max_sp() -> int`
Calculates maximum SP based on current job and stats.

```gdscript
func get_max_sp() -> int:
    if current_job_data:
        var sp = current_job_data.base_sp
        sp += current_job_data.sp_growth * current_level
        sp += get_total_int() * current_job_data.int_sp_factor
        return sp
    else:
        # Fallback if no job data
        return 10 + (2 * current_level) + (get_total_int() * 10)
```

### `get_crit() -> int`
Calculates critical hit chance based on LUK.

```gdscript
func get_crit() -> int:
    return get_total_luk() / 3
```

**Examples:**
- LUK 30: 10% crit
- LUK 60: 20% crit
- LUK 99: 33% crit

### `get_hp_regen() -> int`
Natural HP regeneration per second.

```gdscript
func get_hp_regen() -> int:
    var base_regen = int(get_total_vit() / 5.0)
    var regen = int(base_regen * hp_regen_percent_mod) + hp_regen_flat_bonus
    return max(0, regen)
```

**Base calculation:** VIT / 5 (multiplied by modifiers and bonuses)

**Examples:**
- VIT 10: 2 HP/sec base
- VIT 10 with 100% mod + 5 flat: 2 × 1.0 + 5 = 7 HP/sec
- VIT 10 with 50% mod + 0 flat: 2 × 0.5 = 1 HP/sec

### `get_sp_regen() -> int`
Natural SP regeneration per second.

```gdscript
func get_sp_regen() -> int:
    var base_regen = int(get_total_int() / 6.0)
    var regen = int(base_regen * sp_regen_percent_mod) + sp_regen_flat_bonus
    return max(0, regen)
```

**Base calculation:** INT / 6 (multiplied by modifiers and bonuses)

**Examples:**
- INT 12: 2 SP/sec base
- INT 12 with 100% mod + 0 flat: 2 × 1.0 = 2 SP/sec
- INT 18 with 50% mod + HP Recovery bonus: 3 × 0.5 + passive bonus

## Job Configuration Examples

### Novice (Balanced)
```
base_hp = 40
hp_growth = 5
vit_hp_factor = 15

base_sp = 10
sp_growth = 2
int_sp_factor = 10
```

### Swordsman (Tank/Physical)
```
base_hp = 50        # +10 base HP
hp_growth = 7       # +2 per level
vit_hp_factor = 15

base_sp = 5         # Lower SP
sp_growth = 1
int_sp_factor = 10
```

### Mage (Magic Support)
```
base_hp = 30        # Lower HP
hp_growth = 3
vit_hp_factor = 15

base_sp = 40        # High base SP
sp_growth = 5       # +5 per level
int_sp_factor = 10
```

### Archer (Hybrid)
```
base_hp = 45
hp_growth = 6
vit_hp_factor = 15

base_sp = 15
sp_growth = 2
int_sp_factor = 10
```

### Priest (Support/Healer)
```
base_hp = 38
hp_growth = 4
vit_hp_factor = 15

base_sp = 35        # High SP for healing
sp_growth = 4
int_sp_factor = 10
```

## Integration with Existing Components

### HealthComponent
No changes needed. Calls `stats.get_max_hp()` automatically:

```gdscript
# In HealthComponent._ready()
if stats:
    max_health = stats.get_max_hp()
```

### SPComponent
No changes needed. Calls `stats.get_max_sp()` automatically:

```gdscript
# In SPComponent.setup()
if stats:
    max_sp = stats.get_max_sp()
```

## Fallback Behavior

If `current_job_data` is not set, both `get_max_hp()` and `get_max_sp()` fall back to generic formulas:

```gdscript
# Fallback HP: 40 + (5 × level) + (VIT × 15)
# Fallback SP: 10 + (2 × level) + (INT × 10)
```

This ensures compatibility even if a job isn't loaded.

## Natural Regeneration System

The regeneration system uses:
- **VIT** for HP regeneration (divided by 5 for balance)
- **INT** for SP regeneration (divided by 6 for balance)
- **Modifiers** (`hp_regen_percent_mod`, `sp_regen_percent_mod`) from passive skills
- **Flat bonuses** (`hp_regen_flat_bonus`, `sp_regen_flat_bonus`) from passive skills

### Example with HP Recovery Passive (Level 10)
```
Base VIT: 10
Passive bonus: +10 VIT (from passive_stat_bonuses)
Total VIT: 20

Base regen: 20 / 5 = 4 HP/sec
With 0.2 modifier (hp_regen_percent_mod × 1.002 per level = 1.02 at Lv10):
4 × 1.02 + 50 flat = 4 × 1.02 + 50 ≈ 54 HP/sec
```

## Testing Recommendations

1. **Job Change**: Switch jobs and verify HP/SP change correctly
2. **Level Up**: Gain a level and confirm HP/SP growth
3. **Stat Allocation**: Increase VIT/INT and verify HP/SP increase
4. **Passive Skills**: Enable HP Recovery and verify regeneration
5. **Compatibility**: Ensure HealthComponent and SPComponent work seamlessly

## Files Modified

- `resources/jobs/JobData.gd` - Added HP/SP growth fields
- `scripts/StatsComponent.gd` - Added new methods and job reference
- `resources/jobs/Novice.tres` - Added job-specific values
- `resources/jobs/Swordsman.tres` - Added job-specific values
- `resources/jobs/Mage.tres` - Added job-specific values
- `resources/jobs/Archer.tres` - Added job-specific values
- `resources/jobs/Priest.tres` - Added job-specific values

## Future Enhancements

- [ ] Job-specific stat growth curves (logarithmic, exponential)
- [ ] Race-based HP/SP multipliers
- [ ] Transcendence bonuses to growth rates
- [ ] UI displays showing expected HP/SP at different levels
- [ ] Equipment-based modifier to growth rates
