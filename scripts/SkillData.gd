extends Resource
class_name SkillData

enum SkillType { TARGET, POINT, SELF }

@export_group("Configuración")
@export var skill_name: String = "Habilidad"
@export var type: SkillType = SkillType.TARGET
@export var sp_cost: int = 10
@export var cast_range: float = 5.0
@export var damage_multiplier: float = 1.0
@export var cooldown: float = 1.0
