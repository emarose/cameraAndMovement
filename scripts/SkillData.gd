extends Resource
class_name SkillData

enum SkillType { TARGET, POINT, SELF }

@export_group("Configuración")
@export var skill_name: String = "Habilidad"
@export var type: SkillType = SkillType.TARGET # Define si es click a enemigo o al suelo
@export var sp_cost: int = 10
@export var cast_range: float = 5.0 # Distancia máxima para lanzar
@export var damage_multiplier: float = 1.0
@export var cooldown: float = 1.0

@export_group("Área de Efecto")
@export var aoe_radius: float = 3.0 # Radio de la explosión
@export var effect_scene: PackedScene # El prefab visual (fuego, hielo, etc)
