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
	
	# Ejemplo de bonos por raza (esto es deuda técnica que pagamos ahora):
	# if skill_elem == StatsComponent.Element.HOLY and target_stats.race == StatsComponent.Race.DEMON:
	#    multiplier += 0.5
	
	return int(base_dmg * multiplier)
