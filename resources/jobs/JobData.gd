extends Resource
class_name JobData

@export var job_name: String = "Novice"
@export var job_icon: Texture2D
@export var max_job_level: int = 50
@export var base_skills: Array[SkillData] = [] # Skills que pertenecen a este Job

# Bonos automáticos al elegir el Job
@export var str_bonus: int = 0
@export var agi_bonus: int = 0
@export var int_bonus: int = 0

# Tabla de bonos por nivel (Nivel : {Stat: Cantidad})
# Ejemplo: { 10: {"str": 1}, 15: {"agi": 1} }
@export var job_level_bonuses: Dictionary = {}

@export_group("HP Growth")
@export var base_hp: int = 40 # HP base for level 1
@export var hp_growth: int = 5 # Extra HP per level
@export var vit_hp_factor: int = 15 # HP bonus per VIT point (default RO: 15)

@export_group("SP Growth")
@export var base_sp: int = 10 # SP base for level 1
@export var sp_growth: int = 2 # Extra SP per level
@export var int_sp_factor: int = 10 # SP bonus per INT point (default RO: 10)

# Character model for this job (PackedScene of the character model)
@export var character_model: PackedScene
