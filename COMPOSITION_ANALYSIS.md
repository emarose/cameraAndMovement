# ANÁLISIS DE ARQUITECTURA DEL PROYECTO
## Composition vs Inheritance - Guía para Refactorización

**Fecha:** Enero 2026  
**Proyecto:** Godot RPG (Estilo Ragnarok Online)

---

## Estado Actual: Lo que YA está usando Composition ✅

El proyecto ya implementa correctamente varios componentes reutilizables:

### Componentes Implementados:
1. **`StatsComponent`** - Gestiona stats base y derivados (STR, AGI, VIT, etc.)
2. **`HealthComponent`** - Sistema de daño, curación y muerte
3. **`InventoryComponent`** - Inventario y gestión de stacking
4. **`EquipmentComponent`** - Sistema de equipamiento y bonos
5. **`SkillComponent`** - Gestión de habilidades y cooldowns
6. **`SPComponent`** - Gestión de puntos de habilidad (SP/Mana)
7. **`RegenerationComponent`** - Regeneración automática de HP/SP
8. **`StatusEffectManager`** - Sistema de buffs/debuffs y estados temporales

**Evaluación:** Estos componentes están bien diseñados y son reutilizables entre Player y Enemy.

---

## 🔴 ÁREAS CRÍTICAS QUE NECESITAN COMPOSITION

### 1. Sistema de Movimiento y Navegación

**Problema Actual:**
```gdscript
# enemy.gd - Línea 73
func _move_logic(target_pos: Vector3, movement_speed: float):
    nav_agent.target_position = target_pos
    # ... código duplicado

# player.gd
# Similar lógica de navegación dispersa
```

**Solución: `MovementComponent`**
```gdscript
class_name MovementComponent
extends Node

signal movement_started(target_position)
signal movement_stopped()
signal velocity_changed(new_velocity)

@export var base_speed: float = 5.0
@export var acceleration: float = 10.0

var nav_agent: NavigationAgent3D
var stats: StatsComponent
var status_controller: StatusController
var body: CharacterBody3D

func setup(character_body: CharacterBody3D, stats_comp: StatsComponent, nav: NavigationAgent3D) -> void:
    body = character_body
    stats = stats_comp
    nav_agent = nav

func move_to(target: Vector3) -> void:
    if not can_move():
        return
    nav_agent.target_position = target
    movement_started.emit(target)

func stop() -> void:
    nav_agent.target_position = body.global_position
    movement_stopped.emit()

func get_current_speed() -> float:
    if not stats:
        return base_speed
    return base_speed * stats.get_move_speed_modifier()

func can_move() -> bool:
    if status_controller:
        return status_controller.can_move()
    return true

func get_next_velocity() -> Vector3:
    if nav_agent.is_navigation_finished():
        return Vector3.ZERO
    
    var next_pos = nav_agent.get_next_path_position()
    var direction = (next_pos - body.global_position).normalized()
    return direction * get_current_speed()
```

**Beneficios:**
- Player y Enemy comparten la misma lógica de movimiento
- Buffs de velocidad se aplican automáticamente desde `StatsComponent`
- Estados como STUN detienen el movimiento sin código adicional
- Fácil de testear y depurar

---

### 2. Sistema de Combate

**Problema Actual:**
```gdscript
# player.gd - Línea 266
var damage = attack_damage + stats.str_stat
target.health_component.take_damage(damage)

# enemy.gd - Línea 215
var dmg = data.attack + stats_comp.str_stat
player.health_component.take_damage(dmg)
```

**Solución: `CombatComponent`**
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
var damage_calculator: DamageCalculator
var last_attack_time: int = 0

func setup(stats_comp: StatsComponent) -> void:
    stats = stats_comp

func can_attack(target: Node3D) -> bool:
    if not status_controller or not status_controller.can_attack():
        return false
    
    var time_since_attack = Time.get_ticks_msec() - last_attack_time
    if time_since_attack < attack_cooldown * 1000:
        return false
    
    var distance = get_parent().global_position.distance_to(target.global_position)
    return distance <= attack_range

func perform_attack(target: Node3D) -> void:
    if not can_attack(target):
        return
    
    last_attack_time = Time.get_ticks_msec()
    attack_started.emit(target)
    
    # Calcular daño usando el sistema centralizado
    var damage = DamageCalculator.calculate_physical(
        get_parent(), 
        target
    )
    
    if damage > 0:
        if target.has_node("HealthComponent"):
            target.get_node("HealthComponent").take_damage(damage)
            hit_landed.emit(target, damage)
    else:
        attack_missed.emit(target)

func get_attack_speed() -> float:
    return stats.get_attack_speed() if stats else 1.0
```

**Beneficios:**
- Lógica de combate unificada
- Sistema de HIT/FLEE automático vía `DamageCalculator`
- Fácil aplicar efectos (críticos, elementos, etc.)

---

### 3. Sistema de Estados - ⭐ CRÍTICO

**Problema Actual:**
```gdscript
# Variables booleanas dispersas en múltiples archivos
var is_stunned: bool = false
var is_dead: bool = false
var is_aggroed: bool = false
var current_state = State.IDLE
```

**Solución: `StatusController`**
```gdscript
class_name StatusController
extends Node

signal status_changed(new_status, old_status)
signal can_move_changed(can_move)
signal can_attack_changed(can_attack)
signal can_cast_changed(can_cast)

enum Status { 
    NORMAL,
    STUNNED,    # No se mueve, no ataca, no castea
    ROOTED,     # No se mueve, pero ataca/castea
    SILENCED,   # No castea, pero se mueve/ataca
    FROZEN,     # No se mueve, no ataca, no castea (como stun pero con visual diferente)
    DEAD
}

var current_status: Status = Status.NORMAL
var status_timers: Dictionary = {}

func apply_status(status: Status, duration: float = -1.0) -> void:
    var old_status = current_status
    current_status = status
    
    status_changed.emit(status, old_status)
    can_move_changed.emit(can_move())
    can_attack_changed.emit(can_attack())
    can_cast_changed.emit(can_cast())
    
    if duration > 0:
        status_timers[status] = Time.get_ticks_msec() + int(duration * 1000)

func can_move() -> bool:
    return current_status not in [Status.STUNNED, Status.ROOTED, Status.FROZEN, Status.DEAD]

func can_attack() -> bool:
    return current_status not in [Status.STUNNED, Status.FROZEN, Status.DEAD]

func can_cast() -> bool:
    return current_status not in [Status.STUNNED, Status.SILENCED, Status.FROZEN, Status.DEAD]

func is_alive() -> bool:
    return current_status != Status.DEAD

func _process(delta: float) -> void:
    # Verificar timers de estados temporales
    var current_time = Time.get_ticks_msec()
    for status in status_timers.keys():
        if current_time >= status_timers[status]:
            status_timers.erase(status)
            if current_status == status:
                apply_status(Status.NORMAL)
```

**Integración con StatusEffectManager:**
```gdscript
# En StatusEffectManager.gd
func _apply_effect_logic(data: StatusEffectData, is_applying: bool):
    var mult = 1 if is_applying else -1
    
    match data.type:
        StatusEffectData.EffectType.STUN:
            var status_ctrl = get_parent().get_node_or_null("StatusController")
            if status_ctrl:
                if is_applying:
                    status_ctrl.apply_status(StatusController.Status.STUNNED, data.duration)
                else:
                    status_ctrl.apply_status(StatusController.Status.NORMAL)
```

**Beneficios:**
- Estados centralizados y verificables
- Fácil añadir nuevos estados (FROZEN, PETRIFIED, etc.)
- Integración automática con todos los sistemas

---

### 4. Sistema de IA (Enemigos)

**Problema Actual:**
```gdscript
# enemy.gd - Línea 30+
enum State { IDLE, WANDERING, CHASING, ATTACKING }
var current_state = State.IDLE

func patrol_logic(delta): ...
func attack_player(): ...
```

**Solución: `AIController` (Base abstracta)**
```gdscript
class_name AIController
extends Node

signal target_acquired(target)
signal target_lost()
signal state_changed(new_state)

var target: Node3D
var owner_entity: CharacterBody3D
var stats: StatsComponent
var movement: MovementComponent
var combat: CombatComponent

func setup(entity: CharacterBody3D) -> void:
    owner_entity = entity
    stats = entity.get_node_or_null("StatsComponent")
    movement = entity.get_node_or_null("MovementComponent")
    combat = entity.get_node_or_null("CombatComponent")

# Métodos abstractos (override en subclases)
func process_ai(delta: float) -> void:
    pass

func on_target_detected(detected_target: Node3D) -> void:
    target = detected_target
    target_acquired.emit(target)

func on_target_lost() -> void:
    target = null
    target_lost.emit()
```

**Subclases especializadas:**
```gdscript
# MeleeAI.gd
class_name MeleeAI
extends AIController

enum State { IDLE, PATROLLING, CHASING, ATTACKING }
var current_state: State = State.IDLE

func process_ai(delta: float) -> void:
    if not target or not target.is_inside_tree():
        current_state = State.PATROLLING
        patrol()
        return
    
    var distance = owner_entity.global_position.distance_to(target.global_position)
    
    if distance <= combat.attack_range:
        current_state = State.ATTACKING
        movement.stop()
        combat.perform_attack(target)
    elif distance <= stats.get_aggro_range():
        current_state = State.CHASING
        movement.move_to(target.global_position)
    else:
        on_target_lost()

# RangedAI.gd
class_name RangedAI
extends AIController

@export var preferred_distance: float = 5.0
@export var min_distance: float = 3.0

func process_ai(delta: float) -> void:
    if not target:
        return
    
    var distance = owner_entity.global_position.distance_to(target.global_position)
    
    # Mantener distancia óptima
    if distance < min_distance:
        # Retroceder
        var away_dir = (owner_entity.global_position - target.global_position).normalized()
        movement.move_to(owner_entity.global_position + away_dir * 3.0)
    elif distance > preferred_distance:
        # Acercarse
        movement.move_to(target.global_position)
    else:
        # Atacar
        movement.stop()
        combat.perform_attack(target)
```

**Beneficios:**
- Fácil crear nuevos tipos de enemigos (Boss, Passive, Aggressive, Support)
- Comportamiento consistente y predecible
- Reutilizable para NPCs aliados

---

### 5. Sistema de Cálculo de Daño

**Problema Actual:**
```gdscript
# Daño calculado directamente en múltiples lugares
var damage = attack_damage + stats.str_stat
```

**Solución: `DamageCalculator` (Singleton/Static)**
```gdscript
class_name DamageCalculator
extends Node

# Fórmula estilo Ragnarok Online
static func calculate_physical(attacker: Node, defender: Node) -> int:
    var atk_stats = attacker.get_node("StatsComponent")
    var def_stats = defender.get_node("StatsComponent")
    
    if not atk_stats or not def_stats:
        return 0
    
    # 1. Verificar HIT vs FLEE (Chance de evadir)
    var hit_chance = calculate_hit_chance(atk_stats, def_stats)
    if randf() > hit_chance:
        return 0  # MISS
    
    # 2. Calcular daño base
    var atk = atk_stats.get_atk()
    var def_value = def_stats.get_def()
    
    # Fórmula: ATK - DEF + Variación (±10%)
    var base_damage = atk - def_value
    var variance = randf_range(-0.1, 0.1)
    base_damage += int(base_damage * variance)
    
    # 3. Verificar crítico (basado en LUK)
    if is_critical_hit(atk_stats):
        base_damage *= 1.4  # +40% de daño
    
    return max(1, base_damage)  # Mínimo 1 de daño

static func calculate_magical(attacker: Node, defender: Node) -> int:
    var atk_stats = attacker.get_node("StatsComponent")
    var def_stats = defender.get_node("StatsComponent")
    
    if not atk_stats or not def_stats:
        return 0
    
    var matk = atk_stats.get_matk()
    var mdef = def_stats.get_def()  # Usa DEF normal o podrías tener MDEF separado
    
    var damage = matk - (mdef * 0.5)  # MDEF reduce menos que DEF físico
    return max(1, int(damage))

static func calculate_hit_chance(attacker_stats: StatsComponent, defender_stats: StatsComponent) -> float:
    var hit = attacker_stats.get_hit()
    var flee = defender_stats.get_flee()
    
    # Fórmula RO: 80% base + (HIT - FLEE) / 10
    var chance = 0.8 + (hit - flee) * 0.01
    return clamp(chance, 0.05, 0.95)  # Mínimo 5%, máximo 95%

static func is_critical_hit(attacker_stats: StatsComponent) -> bool:
    var luk = attacker_stats.get_total_luk()
    var crit_chance = luk * 0.003  # 0.3% por punto de LUK
    return randf() < crit_chance
```

**Beneficios:**
- Balanceo centralizado
- Fácil ajustar fórmulas
- Consistencia entre todos los atacantes

---

### 6. Sistema de Detección y Visión

**Problema Actual:**
```gdscript
# enemy.gd
if dist_to_player <= data.aggro_range:
    is_aggroed = true
```

**Solución: `DetectionComponent`**
```gdscript
class_name DetectionComponent
extends Area3D

signal target_detected(target)
signal target_lost(target)
signal alert_triggered(position)  # Para avisar a aliados cercanos

@export var detection_range: float = 10.0
@export var lose_range: float = 15.0
@export var detection_angle: float = 360.0  # Campo de visión (360 = omnidireccional)
@export var target_group: String = "player"
@export var check_line_of_sight: bool = false

var current_targets: Array[Node3D] = []
var stats: StatsComponent

func _ready():
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)
    
    # Configurar forma de detección
    var shape = SphereShape3D.new()
    shape.radius = detection_range
    var collision_shape = CollisionShape3D.new()
    collision_shape.shape = shape
    add_child(collision_shape)

func _on_body_entered(body: Node3D) -> void:
    if not body.is_in_group(target_group):
        return
    
    if check_line_of_sight and not has_line_of_sight(body):
        return
    
    if not current_targets.has(body):
        current_targets.append(body)
        target_detected.emit(body)

func _on_body_exited(body: Node3D) -> void:
    if current_targets.has(body):
        current_targets.erase(body)
        target_lost.emit(body)

func has_line_of_sight(target: Node3D) -> bool:
    var space_state = get_world_3d().direct_space_state
    var from = global_position
    var to = target.global_position
    
    var query = PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [get_parent()]
    
    var result = space_state.intersect_ray(query)
    
    if result:
        return result.collider == target
    return true

func is_in_view_angle(target: Node3D) -> bool:
    if detection_angle >= 360.0:
        return true
    
    var to_target = (target.global_position - global_position).normalized()
    var forward = -global_transform.basis.z
    var angle = rad_to_deg(to_target.angle_to(forward))
    
    return angle <= detection_angle / 2.0

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
- Reutilizable para enemigos, torres, NPCs
- Sistema de alerta grupal
- Línea de visión automática

---

### 7. Sistema de Animación y Efectos

**Problema Actual:** Esparcido por todo el código

**Solución: `AnimationController` + `EffectController`**

```gdscript
# AnimationController.gd
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

```gdscript
# EffectController.gd
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

### 8. Sistema de Cooldowns Genérico

**Solución: `CooldownManager`**
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

### 9. Sistema de Loot Centralizado

**Solución: `LootManager` (Singleton)**
```gdscript
# LootManager.gd (AutoLoad)
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

### 10. Sistema de Experiencia Centralizado

**Solución: `ExperienceManager` (Singleton)**
```gdscript
# ExperienceManager.gd (AutoLoad)
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

## ESTRUCTURA IDEAL DE ENTIDADES

### Player
```
Player (CharacterBody3D)
├── StatsComponent
├── HealthComponent
├── SPComponent
├── StatusController ⭐
├── StatusEffectManager
├── EquipmentComponent
├── InventoryComponent
├── SkillComponent
├── RegenerationComponent
├── MovementComponent ⭐
├── CombatComponent ⭐
├── AnimationController ⭐
├── EffectController ⭐
├── CooldownManager ⭐
└── CameraPivot
```

### Enemy
```
Enemy (CharacterBody3D)
├── StatsComponent
├── HealthComponent
├── SPComponent (opcional, si usa skills)
├── StatusController ⭐
├── StatusEffectManager
├── SkillComponent (opcional)
├── RegenerationComponent
├── MovementComponent ⭐
├── CombatComponent ⭐
├── AIController ⭐ (MeleeAI, RangedAI, BossAI)
├── DetectionComponent ⭐
├── AnimationController ⭐
├── EffectController ⭐
└── HealthBar3D
```

---

## MANAGERS GLOBALES (Singletons/AutoLoad)

```
Singletons/
├── DamageCalculator ⭐ (Cálculos de daño)
├── LootManager ⭐ (Generación de drops)
├── ExperienceManager ⭐ (XP y leveling)
└── EventBus (Comunicación entre sistemas)
```

---

## PRIORIDAD DE IMPLEMENTACIÓN

### 🔴 CRÍTICO (Implementar primero)
1. **`StatusController`** - Centraliza todos los estados (stunned, dead, etc.)
   - Reemplaza variables booleanas dispersas
   - Integrar con `StatusEffectManager` existente

2. **`MovementComponent`** - Afecta a todo el gameplay
   - Unifica lógica de navegación
   - Respeta modificadores de velocidad

3. **`CombatComponent`** - Core del juego
   - Unifica sistema de ataque
   - Integra con `DamageCalculator`

### 🟠 ALTO (Implementar después)
4. **`DamageCalculator`** - Balanceo del juego
   - Fórmulas centralizadas
   - Sistema HIT/FLEE/CRIT

5. **`AIController`** - Comportamiento de enemigos
   - Diferentes tipos de IA
   - Reutilizable para NPCs

### 🟡 MEDIO (Implementar cuando haya tiempo)
6. **`DetectionComponent`** - Aggro y visión
7. **`AnimationController`** - Visuales
8. **`EffectController`** - VFX
9. **`CooldownManager`** - Sistema genérico de cooldowns

### 🟢 BAJO (Nice to have)
10. **`LootManager`** - Centralización de drops
11. **`ExperienceManager`** - XP compartida, bonos

---

## VENTAJAS DE COMPOSITION vs INHERITANCE

### ✅ Con Composition:
```gdscript
# Crear un nuevo tipo de enemigo: Boss Ranged con Regeneración
var boss = Enemy.new()
boss.add_child(RangedAI.new())
boss.add_child(RegenerationComponent.new())
# ¡Listo! Sin herencia múltiple ni copiar código
```

### ❌ Sin Composition (Herencia):
```gdscript
# Necesitarías:
class EnemyRanged extends Enemy
class EnemyBoss extends Enemy
class EnemyRangedBoss extends EnemyRanged  # ¿Y si quiero jefe mele también?
# Se vuelve un árbol de herencia complejo
```

---

## EJEMPLOS DE USO

### Crear un Nuevo Enemigo con Components
```gdscript
# enemy_flying_mage.tscn
[node name="FlyingMage" type="CharacterBody3D"]

[node name="StatsComponent"]
[node name="HealthComponent"]
[node name="MovementComponent"]  # Con velocidad rápida
[node name="CombatComponent"]    # Ataque mágico
[node name="RangedAI"]           # Mantiene distancia
[node name="DetectionComponent"] # Aggro a 15m
[node name="AnimationController"]
```

### Aplicar un Buff que Aumenta Velocidad
```gdscript
# El StatusEffectManager automáticamente:
# 1. Aplica bono de velocidad a StatsComponent
# 2. MovementComponent lee la velocidad modificada
# 3. El personaje se mueve más rápido
# ¡Sin tocar código de movimiento!

var speed_buff = load("res://resources/statusEffects/swift_step.tres")
status_effect_manager.add_effect(speed_buff)
```

---

## PASOS PARA REFACTORIZAR

1. **Crear componentes nuevos** en `/scripts/components/`
2. **Testear componentes individualmente** con escenas simples
3. **Integrar uno por uno** en Player primero
4. **Migrar Enemy** después de validar con Player
5. **Eliminar código legacy** gradualmente
6. **Documentar** cada componente con ejemplos

---

## CONCLUSIÓN

El proyecto ya tiene una **base sólida** con los componentes existentes. Los componentes propuestos completarían el sistema para tener una arquitectura **totalmente modular y reutilizable**.

**Próximo paso recomendado:** Implementar `StatusController` para centralizar todos los estados, ya que actualmente hay variables booleanas dispersas que causan bugs potenciales.

¿Necesitas ayuda implementando alguno de estos componentes?
