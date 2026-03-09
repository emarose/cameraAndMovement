extends Resource
class_name EnemyData

@export_group("Common")
@export var monster_name: String = "Monster"
@export var level: int = 1

@export var type: StatsComponent.Size = StatsComponent.Size.MEDIUM
@export var race: StatsComponent.Race = StatsComponent.Race.FORMLESS
@export var element: StatsComponent.Element = StatsComponent.Element.NEUTRAL

@export var base_exp: int = 10
@export var job_exp: int = 10 

@export_group("Stats (Base)")
@export var str_stat: int = 1
@export var agi: int = 1
@export var vit: int = 1
@export var int_stat: int = 1
@export var dex: int = 1
@export var luk: int = 1	

@export_group("Attributes (Calculados)")
@export var max_hp: int = 50
@export var flee: int = 5
@export var def: int = 5
@export var move_spd: float = 1
@export var aggro_range: float = 5
@export var attack_range: float = 5
@export var lose_aggro_range: float = 15
@export var return_speed: int = 4

@export_group("Visuals")
@export var model_scene: PackedScene
## Yaw correction (degrees) for model forward axis. Use 180 if model faces backwards.
@export_range(-180.0, 180.0, 1.0) var facing_yaw_offset_deg: float = 180.0

@export_group("Collision")
## Auto-creates/resizes CollisionShape3D from the model AABB at runtime.
@export var auto_fit_collision_shape: bool = true
## Auto keeps current shape type if present, otherwise uses Capsule.
@export_enum("Auto", "Capsule", "Box", "Sphere") var collision_shape_mode: int = 0
## Multiplies fitted collision size after AABB + padding.
@export var collision_size_multiplier: Vector3 = Vector3.ONE
## Padding added on each axis (total size uses padding * 2).
@export var collision_padding: Vector3 = Vector3(0.05, 0.0, 0.05)
## Extra offset applied to collision center after fitting.
@export var collision_center_offset: Vector3 = Vector3.ZERO
## Lower bounds to avoid tiny/invalid shapes.
@export var collision_min_size: Vector3 = Vector3(0.2, 0.4, 0.2)

@export_group("Locomotion")
@export var movement_type: StatsComponent.MovementType = StatsComponent.MovementType.SLIDE
@export var jump_frequency: float = 0.3 # Solo para tipos JUMP

@export_group("Patrol")
@export var wander_radius: float = 18.0
@export var idle_time_min: float = 2.0
@export var idle_time_max: float = 7.0
@export var movement_speed_factor: float = 0.5 # Qué tan rápido camina al patrullar (0.5 = 50% de su move_spd)

@export_group("Drops (Loot)")
@export var drop_table: Array[DropEntry] = []  # Tabla de posibles drops (Array de DropEntry)

@export_group("Combat Abilities")
@export var attack_status_effects: Array[StatusEffectData] = []  # Status effects que puede infligir al atacar
@export var status_effect_chance: float = 0.15  # 15% chance por defecto
@export var skills: Array[SkillData] = []  # Skills que el enemigo puede usar
@export var skill_use_chance: float = 0.3  # Enemy AI chance to attempt a skill (0.0-1.0, legacy 0-100 also accepted)

@export_group("Animations")
## Optional AnimationLibrary loaded from res://assets/characters/animations/enemies/.
## Assign one here and its animations become available to the enemy's AnimationPlayer.
@export var animation_library: AnimationLibrary = null
## Animation name for idle standing. Must exist in the AnimationPlayer (or loaded library).
@export var anim_idle: StringName = &"Idle"
## Animation name for walking/running.
@export var anim_walk: StringName = &"Walk"
## Animation name played when attacking.
@export var anim_attack: StringName = &"Punch"
## Animation name played on death.
@export var anim_death: StringName = &"Death"
## Animation name played when flinching (hit received).
@export var anim_flinch: StringName = &"HitRecieve"
## Animation name for the jump impulse (JUMP movement type). Falls back to a tween if empty.
@export var anim_jump: StringName = &"Jump"

## Returns skill_use_chance normalized to [0.0, 1.0].
## Backward compatible with old data using percentage values (e.g. 30, 50, 100).
func get_skill_use_chance_normalized() -> float:
	if skill_use_chance > 1.0:
		return clamp(skill_use_chance / 100.0, 0.0, 1.0)
	return clamp(skill_use_chance, 0.0, 1.0)
