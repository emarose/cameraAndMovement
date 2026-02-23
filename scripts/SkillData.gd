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

@export_group("Level Scaling")
@export var sp_cost_base: int = 0 # Base SP cost at level 1 (if > 0, replaces sp_cost)
@export var sp_cost_per_level: int = 0 # Additional SP cost per skill level
@export var damage_per_level: float = 0.0 # Additional damage multiplier per level

@export_group("Healing")
@export var heals: bool = false # If true, this skill heals instead of damaging
@export var heal_base: float = 0.0 # Base healing amount
@export var heal_per_level: float = 0.0 # Additional healing per skill level
@export var heal_int_scaling: float = 0.0 # Healing scales with INT (multiplier)
@export var heal_base_level_scaling: float = 0.0 # Healing scales with caster's base level (multiplier)
@export var heal_target_max_hp_percent: float = 0.0 # % of target's max HP healed (0.0-1.0)

@export_group("Stat Buffs")
@export var applies_stat_buff: bool = false # If true, applies temporary stat buffs
@export var buff_str_per_level: int = 0 # STR increase per skill level
@export var buff_dex_per_level: int = 0 # DEX increase per skill level
@export var buff_int_per_level: int = 0 # INT increase per skill level
@export var buff_agi_per_level: int = 0 # AGI increase per skill level
@export var buff_vit_per_level: int = 0 # VIT increase per skill level
@export var buff_luk_per_level: int = 0 # LUK increase per skill level
@export var buff_duration: float = 0.0 # Buff duration in seconds (0 = permanent via status effect)

@export_group("Árbol de Habilidades")
@export var max_level: int = 5 # Nivel máximo de la skill
@export var required_job_level: int = 1 # Job Level requerido para aprender
@export var required_skills: Array[SkillData] = [] # Skills previas requeridas

@export_group("Pasivas")
@export var is_passive: bool = false # Si es true, no necesita armarse ni ejecutarse
@export var passive_stat_bonuses: Dictionary = {} # Ej: {"str": 2, "agi": 1, "atk": 5} - Bonus PER LEVEL
@export var passive_hp_regen: int = 0 # HP regenerado PER LEVEL cada tick
@export var passive_sp_regen: int = 0 # SP regenerado PER LEVEL cada tick
@export var passive_hp_regen_percent: float = 0.0 # Modificador % PER LEVEL (0.1 = +10% por nivel)
@export var passive_sp_regen_percent: float = 0.0 # Modificador % PER LEVEL (0.1 = +10% por nivel)
@export var passive_speed_bonus: float = 0.0 # Velocidad % PER LEVEL (0.05 = +5% por nivel)
@export var passive_healing_item_bonus: float = 0.0 # Bonus to healing items % PER LEVEL (0.1 = +10% por nivel)
