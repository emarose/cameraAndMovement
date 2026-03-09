# **ANÁLISIS DE ARQUITECTURA DEL PROYECTO - ACTUALIZADO**
## Composition vs Inheritance - Guía para Refactorización

**Fecha de Actualización:** Febrero 2026  
**Proyecto:** Godot RPG (Estilo Ragnarok Online)  
**Estado:** Análisis Completo del Proyecto

---

## 📊 ESTADO ACTUAL DEL PROYECTO

### ✅ Componentes YA Implementados (Bien Diseñados)

El proyecto ya tiene una **base sólida** con estos componentes reutilizables:

| Componente | Estado | Descripción |
|-----------|--------|-------------|
| **`StatsComponent`** | ✅ Implementado | Gestiona stats base (STR, AGI, VIT, INT, DEX, LUK) y derivados con bonos |
| **`HealthComponent`** | ✅ Implementado | Sistema de daño, curación y muerte con señales |
| **`SPComponent`** | ✅ Implementado | Gestión de SP/Mana para skills y abilities |
| **`InventoryComponent`** | ✅ Implementado | Gestión de inventario con stacking inteligente |
| **`EquipmentComponent`** | ✅ Implementado | Sistema de equipamiento y aplicación de bonos |
| **`SkillComponent`** | ✅ Implementado | Gestión de skills, casteo, cooldowns y ejecución |
| **`RegenerationComponent`** | ✅ Implementado | Regeneración automática de HP/SP en tiempo real |
| **`StatusEffectManager`** | ✅ Implementado | Sistema de buffs/debuffs con duración y efectos DoT |
| **`CombatMath`** | ✅ Implementado | Tabla elemental y cálculos de multiplicadores |

**Evaluación:** Estos componentes están bien diseñados y son reutilizables entre Player y Enemy.

---

## 🔴 COMPONENTES CRÍTICOS QUE FALTAN

### 1. **StatusController** - ⭐ PRIORIDAD MÁXIMA

**Estado Actual:** ❌ No existe  
**Impacto:** CRÍTICO - Hay variables booleanas dispersas que causan bugs

**Problema Actual (disperso en múltiples archivos):**
```gdscript
# player.gd
var is_stunned: bool = false
var is_dead: bool = false  # Duplicado en HealthComponent
var is_clicking: bool = false

# enemy.gd  
var is_dead: bool = false  # Duplicado
var is_stunned: bool = false  # Duplicado
var is_aggroed: bool = false
```

**Solución: StatusController centralizado**
```gdscript
class_name StatusController
extends Node

signal status_changed(new_status, old_status)
signal can_move_changed(can_move)
signal can_attack_changed(can_attack)
signal can_cast_changed(can_cast)

enum Status { NORMAL, STUNNED, ROOTED, SILENCED, FROZEN, SLEEP, DEAD }

var current_status: Status = Status.NORMAL
var status_timers: Dictionary = {}

func apply_status(new_status: Status, duration: float = -1.0) -> void:
    var old_status = current_status
    current_status = new_status
    
    status_changed.emit(new_status, old_status)
    can_move_changed.emit(can_move())
    can_attack_changed.emit(can_attack())
    can_cast_changed.emit(can_cast())
    
    if duration > 0:
        status_timers[new_status] = Time.get_ticks_msec() + int(duration * 1000)

func can_move() -> bool:
    return current_status not in [Status.STUNNED, Status.ROOTED, Status.FROZEN, Status.SLEEP, Status.DEAD]

func can_attack() -> bool:
    return current_status not in [Status.STUNNED, Status.FROZEN, Status.SLEEP, Status.DEAD]

func can_cast() -> bool:
    return current_status not in [Status.STUNNED, Status.SILENCED, Status.FROZEN, Status.SLEEP, Status.DEAD]

func is_alive() -> bool:
    return current_status != Status.DEAD

func _process(delta: float) -> void:
    var current_time = Time.get_ticks_msec()
    for status in status_timers.keys():
        if current_time >= status_timers[status]:
            status_timers.erase(status)
            if current_status == status:
                apply_status(Status.NORMAL)
```

**Integración con StatusEffectManager:**
```gdscript
# En StatusEffectManager.gd - método que ya existe
func _apply_effect_logic(data: StatusEffectData, is_applying: bool):
    match data.type:
        StatusEffectData.EffectType.STUN:
            var status_ctrl = get_parent().get_node_or_null("StatusController")
            if status_ctrl:
                if is_applying:
                    status_ctrl.apply_status(StatusController.Status.STUNNED, data.duration)
                else:
                    if status_ctrl.current_status == StatusController.Status.STUNNED:
                        status_ctrl.apply_status(StatusController.Status.NORMAL)
```

**Beneficios:**
- ✅ Estados centralizados y verificables
- ✅ Elimina variables booleanas duplicadas
- ✅ Fácil añadir nuevos estados (PETRIFIED, etc.)
- ✅ Integración automática con todos los sistemas
- ✅ UI puede monitorear cambios de estado

---

### 2. **MovementComponent** - ⭐ PRIORIDAD ALTA

**Estado Actual:** ❌ No existe  
**Impacto:** ALTO - Código de movimiento disperso en Player y Enemy

**Problema Actual:**
```gdscript
# enemy.gd - línea ~73
func _move_logic(target_pos: Vector3, movement_speed: float):
    nav_agent.target_position = target_pos
    # ... movimiento duplicado

# player.gd
# Similar lógica de navegación dispersa en _process
```

**Solución:**
```gdscript
class_name MovementComponent
extends Node

signal movement_started(target_position)
signal movement_stopped()
signal velocity_changed(new_velocity)

@export var base_speed: float = 5.0
@export var acceleration: float = 20.0
@export var friction: float = 5.0

var nav_agent: NavigationAgent3D
var stats: StatsComponent
var status_controller: StatusController
var body: CharacterBody3D
var current_velocity: Vector3 = Vector3.ZERO

func setup(character_body: CharacterBody3D, stats_comp: StatsComponent, 
           nav: NavigationAgent3D, status: StatusController = null) -> void:
    body = character_body
    stats = stats_comp
    nav_agent = nav
    status_controller = status

func move_to(target: Vector3) -> bool:
    if not can_move():
        return false
    nav_agent.target_position = target
    movement_started.emit(target)
    return true

func stop() -> void:
    nav_agent.target_position = body.global_position
    movement_stopped.emit()

func get_current_speed() -> float:
    if not stats:
        return base_speed
    # Aplicar modificadores del stats (buffs, equipment, etc)
    return base_speed * stats.get_move_speed_modifier()

func can_move() -> bool:
    if status_controller:
        return status_controller.can_move()
    return true

func get_next_velocity() -> Vector3:
    if not can_move():
        current_velocity = current_velocity.lerp(Vector3.ZERO, friction * get_physics_process_delta_time())
        return current_velocity
    
    if nav_agent.is_navigation_finished():
        current_velocity = current_velocity.lerp(Vector3.ZERO, friction * get_physics_process_delta_time())
        return current_velocity
    
    var next_pos = nav_agent.get_next_path_position()
    var direction = (next_pos - body.global_position).normalized()
    var target_velocity = direction * get_current_speed()
    
    current_velocity = current_velocity.lerp(target_velocity, acceleration * get_physics_process_delta_time())
    velocity_changed.emit(current_velocity)
    
    return current_velocity

func is_moving() -> bool:
    return current_velocity.length() > 0.1
```

**Integración en Player/Enemy `_physics_process`:**
```gdscript
# Solo necesita una línea en el loop de física
velocity = movement_component.get_next_velocity()
move_and_slide()
```

**Beneficios:**
- ✅ Player y Enemy comparten la misma lógica
- ✅ Buffs de velocidad se aplican automáticamente
- ✅ Estados como STUN detienen movimiento automáticamente
- ✅ Fácil de testear y depurar
- ✅ Smooth acceleration/friction

---

### 3. **CombatComponent** - ⭐ PRIORIDAD ALTA

**Estado Actual:** ❌ No existe  
**Impacto:** ALTO - Lógica de combate duplicada

**Problema Actual:**
```gdscript
# player.gd (disperso en _process)
var damage = attack_damage + stats.str_stat
if target and distance <= attack_range:
    target.health_component.take_damage(damage)

# enemy.gd (similar, duplicado)
var dmg = data.attack + stats_comp.str_stat
player.health_component.take_damage(dmg)
```

**Solución:**
```gdscript
class_name CombatComponent
extends Node

signal attack_started(target)
signal hit_landed(target, damage)
signal attack_missed(target)
signal attacked_by(attacker)

@export var base_damage: int = 10
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.0

var stats: StatsComponent
var status_controller: StatusController
var health_component: HealthComponent
var last_attack_time: int = 0

func setup(stats_comp: StatsComponent, health_comp: HealthComponent, status: StatusController = null) -> void:
    stats = stats_comp
    health_component = health_comp
    status_controller = status

func can_attack(target: Node3D) -> bool:
    if not status_controller or not status_controller.can_attack():
        return false
    
    var time_since_attack = Time.get_ticks_msec() - last_attack_time
    if time_since_attack < attack_cooldown * 1000:
        return false
    
    var distance = get_parent().global_position.distance_to(target.global_position)
    return distance <= attack_range

func perform_attack(target: Node3D) -> bool:
    if not can_attack(target):
        return false
    
    last_attack_time = Time.get_ticks_msec()
    attack_started.emit(target)
    
    # Usar CombatMath existente o DamageCalculator
    var damage = _calculate_damage(target)
    
    if damage > 0:
        if target.has_node("HealthComponent"):
            target.get_node("HealthComponent").take_damage(damage)
            hit_landed.emit(target, damage)
            return true
    else:
        attack_missed.emit(target)
        return false
    
    return false

func _calculate_damage(target: Node3D) -> int:
    if not stats:
        return base_damage
    
    var target_stats = target.get_node_or_null("StatsComponent")
    if not target_stats:
        return base_damage
    
    # Sistema HIT/FLEE
    var hit_chance = _calculate_hit_chance(target_stats)
    if randf() > hit_chance:
        return 0  # MISS
    
    # Daño base
    var atk = stats.get_atk()
    var def_value = target_stats.get_def()
    var damage = max(1, atk - def_value)
    
    # Variación
    var variance = randf_range(-0.1, 0.1)
    damage += int(damage * variance)
    
    # Crítico
    if _is_critical_hit():
        damage = int(damage * 1.4)
    
    return damage

func _calculate_hit_chance(target_stats: StatsComponent) -> float:
    var hit = stats.get_hit()
    var flee = target_stats.get_flee()
    var chance = 0.8 + (hit - flee) * 0.01
    return clamp(chance, 0.05, 0.95)

func _is_critical_hit() -> bool:
    var luk = stats.get_total_luk()
    var crit_chance = luk * 0.003
    return randf() < crit_chance

func get_attack_speed() -> float:
    return stats.get_attack_speed() if stats else 1.0
```

**Beneficios:**
- ✅ Lógica de combate unificada
- ✅ Sistema HIT/FLEE/CRIT automático
- ✅ Fácil aplicar modificadores
- ✅ Eventos para UI y VFX

---

### 4. **AIController** - ⭐ PRIORIDAD ALTA

**Estado Actual:** ❌ No existe  
**Impacto:** ALTO - IA de enemigos va a ser cada vez más compleja

**Problema Actual:**
```gdscript
# enemy.gd - línea ~30
enum State { IDLE, WANDERING, CHASING, ATTACKING }
var current_state = State.IDLE

# Lógica de IA mezclada con físicas, eventos, etc.
```

**Solución - Base Abstracta:**
```gdscript
class_name AIController
extends Node

signal target_acquired(target)
signal target_lost()
signal state_changed(new_state)

enum AIState { IDLE, PATROLLING, ALERT, CHASING, ATTACKING }

var target: Node3D
var owner_entity: CharacterBody3D
var current_state: AIState = AIState.IDLE
var home_position: Vector3

# Referencias a componentes
var stats: StatsComponent
var movement: MovementComponent
var combat: CombatComponent
var status_controller: StatusController
var detection: DetectionComponent

func setup(entity: CharacterBody3D) -> void:
    owner_entity = entity
    home_position = entity.global_position
    stats = entity.get_node_or_null("StatsComponent")
    movement = entity.get_node_or_null("MovementComponent")
    combat = entity.get_node_or_null("CombatComponent")
    status_controller = entity.get_node_or_null("StatusController")
    detection = entity.get_node_or_null("DetectionComponent")

# Método principal que cada subclase implementa
func process_ai(delta: float) -> void:
    pass

func on_target_detected(detected_target: Node3D) -> void:
    if not target:
        target = detected_target
        target_acquired.emit(target)

func on_target_lost() -> void:
    target = null
    target_lost.emit()
    _change_state(AIState.IDLE)

func _change_state(new_state: AIState) -> void:
    if current_state != new_state:
        current_state = new_state
        state_changed.emit(new_state)

func _is_ready_to_attack() -> bool:
    return status_controller == null or status_controller.can_attack()
```

**Subclase MeleeAI:**
```gdscript
class_name MeleeAI
extends AIController

@export var patrol_range: float = 5.0
@export var patrol_wait_time: float = 2.0

var wander_timer: float = 0.0
var wander_target: Vector3

func _ready():
    wander_target = home_position

func process_ai(delta: float) -> void:
    if not status_controller or status_controller.is_alive():
        return
    
    if not target or not target.is_inside_tree():
        _handle_idle_state(delta)
        return
    
    var distance = owner_entity.global_position.distance_to(target.global_position)
    
    if distance <= combat.attack_range:
        _change_state(AIState.ATTACKING)
        movement.stop()
        combat.perform_attack(target)
    elif distance <= 15.0:  # Aggro range
        _change_state(AIState.CHASING)
        movement.move_to(target.global_position)
    else:
        on_target_lost()

func _handle_idle_state(delta: float) -> void:
    if current_state != AIState.PATROLLING:
        _change_state(AIState.PATROLLING)
        _pick_wander_target()
    
    wander_timer -= delta
    if wander_timer <= 0:
        _pick_wander_target()

func _pick_wander_target() -> void:
    var random_offset = Vector3(randf_range(-patrol_range, patrol_range), 0, randf_range(-patrol_range, patrol_range))
    wander_target = home_position + random_offset
    movement.move_to(wander_target)
    wander_timer = patrol_wait_time
```

**Subclase RangedAI:**
```gdscript
class_name RangedAI
extends AIController

@export var preferred_distance: float = 8.0
@export var min_distance: float = 4.0

func process_ai(delta: float) -> void:
    if not target or not target.is_inside_tree():
        _change_state(AIState.IDLE)
        return
    
    var distance = owner_entity.global_position.distance_to(target.global_position)
    
    # Mantener distancia óptima
    if distance < min_distance:
        _change_state(AIState.CHASING)
        var away_dir = (owner_entity.global_position - target.global_position).normalized()
        movement.move_to(owner_entity.global_position + away_dir * min_distance)
    elif distance > preferred_distance:
        _change_state(AIState.CHASING)
        movement.move_to(target.global_position)
    else:
        _change_state(AIState.ATTACKING)
        movement.stop()
        combat.perform_attack(target)
```

**Beneficios:**
- ✅ Fácil crear nuevos tipos (BossAI, SupportAI, etc.)
- ✅ Comportamiento consistente y predecible
- ✅ Reutilizable para NPCs aliados
- ✅ Separación de responsabilidades

---

### 5. **DetectionComponent** - ⭐ PRIORIDAD MEDIA

**Estado Actual:** ❌ No existe  
**Impacto:** MEDIO - Aggro está hardcodeado

```gdscript
class_name DetectionComponent
extends Area3D

signal target_detected(target)
signal target_lost(target)

@export var detection_range: float = 10.0
@export var target_group: String = "player"
@export var check_line_of_sight: bool = false

var current_targets: Array[Node3D] = []

func _ready():
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)
    
    var shape = SphereShape3D.new()
    shape.radius = detection_range
    var collision = CollisionShape3D.new()
    collision.shape = shape
    add_child(collision)

func _on_body_entered(body: Node3D) -> void:
    if not body.is_in_group(target_group):
        return
    
    if check_line_of_sight and not _has_line_of_sight(body):
        return
    
    if not current_targets.has(body):
        current_targets.append(body)
        target_detected.emit(body)

func _on_body_exited(body: Node3D) -> void:
    if current_targets.has(body):
        current_targets.erase(body)
        target_lost.emit(body)

func _has_line_of_sight(target: Node3D) -> bool:
    var space_state = get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(global_position, target.global_position)
    query.exclude = [get_parent()]
    
    var result = space_state.intersect_ray(query)
    return result.is_empty() or result.collider == target

func get_closest_target() -> Node3D:
    if current_targets.is_empty():
        return null
    
    var closest: Node3D = null
    var min_dist := INF
    
    for target in current_targets:
        var dist = global_position.distance_to(target.global_position)
        if dist < min_dist:
            min_dist = dist
            closest = target
    
    return closest
```

**Beneficios:**
- ✅ Reutilizable en enemigos, torres, NPCs
- ✅ Línea de visión automática
- ✅ Sistema de alerta grupal posible

---

## 🟠 COMPONENTES ADICIONALES RECOMENDADOS

### 6. **DamageCalculator** (Singleton)

**Estado Actual:** ⚠️ Parcialmente en CombatMath.gd  
**Impacto:** MEDIO - Balanceo centralizado

Centralizar toda la lógica de daño que ya existe en `CombatMath.gd` y crear métodos estáticos accesibles desde cualquier componente.

---

### 7. **AnimationController**

**Estado Actual:** ❌ No existe  
**Impacto:** BAJO - Visuales

Gestionar animaciones de ataque, muerte, skills, etc., de forma centralizada.

```gdscript
class_name AnimationController
extends Node

signal animation_finished(animation_name)

var animation_player: AnimationPlayer
var animation_tree: AnimationTree

func setup(anim_player: AnimationPlayer) -> void:
    animation_player = anim_player
    if animation_player:
        animation_player.animation_finished.connect(_on_animation_finished)

func play_attack_animation() -> void:
    if animation_player and animation_player.has_animation("attack"):
        animation_player.play("attack")

func play_hit_reaction() -> void:
    if animation_player and animation_player.has_animation("hit"):
        animation_player.play("hit")

func play_death_animation() -> void:
    if animation_player and animation_player.has_animation("death"):
        animation_player.play("death")

func play_skill_animation(skill_name: String) -> void:
    var anim_name = "skill_" + skill_name.to_lower()
    if animation_player and animation_player.has_animation(anim_name):
        animation_player.play(anim_name)

func set_move_speed(speed: float) -> void:
    if animation_player:
        animation_player.speed_scale = clamp(speed, 0.5, 2.0)

func _on_animation_finished(anim_name: String) -> void:
    animation_finished.emit(anim_name)
```

---

### 8. **EffectController**

**Estado Actual:** ⚠️ Parcialmente en floating_text.gd, level_up_effect.gd  
**Impacto:** BAJO - VFX

Centralizar spawning de efectos visuales y floating text.

```gdscript
class_name EffectController
extends Node

@export var floating_text_scene: PackedScene
@export var default_effect_scene: PackedScene

func spawn_floating_damage(amount: int, position: Vector3, is_critical: bool = false) -> void:
    if not floating_text_scene:
        return
    
    var text = floating_text_scene.instantiate()
    get_tree().current_scene.add_child(text)
    text.global_position = position
    
    if text.has_method("set_text"):
        text.set_text(str(amount))
    
    if is_critical and text.has_method("set_critical"):
        text.set_critical(true)

func spawn_effect(effect_scene: PackedScene, position: Vector3, rotation: Vector3 = Vector3.ZERO) -> Node:
    if not effect_scene:
        return null
    
    var effect = effect_scene.instantiate()
    get_tree().current_scene.add_child(effect)
    effect.global_position = position
    effect.global_rotation = rotation
    
    return effect

func spawn_skill_effect(skill_data: SkillData, position: Vector3) -> void:
    if skill_data and skill_data.effect_scene:
        spawn_effect(skill_data.effect_scene, position)
```

---

### 9. **CooldownManager**

**Estado Actual:** ⚠️ En SkillComponent.gd (cooldown_timers)  
**Impacto:** BAJO - Sistema genérico

Separar en componente reutilizable para skills, ataques, etc.

```gdscript
class_name CooldownManager
extends Node

signal cooldown_started(id: String, duration: float)
signal cooldown_finished(id: String)
signal cooldown_tick(id: String, remaining: float)

var cooldowns: Dictionary = {}  # id: end_time_ms

func start_cooldown(id: String, duration: float) -> void:
    var end_time = Time.get_ticks_msec() + int(duration * 1000)
    cooldowns[id] = end_time
    cooldown_started.emit(id, duration)

func is_on_cooldown(id: String) -> bool:
    if not cooldowns.has(id):
        return false
    
    var current_time = Time.get_ticks_msec()
    if current_time >= cooldowns[id]:
        cooldowns.erase(id)
        cooldown_finished.emit(id)
        return false
    
    return true

func get_remaining(id: String) -> float:
    if not cooldowns.has(id):
        return 0.0
    
    var current_time = Time.get_ticks_msec()
    var remaining_ms = cooldowns[id] - current_time
    return max(0.0, remaining_ms / 1000.0)

func clear_cooldown(id: String) -> void:
    if cooldowns.has(id):
        cooldowns.erase(id)
        cooldown_finished.emit(id)

func clear_all() -> void:
    cooldowns.clear()

func _process(delta: float) -> void:
    for id in cooldowns.keys():
        var remaining = get_remaining(id)
        if remaining > 0:
            cooldown_tick.emit(id, remaining)
```

---

### 10. **LootManager** (Singleton/AutoLoad)

**Estado Actual:** ❌ No existe  
**Impacto:** BAJO - Drops centralizado

```gdscript
extends Node

func generate_loot(enemy_data: EnemyData, killer_stats: StatsComponent = null) -> Array[ItemData]:
    var dropped_items: Array[ItemData] = []
    
    for drop_entry in enemy_data.drops_table:
        var drop_chance = drop_entry.drop_chance
        
        # Modificar por LUK del jugador
        if killer_stats:
            var luk_bonus = killer_stats.get_total_luk() * 0.001  # 0.1% por LUK
            drop_chance += luk_bonus
        
        # Roll
        if randf() <= drop_chance:
            dropped_items.append(drop_entry.item)
    
    return dropped_items

func spawn_loot_drops(items: Array[ItemData], position: Vector3, drop_scene: PackedScene) -> void:
    for item in items:
        var drop = drop_scene.instantiate()
        get_tree().current_scene.add_child(drop)
        
        # Esparcir items en un radio pequeño
        var offset = Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
        drop.global_position = position + offset
        
        if drop.has_method("set_item"):
            drop.set_item(item)
```

---

### 11. **ExperienceManager** (Singleton/AutoLoad)

**Estado Actual:** ❌ No existe  
**Impacto:** BAJO - XP compartida

```gdscript
extends Node

signal xp_gained(character: Node, amount: int)
signal level_up(character: Node, new_level: int)

@export var xp_multiplier: float = 1.0  # Para eventos x2 XP

func calculate_kill_xp(enemy_data: EnemyData, killer_level: int) -> int:
    var base_xp = enemy_data.xp_reward
    
    # Penalización por diferencia de nivel
    var level_diff = enemy_data.level - killer_level
    
    if level_diff < -10:
        # Enemigo muy débil: -50% XP
        base_xp = int(base_xp * 0.5)
    elif level_diff > 10:
        # Enemigo muy fuerte: +50% XP
        base_xp = int(base_xp * 1.5)
    
    # Aplicar multiplicador de servidor
    return int(base_xp * xp_multiplier)

func award_xp(character: Node, amount: int) -> void:
    var stats = character.get_node_or_null("StatsComponent")
    if not stats:
        return
    
    stats.add_xp(amount)
    xp_gained.emit(character, amount)
```

---

## 📋 ESTRUCTURA IDEAL DESPUÉS DE LA REFACTORIZACIÓN

### Player
```
Player (CharacterBody3D)
├── StatsComponent ✅
├── HealthComponent ✅
├── SPComponent ✅
├── StatusEffectManager ✅
├── StatusController ⭐ (CREAR)
├── EquipmentComponent ✅
├── InventoryComponent ✅
├── SkillComponent ✅
├── RegenerationComponent ✅
├── MovementComponent ⭐ (CREAR)
├── CombatComponent ⭐ (CREAR)
├── AnimationController 🟠 (CREAR)
├── EffectController 🟠 (CREAR)
├── CooldownManager 🟠 (CREAR)
└── CameraPivot (Existente)
```

### Enemy
```
Enemy (CharacterBody3D)
├── StatsComponent ✅
├── HealthComponent ✅
├── SPComponent ✅ (opcional)
├── StatusEffectManager ✅
├── StatusController ⭐ (CREAR)
├── SkillComponent ✅ (opcional)
├── RegenerationComponent ✅ (opcional)
├── MovementComponent ⭐ (CREAR)
├── CombatComponent ⭐ (CREAR)
├── AIController ⭐ (CREAR) - MeleeAI, RangedAI, BossAI
├── DetectionComponent ⭐ (CREAR)
├── AnimationController 🟠 (CREAR)
├── EffectController 🟠 (CREAR)
└── HealthBar3D (Existente)
```

---

## 🎯 PLAN DE IMPLEMENTACIÓN

### Fase 1: CRÍTICO (1-2 semanas)
1. **StatusController** - Centralizar estados
2. **MovementComponent** - Unificar navegación
3. **CombatComponent** - Unificar ataques

### Fase 2: ALTO (2-3 semanas)
4. **AIController** + MeleeAI/RangedAI - IA de enemigos
5. **DetectionComponent** - Aggro y visión
6. Refactorizar `enemy.gd` para usar nuevos componentes

### Fase 3: MEDIO (1-2 semanas)
7. **AnimationController** - Gestos de animación
8. **EffectController** - Centralizar VFX
9. Separar CooldownManager de SkillComponent

### Fase 4: BAJO (Opcional)
10. **DamageCalculator** singleton
11. **LootManager** - Drops centralizado
12. **ExperienceManager** - XP compartida

---

## 💡 VENTAJAS DE ESTA ARQUITECTURA

### ✅ Composición (Propuesta)
```gdscript
# Crear Boss Ranged con Regeneración en 3 líneas
var boss = Enemy.new()
boss.add_child(RangedAI.new())
boss.add_child(RegenerationComponent.new())  # ¡Listo!
```

### ❌ Herencia (Problema)
```gdscript
# Necesitarías crear múltiples subclases
class EnemyRanged extends Enemy
class EnemyBoss extends Enemy
class EnemyRangedBoss extends EnemyRanged  # ¿Múltiple herencia?
# Explosión de clases
```

---

## 📌 PRÓXIMOS PASOS

1. **Crear carpeta `/scripts/components/`** para los nuevos componentes
2. **Implementar StatusController** primero (máxima prioridad)
3. **Testear** cada componente individualmente
4. **Integrar** uno por uno en Player primero
5. **Migrar** Enemy después
6. **Documentar** cada componente con ejemplos

---

---

## 🎓 SISTEMA DE JOBS (PROFESIONES)

### Estado Actual del Job System

**Ya Implementado:** ✅
- `JobData` resource class con bonos y habilidades
- `JobChanger.gd` NPC para cambiar de profesión
- `JobChangerUI.gd` interfaz de selección
- Integración con `StatsComponent` y `SkillComponent`
- Almacenamiento de jobs en `GameManager.player_stats`

**Problema Actual:**
```gdscript
# JobData es solo datos - La lógica está dispersa
# En player.gd, GameManager.gd, JobChangerUI.gd, StatsComponent.gd
# No hay un componente unificado que maneje transiciones de job
```

### Solución: **JobComponent** - ⭐ ESENCIAL

**Estado:** ❌ No existe como componente  
**Impacto:** ALTO - Centraliza toda la lógica de profesiones

```gdscript
class_name JobComponent
extends Node

signal job_changed(old_job, new_job)
signal job_level_up(new_level)
signal job_exp_changed(current_exp, max_exp)

@export var starting_job_path: String = "res://resources/jobs/Novice.tres"

var current_job: JobData
var current_job_level: int = 1
var current_job_exp: int = 0
var max_job_exp_table: Array = [100, 200, 400, 800]  # Por nivel

var stats_component: StatsComponent
var skill_component: SkillComponent

func setup(stats: StatsComponent, skills: SkillComponent) -> void:
    stats_component = stats
    skill_component = skills
    load_job(starting_job_path)

func load_job(job_path: String) -> void:
    var new_job = load(job_path) as JobData
    if not new_job:
        push_error("No se pudo cargar el job: " + job_path)
        return
    
    var old_job = current_job
    current_job = new_job
    _apply_job_bonuses()
    job_changed.emit(old_job, new_job)

func add_job_exp(amount: int) -> void:
    current_job_exp += amount
    var max_exp = max_job_exp_table[current_job_level - 1] if current_job_level < max_job_exp_table.size() else 10000
    
    if current_job_exp >= max_exp:
        level_up_job()
    else:
        job_exp_changed.emit(current_job_exp, max_exp)

func level_up_job() -> void:
    if current_job_level >= current_job.max_job_level:
        return
    
    var excess_exp = current_job_exp - max_job_exp_table[current_job_level - 1]
    current_job_level += 1
    current_job_exp = excess_exp
    
    _apply_job_bonuses()
    job_level_up.emit(current_job_level)

func _apply_job_bonuses() -> void:
    # Limpiar bonos previos
    if stats_component:
        stats_component.status_bonuses["str"] = 0
        stats_component.status_bonuses["agi"] = 0
        stats_component.status_bonuses["int"] = 0
        # ... otros bonos
    
    # Aplicar bonos de job actual
    if current_job:
        stats_component.status_bonuses["str"] = current_job.str_bonus
        stats_component.status_bonuses["agi"] = current_job.agi_bonus
        stats_component.status_bonuses["int"] = current_job.int_bonus
        
        # Aplicar bonos por nivel de job
        if current_job.job_level_bonuses.has(current_job_level):
            var bonuses = current_job.job_level_bonuses[current_job_level]
            for stat in bonuses:
                stats_component.status_bonuses[stat] += bonuses[stat]

func get_job_name() -> String:
    return current_job.job_name if current_job else "None"

func unlock_job(job_path: String) -> void:
    # Registrar job desbloqueado (para mostrar en UI de cambio)
    pass
```

**Beneficios:**
- ✅ Lógica de jobs centralizada
- ✅ Fácil agregar nuevos jobs
- ✅ Sistema de EXP de job unificado
- ✅ Bonos aplicados automáticamente
- ✅ UI escucha cambios vía señales

---

## 📋 SISTEMA DE QUESTS Y MISIONES

### Nuevo Componente: **QuestManager** - ⭐ ESENCIAL

**Estado:** ❌ No existe  
**Impacto:** ALTO - Sistema de misiones completo

```gdscript
class_name QuestData
extends Resource

@export var quest_id: String = "quest_001"
@export var quest_name: String = "First Quest"
@export var description: String = ""
@export var npc_giver: String = "Merchant"
@export var objectives: Array[String] = []
@export var rewards: Dictionary = {"zeny": 100, "xp": 50}
@export var next_quests: Array[String] = []  # IDs de quests siguientes
@export var required_level: int = 1
```

```gdscript
class_name QuestManager
extends Node

signal quest_accepted(quest: QuestData)
signal quest_completed(quest: QuestData, rewards: Dictionary)
signal quest_progress_changed(quest_id: String, objective_index: int)
signal quest_failed(quest_id: String)

var active_quests: Dictionary = {}  # quest_id: quest_data
var completed_quests: Array[String] = []
var quest_progress: Dictionary = {}  # quest_id: {"objective_index": int, "progress": var}

func accept_quest(quest: QuestData) -> bool:
    if quest.quest_id in active_quests:
        return false
    
    active_quests[quest.quest_id] = quest
    quest_progress[quest.quest_id] = {"objective_index": 0, "progress": 0}
    quest_accepted.emit(quest)
    return true

func complete_quest(quest_id: String) -> void:
    if not active_quests.has(quest_id):
        return
    
    var quest = active_quests[quest_id]
    active_quests.erase(quest_id)
    completed_quests.append(quest_id)
    
    quest_completed.emit(quest, quest.rewards)
    
    # Unlock next quests
    for next_quest_id in quest.next_quests:
        # Emitir evento para que el mundo cree las nuevas quests

func update_objective(quest_id: String, objective_index: int) -> void:
    if quest_progress.has(quest_id):
        quest_progress[quest_id]["objective_index"] = objective_index
        quest_progress_changed.emit(quest_id, objective_index)

func is_quest_completed(quest_id: String) -> bool:
    return quest_id in completed_quests

func get_active_quest(quest_id: String) -> QuestData:
    return active_quests.get(quest_id)
```

**Beneficios:**
- ✅ Sistema flexible de quests
- ✅ Tracking de progreso automático
- ✅ Encadenamiento de quests
- ✅ Fácil integrar con UI

---

## 🗺️ GESTIÓN DE MAPAS

### Nuevo Componente: **MapManager** - ⭐ ESENCIAL

**Estado:** ❌ No existe  
**Impacto:** ALTO - Control centralizado de niveles/mapas

```gdscript
class_name MapData
extends Resource

@export var map_id: String = "starting_field"
@export var map_name: String = "Starting Field"
@export var scene_path: String = "res://scenes/maps/starting_field.tscn"
@export var npcs: Array[String] = []  # Paths a NPC scenes
@export var enemies: Array[String] = []  # Paths a enemy scenes
@export var music_path: String = ""
@export var level_requirement: int = 1
@export var connections: Array[String] = []  # IDs de mapas conectados
```

```gdscript
class_name MapManager
extends Node

signal map_changed(old_map_id, new_map_id)
signal npcs_spawned
signal enemies_spawned

var current_map: MapData
var current_scene_root: Node3D
var spawned_npcs: Array = []
var spawned_enemies: Array = []

var maps: Dictionary = {}  # map_id: MapData

func _ready():
    # Cargar todos los mapas disponibles
    var map_dir = "res://resources/maps/"
    for file in DirAccess.get_files_at(map_dir):
        if file.ends_with(".tres"):
            var map_data = load(map_dir + file) as MapData
            if map_data:
                maps[map_data.map_id] = map_data

func load_map(map_id: String) -> bool:
    if not maps.has(map_id):
        push_error("Map not found: " + map_id)
        return false
    
    var old_map_id = current_map.map_id if current_map else ""
    current_map = maps[map_id]
    map_changed.emit(old_map_id, map_id)
    
    # Cargar escena
    await get_tree().change_scene_to_file(current_map.scene_path)
    return true

func spawn_npcs() -> void:
    for npc_path in current_map.npcs:
        var npc = load(npc_path).instantiate()
        current_scene_root.add_child(npc)
        spawned_npcs.append(npc)
    npcs_spawned.emit()

func spawn_enemies() -> void:
    for enemy_path in current_map.enemies:
        var enemy = load(enemy_path).instantiate()
        current_scene_root.add_child(enemy)
        spawned_enemies.append(enemy)
    enemies_spawned.emit()

func get_connected_maps() -> Array[MapData]:
    var connected: Array[MapData] = []
    for map_id in current_map.connections:
        if maps.has(map_id):
            connected.append(maps[map_id])
    return connected
```

**Beneficios:**
- ✅ Transiciones de mapa centralizadas
- ✅ Spawn de NPCs/enemigos automático
- ✅ Fácil conexión entre mapas
- ✅ Control de música/ambientación

---

## 🤖 CONTROLADOR DE NPCs

### Nuevo Componente: **NPCController** - ⭐ ESENCIAL

**Estado:** ❌ No existe (disperso en NPC_Merchant.gd, JobChanger.gd)  
**Impacto:** MEDIO-ALTO - Unifica comportamiento de NPCs

```gdscript
class_name NPCData
extends Resource

@export var npc_id: String = "npc_001"
@export var npc_name: String = "Merchant"
@export var npc_type: String = "Merchant"  # Merchant, QuestGiver, JobChanger
@export var interact_distance: float = 8.0
@export var dialog_tree: Array[String] = []  # Path a diálogos
@export var quest_data: Array[QuestData] = []
@export var shop_items: Array[ItemData] = []
```

```gdscript
class_name NPCController
extends StaticBody3D

signal interaction_started(npc: NPCController)
signal interaction_ended
signal dialog_changed(dialog_index: int)

@export var npc_data: NPCData
@export var animated_model: Node3D  # Para animaciones de idle

var player: Node3D = null
var current_dialog_index: int = 0

func _ready():
    if not npc_data:
        push_error("NPCController needs NPC data resource")
        return

func interact(player_node: Node3D) -> void:
    var dist = global_position.distance_to(player_node.global_position)
    if dist <= npc_data.interact_distance:
        player = player_node
        interaction_started.emit(self)
        _open_interaction_ui()
    else:
        get_tree().call_group("hud", "add_log_message", "Acércate más a %s" % npc_data.npc_name, Color.GRAY)

func _open_interaction_ui() -> void:
    match npc_data.npc_type:
        "Merchant":
            _open_shop()
        "QuestGiver":
            _open_quest_dialog()
        "JobChanger":
            _open_job_changer()

func _open_shop() -> void:
    var shop_ui = get_tree().get_first_node_in_group("shop_ui")
    if shop_ui and player:
        var inv = player.get_node("InventoryComponent")
        shop_ui.open_shop(inv, npc_data.shop_items)

func _open_quest_dialog() -> void:
    var quest_ui = get_tree().get_first_node_in_group("quest_ui")
    if quest_ui:
        quest_ui.open_quest_dialog(npc_data.quest_data)

func _open_job_changer() -> void:
    var job_ui = get_tree().get_first_node_in_group("job_changer_ui")
    if job_ui and player:
        job_ui.open_job_changer(player, npc_data.shop_items)

func end_interaction() -> void:
    player = null
    current_dialog_index = 0
    interaction_ended.emit()
```

**Beneficios:**
- ✅ NPCs con comportamiento unificado
- ✅ Fácil crear nuevos tipos de NPCs
- ✅ Datos separados de lógica
- ✅ Interacciones flexibles

---

## 🎨 UI/HUD COMO CAPA TRANSVERSAL

### Arquitectura de Señales del HUD

**Estado Actual:** ⚠️ Parcialmente implementado  
El HUD ya escucha al GameManager pero podría ser más robusto y escalable.

```
┌─────────────────────────────────────────────────────────────┐
│              HUD/UI (CanvasLayer)                           │
│  - Escucha TODOS los eventos del juego                      │
│  - Actualiza visualización en tiempo real                   │
└──────────┬──────────────────────────────────────────────────┘
           │
           ├─ StatsComponent.stats_changed
           ├─ HealthComponent.on_health_changed
           ├─ SPComponent.sp_changed
           ├─ StatusEffectManager.effect_started/ended
           ├─ SkillComponent.cooldown_started
           ├─ StatusController.can_move_changed
           ├─ StatusController.status_changed
           ├─ JobComponent.job_changed
           ├─ JobComponent.job_exp_changed
           ├─ QuestManager.quest_accepted
           ├─ QuestManager.quest_completed
           ├─ MapManager.map_changed
           ├─ InventoryComponent.inventory_changed
           ├─ EquipmentComponent.equipment_changed
           └─ GameManager.base_exp_gained
```

### Estructura Recomendada para HUD

```gdscript
class_name UIManager
extends CanvasLayer

# --- Paneles Específicos ---
var status_panel: StatusPanel
var inventory_panel: InventoryPanel
var equipment_panel: EquipmentPanel
var quest_panel: QuestPanel
var job_panel: JobPanel
var minimap: Minimap

# --- Referencias a Componentes del Player ---
var player: Node3D
var stats: StatsComponent
var health: HealthComponent
var sp: SPComponent
var status_controller: StatusController
var job_component: JobComponent
var quest_manager: QuestManager
var map_manager: MapManager

func _ready():
    # Conectar a TODOS los componentes
    _connect_to_player_components()
    _connect_to_managers()
    _connect_to_hud_groups()

func _connect_to_player_components() -> void:
    if stats:
        stats.stats_changed.connect(_on_stats_changed)
    if health:
        health.on_health_changed.connect(_on_health_changed)
    if sp:
        sp.sp_changed.connect(_on_sp_changed)
    if status_controller:
        status_controller.status_changed.connect(_on_status_changed)
    if job_component:
        job_component.job_changed.connect(_on_job_changed)

func _connect_to_managers() -> void:
    if quest_manager:
        quest_manager.quest_accepted.connect(_on_quest_accepted)
        quest_manager.quest_completed.connect(_on_quest_completed)
    if map_manager:
        map_manager.map_changed.connect(_on_map_changed)

func _on_stats_changed() -> void:
    status_panel.update_stats(stats)

func _on_health_changed(current: int, max: int) -> void:
    status_panel.update_health(current, max)

func _on_sp_changed(current: int, max: int) -> void:
    status_panel.update_sp(current, max)

func _on_status_changed(new_status, old_status) -> void:
    status_panel.show_status_effect(new_status)

func _on_job_changed(old_job, new_job) -> void:
    job_panel.update_job_display(new_job)

func _on_quest_accepted(quest: QuestData) -> void:
    quest_panel.add_quest(quest)

func _on_quest_completed(quest: QuestData, rewards) -> void:
    quest_panel.complete_quest(quest)
    _show_reward_animation(rewards)

func _on_map_changed(old_map_id, new_map_id) -> void:
    minimap.load_map(new_map_id)

func _connect_to_hud_groups() -> void:
    # Métodos que otros sistemas pueden llamar
    add_to_group("hud_notifications")
    add_to_group("ui_event_listener")
```

### Beneficios de esta Arquitectura UI:
- ✅ UI siempre sincronizado con estado del juego
- ✅ Bajo acoplamiento (escucha eventos, no referencias directas)
- ✅ Fácil agregar nuevos paneles
- ✅ Performance optimizado (solo actualiza lo que cambió)
- ✅ Debugging simplificado (eventos visibles)

---

## 🔗 RESUMEN DE CAMBIOS

| Componente | Estado | Prioridad | Notas |
|-----------|--------|-----------|-------|
| StatusController | ❌ | ⭐⭐⭐ | Elimina variables booleanas dispersas |
| MovementComponent | ❌ | ⭐⭐⭐ | Unifica navegación Player/Enemy |
| CombatComponent | ❌ | ⭐⭐⭐ | Unifica sistema de ataque |
| **JobComponent** | ❌ | ⭐⭐⭐ | **NUEVO: Centraliza lógica de profesiones** |
| **QuestManager** | ❌ | ⭐⭐⭐ | **NUEVO: Sistema de misiones** |
| **MapManager** | ❌ | ⭐⭐ | **NUEVO: Gestión de niveles/mapas** |
| **NPCController** | ❌ | ⭐⭐ | **NUEVO: Unifica comportamiento de NPCs** |
| AIController | ❌ | ⭐⭐ | Base para IA de enemigos |
| DetectionComponent | ❌ | ⭐⭐ | Aggro y visión automática |
| DamageCalculator | ⚠️ | ⭐⭐ | Centralizar `CombatMath` |
| **UIManager** | ⚠️ | ⭐⭐ | **MEJORADO: Escucha todas las señales** |
| AnimationController | ❌ | ⭐ | Gestos de animación |
| EffectController | ⚠️ | ⭐ | Centralizar VFX |
| CooldownManager | ⚠️ | ⭐ | Separar de SkillComponent |
| LootManager | ❌ | ⭐ | AutoLoad para drops |
| ExperienceManager | ❌ | ⭐ | AutoLoad para XP |

---

## 📊 NUEVA ESTRUCTURA DE PROYECTO COMPLETA

```
Player (CharacterBody3D)
├── StatsComponent ✅
├── HealthComponent ✅
├── SPComponent ✅
├── StatusEffectManager ✅
├── StatusController ⭐
├── EquipmentComponent ✅
├── InventoryComponent ✅
├── SkillComponent ✅
├── RegenerationComponent ✅
├── MovementComponent ⭐
├── CombatComponent ⭐
├── JobComponent ⭐ (NUEVO)
├── AnimationController 🟠
├── EffectController 🟠
├── CooldownManager 🟠
└── CameraPivot

World (Node3D)
├── MapManager ⭐ (NUEVO)
├── QuestManager ⭐ (NUEVO)
├── NPCController(s) ⭐ (NUEVO)
├── Navigation3D
├── Enemies
│   ├── AIController ⭐
│   ├── DetectionComponent ⭐
│   └── ... (otros componentes)
├── NPCs
│   └── NPCController ⭐ (NUEVO)
└── UI (CanvasLayer)
    └── UIManager ⭐ (MEJORADO)
        ├── StatusPanel
        ├── InventoryPanel
        ├── EquipmentPanel
        ├── JobPanel (NUEVO)
        ├── QuestPanel (NUEVO)
        └── Minimap (NUEVO)

Autoload/Singletons
├── GameManager ✅
├── DamageCalculator 🟠
├── LootManager ⭐
├── ExperienceManager ⭐
└── EventBus (comunicación global)
```

---

## 🎯 PLAN DE IMPLEMENTACIÓN ACTUALIZADO

### Fase 1: CRÍTICO (2-3 semanas)
1. **StatusController** - Centralizar estados
2. **MovementComponent** - Unificar navegación
3. **CombatComponent** - Unificar ataques
4. **JobComponent** - Centralizar lógica de profesiones

### Fase 2: ALTO (2-3 semanas)
5. **QuestManager** - Sistema de misiones
6. **MapManager** - Gestión de niveles
7. **NPCController** - Unificar comportamiento de NPCs
8. **AIController** + MeleeAI/RangedAI - IA de enemigos
9. **DetectionComponent** - Aggro y visión

### Fase 3: MEDIO (1-2 semanas)
10. **UIManager** mejorado - Escucha centralizada de eventos
11. **AnimationController** - Gestos de animación
12. **EffectController** - Centralizar VFX
13. Separar **CooldownManager** de SkillComponent

### Fase 4: BAJO (Cuando haya tiempo)
14. **DamageCalculator** singleton
15. **LootManager** - Drops centralizado
16. **ExperienceManager** - XP compartida
17. **EventBus** - Comunicación global entre sistemas

---

**Este documento proporciona una arquitectura completa y escalable para el proyecto RPG, cubriendo todas las áreas clave: combate, progresión, quests, mapas y UI.**
