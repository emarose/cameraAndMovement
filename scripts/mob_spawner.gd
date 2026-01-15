extends Node3D

@export_group("Configuración")
@export var enemy_scene: PackedScene
@export var mob_pool: Array[EnemyData]
@export var spawn_radius: float = 15.0
@export var max_mobs: int = 8
@export var spawn_interval: float = 5.0

var active_mobs: int = 0

func _ready():
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = spawn_interval
	timer.timeout.connect(_on_timer_timeout)
	timer.start()
	
	await get_tree().create_timer(0.5).timeout
	for i in range(max_mobs):
		spawn_mob()

func _on_timer_timeout():
	if active_mobs < max_mobs:
		spawn_mob()

func spawn_mob():
	if not enemy_scene or mob_pool.is_empty(): return
	
	var mob = enemy_scene.instantiate()
	mob.data = mob_pool[randi() % mob_pool.size()]
	
	# Calcular posición aleatoria
	var angle = randf() * PI * 2
	var dist = sqrt(randf()) * spawn_radius
	var raw_pos = global_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	
	# Ajustar a NavMesh
	var map = get_world_3d().navigation_map
	var spawn_pos = NavigationServer3D.map_get_closest_point(map, raw_pos)

	# Añadir al árbol ANTES de setear posiciones globales
	get_tree().current_scene.add_child(mob)
	
	# Seteo inmediato
	mob.global_position = spawn_pos
	if mob.has_method("set"): # O simplemente acceso directo si confías en el script
		mob.home_position = spawn_pos
		mob.wander_target = spawn_pos
	
	active_mobs += 1
	mob.tree_exited.connect(func(): active_mobs -= 1)
	
