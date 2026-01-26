extends Resource
class_name EnemyData

@export_group("Common")
@export var monster_name: String = "Monster"
@export var level: int = 1

@export var type: StatsComponent.Size = StatsComponent.Size.MEDIUM
@export var race: StatsComponent.Race = StatsComponent.Race.FORMLESS
@export var element: StatsComponent.Element = StatsComponent.Element.NEUTRAL

@export var base_exp: int = 10
@export var job_exp: int = 10 # Por si luego añades sistema de jobs

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
@export var skill_use_chance: float = 0.3  # 30% chance de usar skill cuando puede
