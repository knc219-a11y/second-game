extends Node2D

# Test map only: keeps a few enemies around so a fight doesn't end after 3 kills.
# While fewer than keep_alive enemies are alive, one more appears every
# respawn_delay s at the nearest map-edge point at least spawn_min_distance px
# from the Player, so there are never more than keep_alive. Stops once the Player is dead (R reloads the scene).
@export var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
@export var keep_alive: int = 3
@export var respawn_delay: float = 1.5
# Map-edge spawn points, inside the walls and clear of rocks.
@export var spawn_points: PackedVector2Array = PackedVector2Array([
	Vector2(60, 60), Vector2(400, 60), Vector2(800, 60), Vector2(1200, 60), Vector2(1540, 60),
	Vector2(60, 450), Vector2(1540, 450),
	Vector2(60, 840), Vector2(400, 840), Vector2(800, 840), Vector2(1200, 840), Vector2(1540, 840),
])
# Kept beyond detect_range (300) so a new enemy never pops up right next to the
# Player. Not strictly off-screen: the map is barely bigger than the view, so an
# off-screen point would mean a 7-15 s walk before the enemy arrives.
@export var spawn_min_distance: float = 400.0

var respawn_left: float = 0.0

@onready var enemies: Node2D = $Enemies
@onready var player: Node2D = $Player


func _physics_process(delta: float) -> void:
	if player.get("is_dead") == true:
		return
	var alive := 0
	for e in enemies.get_children():
		if not e.is_queued_for_deletion():
			alive += 1
	if alive >= keep_alive:
		respawn_left = respawn_delay
		return
	respawn_left -= delta
	if respawn_left <= 0.0:
		respawn_left = respawn_delay
		_spawn_enemy()


func _spawn_enemy() -> void:
	var best := spawn_points[0]
	var best_dist := INF
	for p in spawn_points:
		var d := p.distance_to(player.global_position)
		if d >= spawn_min_distance and d < best_dist:
			best = p
			best_dist = d
	var enemy := enemy_scene.instantiate()
	enemy.position = best
	# Spawned beyond detect_range: make it come for the Player anyway.
	enemy.detect_range = INF
	enemy.lose_range = INF
	enemies.add_child(enemy)
