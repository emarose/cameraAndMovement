extends Resource
class_name EnemyData

@export_group("Common")
@export var monster_name: String = "Monster"
@export var level: int = 1
@export_enum("Monster", "Boss", "Mini-Boss") var type: String = "Monster"
@export_enum("Brute", "Plant", "Insect", "Undead", "Demon") var race: String = "Brute"
@export_enum("Neutral", "Water", "Earth", "Fire", "Wind", "Ghost") var element: String = "Neutral"
@export var base_exp: int = 10
@export var job_exp: int = 10 # Por si luego añades sistema de jobs
enum MovementType { SLIDE, JUMP, SLITHER } # Slide (Normal), Jump (Poring), Slither (Fabre)
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
@export var movement_type: MovementType = MovementType.SLIDE
@export var jump_frequency: float = 0.8 # Solo para tipos JUMP

@export_group("Patrol")
@export var wander_radius: float = 18.0
@export var idle_time_min: float = 2.0
@export var idle_time_max: float = 7.0
@export var movement_speed_factor: float = 0.2 # Qué tan rápido camina al patrullar (0.5 = 50% de su move_spd)
