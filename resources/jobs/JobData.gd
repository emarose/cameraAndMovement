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
