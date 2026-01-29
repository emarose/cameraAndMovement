# --- RegenerationComponent.gd ---
extends Node
class_name RegenerationComponent

signal hp_regenerated(amount: int)
signal sp_regenerated(amount: int)

var stats: StatsComponent
var health_comp: HealthComponent
var sp_comp: SPComponent
var timer: Timer
var is_timer_running: bool = false

func setup(s: StatsComponent, h: HealthComponent, sp: SPComponent):
	stats = s
	health_comp = h
	sp_comp = sp
	
	# Crear timer solo una vez
	if timer == null:
		timer = Timer.new()
		timer.wait_time = 3.0 # El tick estándar de RO
		timer.timeout.connect(_on_tick)
		add_child(timer)
	
	# Iniciar timer solo si no está corriendo
	if not is_timer_running and is_inside_tree():
		is_timer_running = true
		# Esperar un frame para que el timer esté completamente en el árbol
		get_tree().create_timer(0.01).timeout.connect(func(): 
			if timer and not timer.is_stopped():
				return
			if timer:
				timer.start()
		)

func _on_tick():
	if not stats: return
	_regen_hp()
	_regen_sp()

func _regen_hp():
	if health_comp.current_health >= health_comp.max_health: return
	
	# Fórmula: Base (1 por cada 200) + Bono (1 por cada 5 VIT) + Modificadores
	var base = max(1, floor(health_comp.max_health / 200.0))
	var vit_bonus = floor(stats.vit / 5.0)
	
	var total = int((base + vit_bonus + stats.hp_regen_flat_bonus) * stats.hp_regen_percent_mod)
	health_comp.heal(total)
	hp_regenerated.emit(total)

func _regen_sp():
	var max_sp = stats.get_max_sp()
	if sp_comp.current_sp >= max_sp: return
	
	# Fórmula: Base (1) + Bono (1 por cada 100 SP) + Bono (1 por cada 6 INT)
	var base = 1.0
	var sp_bonus = floor(max_sp / 100.0)
	var int_bonus = floor(stats.int_stat / 6.0)
	
	# Bono lujo INT 120+
	var luxury = 0
	if stats.int_stat >= 120:
		luxury = 4 + floor((stats.int_stat - 120) / 2.0)
	
	var total = int((base + sp_bonus + int_bonus + luxury + stats.sp_regen_flat_bonus) * stats.sp_regen_percent_mod)
	sp_comp.recover(total)
	sp_regenerated.emit(total)
