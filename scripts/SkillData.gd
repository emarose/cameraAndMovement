extends Resource
class_name SkillData

enum SkillType { TARGET, POINT, SELF }

@export_group("Configuración")
@export var id: String = "" # Identificador único (ej: "bash", "magnum_break")
@export var skill_name: String = "Habilidad"
@export var type: SkillType = SkillType.TARGET # Define si es click a enemigo o al suelo
@export var sp_cost: int = 10
@export var cast_range: float = 5.0 # Distancia máxima para lanzar
@export var damage_multiplier: float = 1.0
@export var cooldown: float = 1.0
@export var icon: Texture2D
@export var element: StatsComponent.Element = StatsComponent.Element.NEUTRAL

@export_group("Área de Efecto")
@export var aoe_radius: float = 3.0 # Radio de la explosión
@export var effect_scene: PackedScene # El prefab visual (fuego, hielo, etc)

@export_group("Efectos de Estado")
@export var status_effects: Array[StatusEffectData] = [] # Status effects a aplicar
@export var status_effect_chance: float = 1.0 # Chance de aplicar (0.0 - 1.0)

@export_group("Casteo")
@export var cast_time: float = 0.0 # 0.0 = Instantáneo
@export var is_interruptible: bool = true # Si es true, moverse o recibir daño cancela
@export var cast_animation_name: String = "cast" # Nombre de la animación a reproducir

@export_group("IA Enemiga")
@export var ai_use_chance: float = 1.0 # Probabilidad que un enemigo use esta skill (0.0 - 1.0)

@export_group("Árbol de Habilidades")
@export var max_level: int = 5 # Nivel máximo de la skill
@export var required_job_level: int = 1 # Job Level requerido para aprender
@export var required_skills: Array[SkillData] = [] # Skills previas requeridas

@export_group("Pasivas")
@export var is_passive: bool = false # Si es true, no necesita armarse ni ejecutarse
@export var passive_stat_bonuses: Dictionary = {} # Ej: {"str": 2, "agi": 1, "atk": 5} por nivel
@export var passive_hp_regen: int = 0 # HP regenerado por nivel cada tick
@export var passive_sp_regen: int = 0 # SP regenerado por nivel cada tick
@export var passive_hp_regen_percent: float = 0.0 # Modificador % (0.1 = +10% por nivel)
@export var passive_sp_regen_percent: float = 0.0 # Modificador % (0.1 = +10% por nivel)
@export var passive_speed_bonus: float = 0.0 # Velocidad % (0.05 = +5% por nivel)
