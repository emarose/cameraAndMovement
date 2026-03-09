# Weapon-Based Animation System Guide

## Resumen

El sistema de combate ahora reproduce animaciones basadas en el arma equipada en lugar de estar fijadas a la clase del personaje. Esto permite que cualquier clase use diferentes armas con sus propias animaciones únicas.

## Características Principales

✅ **Animaciones por Arma**: Cada arma puede definir sus propias animaciones de idle, inicio de ataque y liberación  
✅ **Melee y Ranged**: Soporte completo para armas cuerpo a cuerpo y a distancia  
✅ **Fallback Automático**: Si un arma no tiene animaciones configuradas, usa animaciones por defecto  
✅ **Integración con EquipmentComponent**: Las animaciones cambian automáticamente al equipar/desequipar armas  

---

## Estructura del Sistema

### 1. Propiedades en EquipmentItem

Se agregaron tres nuevas propiedades exportadas en `EquipmentItem.gd`:

```gdscript
@export_group("Animaciones de Combate")
## Animación cuando el personaje está en idle con esta arma equipada
@export var idle_animation: StringName = &""

## Animación de inicio de ataque (preparación, antes del golpe)
@export var attack_start_animation: StringName = &""

## Animación de liberación del ataque (el golpe/disparo en sí)
@export var attack_release_animation: StringName = &""
```

### 2. Implementación en Player

El jugador ahora:
- Tiene una referencia a `AnimationPlayer` además de `AnimationTree`
- Reproduce animaciones del arma durante los ataques
- Actualiza automáticamente las animaciones cuando cambia el equipo

#### Flujo de Ataque

```gdscript
# 1. Al ejecutar ataque, verificar el arma equipada
var weapon = equipment_component.get_equipped_item(EquipmentItem.EquipmentSlot.WEAPON)

# 2. Reproducir animación de inicio si está configurada
if weapon and weapon.attack_start_animation != "":
    animation_player.play(weapon.attack_start_animation)
else:
    animation_player.play("attack_1")  # Fallback

# 3. Luego de hit_delay, reproducir animación de liberación
if is_ranged:
    if weapon.attack_release_animation != "":
        animation_player.play(weapon.attack_release_animation)
else:
    if weapon.attack_release_animation != "":
        animation_player.play(weapon.attack_release_animation)
```

---

## Configuración de Armas

### Ejemplo: Arma Melee (Espada/Cuchillo)

```gdscript
# resources/items/Knife.tres
[resource]
script = ExtResource("EquipmentItem.gd")
item_name = "Knife"
atk_bonus = 15
is_ranged = false
attack_range = 1.5

# Animaciones
idle_animation = &"idle"
attack_start_animation = &"attack_1"
attack_release_animation = &"attack_1"
```

### Ejemplo: Arma Ranged (Arco)

```gdscript
# resources/items/HunterBow.tres
[resource]
script = ExtResource("EquipmentItem.gd")
item_name = "Hunter's Bow"
atk_bonus = 20
is_ranged = true
attack_range = 8.0
projectile_scene = ExtResource("Arrow.tscn")

# Animaciones
idle_animation = &"idle"
attack_start_animation = &"attack_1"
attack_release_animation = &"attack_1"
```

### Ejemplo: Arma con Animaciones Personalizadas

```gdscript
# resources/items/GreatSword.tres
[resource]
script = ExtResource("EquipmentItem.gd")
item_name = "Great Sword"
atk_bonus = 45
is_ranged = false
attack_range = 2.0

# Animaciones personalizadas para espada grande
idle_animation = &"idle_heavy"
attack_start_animation = &"heavy_attack_windup"
attack_release_animation = &"heavy_attack_slash"
```

---

## Nombres de Animaciones Sugeridos

Según el tipo de arma, puedes usar diferentes nombres de animación:

### Armas Melee
- **Espadas**: `idle`, `sword_attack_1`, `sword_attack_2`, `sword_slash`
- **Dagas**: `idle_dagger`, `dagger_stab`, `dagger_slash`
- **Hachas**: `idle_heavy`, `axe_overhead`, `axe_swing`
- **Lanzas**: `idle_spear`, `spear_thrust`, `spear_spin`

### Armas Ranged
- **Arcos**: `idle_bow`, `bow_draw`, `bow_release`
- **Ballestas**: `idle_crossbow`, `crossbow_load`, `crossbow_fire`
- **Bastones**: `idle_staff`, `staff_channel`, `staff_cast`
- **Armas de Fuego**: `idle_gun`, `gun_aim`, `gun_shoot`

---

## Sistema de Fallback

Si un arma no tiene animaciones configuradas (StringName vacío), el sistema usa animaciones por defecto:

1. **attack_start_animation vacío** → usa `"attack_1"`
2. **attack_release_animation vacío** → usa `"attack_1"`
3. **idle_animation vacío** → usa el idle del state machine

Esto asegura que las armas siempre tengan alguna animación, incluso si no están completamente configuradas.

---

## Integración con AnimationPlayer y AnimationTree

El sistema usa ambos:
- **AnimationTree**: Para transiciones suaves entre estados (Idle, Move, Attack)
- **AnimationPlayer**: Para reproducir animaciones específicas del arma durante ataques

### Cómo Funcionan Juntos

1. El `StateMachine` controla las transiciones entre estados generales
2. Cuando se ejecuta un ataque, `animation_player.play()` reproduce la animación específica del arma
3. Esto permite que diferentes armas tengan diferentes animaciones mientras mantienen las transiciones del state machine

---

## Callbacks y Señales

### equipment_changed Signal

El jugador se conecta a la señal `equipment_changed` de `EquipmentComponent`:

```gdscript
func _on_equipment_changed() -> void:
    _update_idle_animation()
```

Esto asegura que cuando se equipa o desequipa un arma, las animaciones se actualicen automáticamente.

---

## Diferencias Melee vs Ranged

### Armas Melee
```gdscript
# Flujo de animación melee
1. play(weapon.attack_start_animation)  # Preparación
2. await delay (attack_hit_delay)
3. play(weapon.attack_release_animation)  # Golpe
4. Aplicar daño directamente al enemigo
```

### Armas Ranged
```gdscript
# Flujo de animación ranged
1. play(weapon.attack_start_animation)  # Preparar arco/bastón
2. await delay (attack_hit_delay)
3. play(weapon.attack_release_animation)  # Disparar
4. Instanciar proyectil
5. El proyectil aplica daño al llegar
```

---

## Ejemplo Completo: Crear un Arma Nueva

### Paso 1: Crear el Recurso

```gdscript
# resources/items/FireStaff.tres
[gd_resource type="Resource" script_class="EquipmentItem" format=3]

[ext_resource type="Script" path="res://scripts/EquipmentItem.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/Fireball.tscn" id="2"]
[ext_resource type="PackedScene" path="res://assets/weapons/staff.gltf" id="3"]

[resource]
script = ExtResource("1")
item_name = "Fire Staff"
description = "A magical staff that shoots fireballs. +30 ATK, 10.0 range"
item_type = 1
stackable = false
sell_price = 500

slot = 0  # WEAPON
atk_bonus = 30
is_ranged = true
attack_range = 10.0
projectile_scene = ExtResource("2")

# Animaciones personalizadas para bastón
idle_animation = &"idle_staff"
attack_start_animation = &"staff_channel"
attack_release_animation = &"staff_cast"
```

### Paso 2: Asegurarse que las Animaciones Existen

Verifica que tu `AnimationPlayer` tenga las animaciones:
- `idle_staff`
- `staff_channel`
- `staff_cast`

Si no existen, el sistema usará `"attack_1"` como fallback.

### Paso 3: Probar en Juego

1. Agrega el arma al inventario inicial del jugador
2. Equipala desde el UI de equipo
3. Ataca a un enemigo
4. El sistema automáticamente usará las animaciones del bastón

---

## Debugging y Troubleshooting

### El arma no reproduce animaciones

**Problema**: El arma no muestra las animaciones configuradas  
**Solución**:
1. Verifica que `animation_player` no sea null en el jugador
2. Confirma que las animaciones existen en el AnimationPlayer del modelo
3. Revisa que los nombres de animación coincidan exactamente (case-sensitive)

### Las animaciones se ven raras

**Problema**: Las animaciones no se ven bien o se cortan  
**Solución**:
1. Ajusta `attack_hit_delay` y `attack_animation_duration` en el Player
2. Verifica la duración de las animaciones en el AnimationPlayer
3. Asegúrate que las animaciones completen su ciclo

### AnimationPlayer es null

**Problema**: Error "Cannot call play on null instance"  
**Solución**:
1. Verifica que el modelo tenga un nodo AnimationPlayer

2. Actualiza la ruta: `@onready var animation_player = $Mannequin_Medium/AnimationPlayer`
3. Si el modelo usa otro nombre, ajusta la ruta

---

## Mejoras Futuras Posibles

- **Blending de animaciones**: Mezclar suavemente entre idle de diferentes armas
- **Combo system**: Diferentes animaciones según el número de ataque en combo
- **Animaciones de movimiento**: Diferentes formas de caminar según el arma (pesada vs ligera)
- **Animaciones de equipar**: Mostrar animación cuando se equipa el arma
- **Stance system**: Diferentes posturas que afectan las animaciones

---

## Archivos Modificados

### Scripts
- `scripts/EquipmentItem.gd` - Agregadas propiedades de animación
- `scripts/player.gd` - Sistema de reproducción de animaciones por arma

### Recursos
- `resources/items/Knife.tres` - Configurado con animaciones melee
- `resources/items/HunterBow.tres` - Configurado con animaciones ranged

### Nuevos Métodos en Player
- `_update_idle_animation()` - Actualiza idle basado en arma equipada
- `_on_equipment_changed()` - Callback para cambios de equipo

---

## Conclusión

El sistema de animaciones por arma proporciona flexibilidad total para que cada arma tenga su propia identidad visual, manteniendo la compatibilidad con el sistema existente de state machine y soporte para fallback automático.

**Resultado**: Un sistema de combate más dinámico y visualmente rico donde cada arma se siente única.
