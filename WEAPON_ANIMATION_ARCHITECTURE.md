# Arquitectura del Sistema de Animaciones por Arma

## Descripción General

El sistema de animaciones ha sido reestructurado para que **cada arma equipada defina y ejecute sus propias animaciones de ataque**, en lugar de depender de un único AnimationTree preconfigurado con todos los estados.

## Arquitectura

### División de Responsabilidades

1. **AnimationTree**: Se usa exclusivamente para locomoción básica
   - Idle
   - Move
   - Flinch
   - Cast

2. **AnimationPlayer**: Se usa para animaciones específicas de combate con armas
   - Attack animations (específicas de cada arma)
   - Las animaciones se cargan dinámicamente al equipar un arma

### Cómo Funciona

#### 1. Definición en EquipmentItem.gd

Cada arma puede definir sus animaciones de dos formas:

```gdscript
# Opción A: Usando un recurso de Animation (carga dinámica)
@export var idle_animation_resource: Animation
@export var attack_start_animation_resource: Animation
@export var attack_release_animation_resource: Animation

# Opción B: Referenciando una animación existente por nombre
@export var idle_animation_name: StringName = &""
@export var attack_start_animation_name: StringName = &""
@export var attack_release_animation_name: StringName = &""
```

**Prioridad**: Si existe `animation_resource`, se carga dinámicamente. Si no, se usa `animation_name`.

#### 2. Carga Dinámica al Equipar (Player.gd)

Cuando se equipa un arma, se llama a `load_weapon_animations()`:

```gdscript
func load_weapon_animations(weapon: EquipmentItem) -> void:
    # 1. Obtiene/crea la AnimationLibrary del AnimationPlayer
    # 2. Si el arma tiene animation_resource, lo carga como "weapon_idle", "weapon_attack_start", etc.
    # 3. Si no, usa el animation_name para referenciar animaciones existentes
    # 4. Guarda las referencias en variables:
    #    - current_weapon_idle_anim
    #    - current_weapon_attack_start_anim
    #    - current_weapon_attack_release_anim
```

#### 3. Reproducción Durante el Combate (Player.gd)

En `execute_attack()`, se usa `animation_player.play()` directamente:

```gdscript
# Reproducir animación de inicio de ataque
if current_weapon_attack_start_anim != "" and animation_player.has_animation(current_weapon_attack_start_anim):
    animation_player.play(current_weapon_attack_start_anim)
elif animation_player.has_animation("attack_1"):
    animation_player.play("attack_1")  # Fallback
```

### Sistema de Fallbacks

El sistema tiene varios niveles de fallback para evitar errores:

1. **Nivel 1**: Usar la animación del arma (`current_weapon_attack_start_anim`)
2. **Nivel 2**: Usar animación por defecto (`attack_1`)
3. **Nivel 3**: Si no existe ninguna, mostrar warning en consola

## Configuración de Armas

### Ejemplo 1: Arma con Animaciones Existentes (Knife)

```tres
[resource]
script = ExtResource("1_knife")
atk_bonus = 15
idle_animation_name = &"idle"
attack_start_animation_name = &"attack_1"
attack_release_animation_name = &"attack_1"
item_name = "Knife"
```

Requiere que el AnimationPlayer del modelo tenga las animaciones `idle` y `attack_1`.

### Ejemplo 2: Arma con Animaciones Personalizadas (Bow)

```tres
[resource]
script = ExtResource("1")
atk_bonus = 20
is_ranged = true
idle_animation_name = &"idle_bow"
attack_start_animation_name = &"bow_draw"
attack_release_animation_name = &"bow_release"
item_name = "Hunter's Bow"
```

Requiere que el AnimationPlayer tenga `idle_bow`, `bow_draw`, y `bow_release`.

### Ejemplo 3: Arma con Animación Cargada Dinámicamente (Futuro)

Para cargar una animación completamente nueva:

1. Crea un recurso `.anim` o `.res` con tu Animation
2. Asígnalo al arma:

```tres
[resource]
script = ExtResource("1")
atk_bonus = 30
idle_animation_resource = ExtResource("custom_idle_anim")
attack_start_animation_resource = ExtResource("custom_start_anim")
attack_release_animation_resource = ExtResource("custom_release_anim")
item_name = "Magic Staff"
```

El sistema automáticamente cargará estas animaciones con los nombres:
- `weapon_idle`
- `weapon_attack_start`
- `weapon_attack_release`

## Ventajas del Sistema

### ✅ Modularidad
- Cada arma es independiente
- No necesitas modificar el AnimationTree para agregar nuevas armas

### ✅ Flexibilidad
- Soporta tanto animaciones existentes como nuevas
- Permite cargar animaciones dinámicamente en runtime

### ✅ Seguridad
- Múltiples niveles de fallback
- Warnings claros cuando falta una animación
- No causa crashes si una animación no existe

### ✅ Mantenibilidad
- Fácil agregar nuevas armas
- Fácil cambiar animaciones de armas existentes
- No hay acoplamiento con el AnimationTree

## Flujo de Trabajo para Agregar Nueva Arma

1. **Crea el recurso de EquipmentItem** (`.tres`)
   - Define `atk_bonus`, `attack_range`, etc.
   - Define `idle_animation_name`, `attack_start_animation_name`, `attack_release_animation_name`

2. **Prepara las animaciones**
   - **Opción A**: Usa animaciones que ya existen en el modelo del personaje
   - **Opción B**: Crea nuevas animaciones (.anim) y asígnalas a `animation_resource`

3. **Configura el modelo 3D del arma** (opcional)
   - Asigna el `model` (PackedScene) del arma

4. **Prueba en el juego**
   - Equipa el arma
   - Verifica que las animaciones se reproduzcan correctamente
   - Revisa la consola por warnings

## Debugging

### Mensaje de Carga de Animaciones

Cuando equipas un arma, verás en la consola:

```
Player: Loaded weapon animations - idle: bow_idle, attack_start: bow_draw, attack_release: bow_release
```

### Warnings Comunes

```
Player: No attack start animation found
```
**Solución**: Asegúrate de que el arma tiene definido `attack_start_animation_name` o `attack_start_animation_resource`.

## Animaciones Requeridas en el AnimationPlayer Base

Para el sistema de locomoción (AnimationTree), se necesitan:
- `idle` (o variantes como `idle_bow`)
- `walk` / `run`
- `flinch`
- `cast`

Para ataques por defecto (fallback):
- `attack_1`

## Diferencias con el Sistema Anterior

### Antes (Basado en StateMachine)
```gdscript
# Las animaciones estaban en el AnimationTree StateMachine
var state_machine_playback = animation_tree.get("parameters/playback")
state_machine_playback.travel("bow_draw")
```

❌ Problema: Todas las animaciones de todas las armas debían estar en el StateMachine

### Ahora (Basado en AnimationPlayer)
```gdscript
# Las animaciones se cargan dinámicamente y se reproducen directamente
animation_player.play(current_weapon_attack_start_anim)
```

✅ Solución: Cada arma define sus animaciones independientemente

## Conclusión

Este sistema permite una verdadera modularidad en las animaciones de combate, donde cada arma es responsable de sus propias animaciones, mientras el AnimationTree se mantiene simple y enfocado en la locomoción del personaje.
