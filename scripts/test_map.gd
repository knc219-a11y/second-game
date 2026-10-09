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

# Tough variant: this fraction of respawns has more HP, a better drop chance, drops
# the Steel Sword (tier 2) instead of the Iron Sword, and super armor (keeps swinging when hit), drawn bigger and darker to read at a glance.
@export var tough_chance: float = 0.3
@export var tough_hp: int = 100
@export var tough_drop_chance: float = 0.7
@export var tough_drop_tier: int = 2
# Tough enemies rarely drop the Brute Cub (player.gd pet kind 1) instead of
# the normal enemies' Red Pup.
@export var tough_pet_drop_chance: float = 0.08
@export var tough_pet_drop_kind: int = 1
@export var tough_body_scale: float = 1.25
@export var tough_color: Color = Color(0.45, 0.12, 0.2, 1)
# Ranged variant (enemy.gd is_ranged): this further fraction of respawns keeps
# its distance and shoots; low HP, slower, drawn smaller and violet.
@export var ranged_chance: float = 0.2
@export var ranged_hp: int = 20
@export var ranged_move_speed: float = 80.0
@export var ranged_body_scale: float = 0.85
@export var ranged_color: Color = Color(0.5, 0.35, 0.9, 1)

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
	var roll := randf()
	if roll < tough_chance:
		_make_tough(enemy)
	elif roll < tough_chance + ranged_chance:
		_make_ranged(enemy)
	enemies.add_child(enemy)


# Called before add_child, so enemy._ready picks up the new HP and color.
func _make_tough(enemy: Node) -> void:
	enemy.name = "Tough"
	enemy.max_hp = tough_hp
	enemy.drop_chance = tough_drop_chance
	enemy.drop_tier = tough_drop_tier
	enemy.pet_drop_chance = tough_pet_drop_chance
	enemy.pet_drop_kind = tough_pet_drop_kind
	enemy.super_armor = true
	var body := enemy.get_node("Body") as Polygon2D
	body.color = tough_color
	body.scale = Vector2(tough_body_scale, tough_body_scale)


func _make_ranged(enemy: Node) -> void:
	enemy.name = "Ranged"
	enemy.max_hp = ranged_hp
	enemy.move_speed = ranged_move_speed
	enemy.is_ranged = true
	var body := enemy.get_node("Body") as Polygon2D
	body.color = ranged_color
	body.scale = Vector2(ranged_body_scale, ranged_body_scale)
