extends Node

# Matriz: [Elemento Atacante][Elemento Defensor]
var element_chart = {
	StatsComponent.Element.FIRE: {
		StatsComponent.Element.EARTH: 1.5,
		StatsComponent.Element.FIRE: 0.5,
		StatsComponent.Element.WATER: 0.5,
		StatsComponent.Element.UNDEAD: 2.0,
	},
	StatsComponent.Element.WATER: {
		StatsComponent.Element.FIRE: 1.5,
		StatsComponent.Element.WATER: 0.5,
		StatsComponent.Element.EARTH: 0.5,
	},
	StatsComponent.Element.WIND: {
		StatsComponent.Element.WATER: 1.75,
		StatsComponent.Element.EARTH: 0.5,
	},
	StatsComponent.Element.EARTH: {
		StatsComponent.Element.WIND: 1.5,
		StatsComponent.Element.FIRE: 0.5,
	},
	StatsComponent.Element.HOLY: {
		StatsComponent.Element.SHADOW: 2.0,
		StatsComponent.Element.UNDEAD: 2.0,
		StatsComponent.Element.HOLY: 0.0, # Sanar o 0 daño
	},
	StatsComponent.Element.GHOST: {
		StatsComponent.Element.NEUTRAL: 0.0, # Fantasmas no reciben daño físico normal
		StatsComponent.Element.GHOST: 1.5,
	}
}

func get_element_modifier(atk_elem: StatsComponent.Element, def_elem: StatsComponent.Element) -> float:
	if element_chart.has(atk_elem):
		if element_chart[atk_elem].has(def_elem):
			return element_chart[atk_elem][def_elem]
	
	# Si atacamos con algo que no sea Neutral a un Ghost, y no está en la tabla,
	# podríamos querer que haga poco daño. Por ahora, 1.0 por defecto.
	return 1.0

func calculate_skill_damage(base_dmg: int, skill_elem: StatsComponent.Element, target_stats: StatsComponent) -> int:
	var multiplier = get_element_modifier(skill_elem, target_stats.element)
	# if skill_elem == StatsComponent.Element.HOLY and target_stats.race == StatsComponent.Race.DEMON:
	#    multiplier += 0.5
	
	return int(base_dmg * multiplier)

func calculate_final_damage(base_dmg: int, atk_stats: StatsComponent, target_stats: StatsComponent, skill_elem: int = -1) -> int:
	# 1. Determinar el elemento del ataque
	# Si skill_elem es -1, es un golpe normal (usa el elemento del arma)
	var final_atk_elem = skill_elem if skill_elem >= 0 else atk_stats.weapon_element
	
	# 2. Multiplicador de Tabla Elemental (Fuego vs Agua, etc)
	var multiplier = get_element_modifier(final_atk_elem, target_stats.element)
	
	# 3. Aplicar Bonos Pasivos (Cards/Equipamiento)
	# Bono contra Raza
	multiplier += atk_stats.get_race_modifier(target_stats.race)
	
	# Bono contra Elemento del enemigo (Ej: +20% daño a enemigos de Agua)
	multiplier += atk_stats.get_element_modifier_bonus(target_stats.element)
	
	# 4. Cálculo final
	return int(base_dmg * multiplier)
