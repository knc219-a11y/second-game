extends Node2D

# Placeholder pet: a small copy of the enemy that dropped it (player.gd
# pet_colors tints it) that trails behind the Player
# (on the side away from facing). The passives live in player.gd take_damage;
# the Brute Cub flashes when it blocks a push. It also helps a little in a fight:
# every bite_cooldown s it dashes at the nearest enemy within bite_range of the
# Player and bites for bite_damage (player.gd sets damage, cooldown and pop per
# pet). The bite never pushes the enemy or cancels its swing, so it only chips
# (about 2 damage a second next to the Player's ~30). The green AllyMark under
# its feet tells it apart from enemies.
@export var follow_offset: Vector2 = Vector2(36, -6)
# Higher = catches up faster (exponential smoothing per second).
@export var follow_speed: float = 6.0
@export var flash_duration: float = 0.15
@export var flash_color: Color = Color(1, 0.95, 0.6, 1)
@export var bite_damage: int = 3
@export var bite_cooldown: float = 1.5
@export var bite_range: float = 90.0
# Dash in, bite on arrival, then the normal follow pulls it back.
@export var lunge_speed: float = 600.0
@export var lunge_max_time: float = 0.25
@export var bite_color: Color = Color(1, 1, 1, 1)
# On a bite the pet swells to this size and shrinks back over flash_duration.
@export var bite_pop: float = 1.0
# Spit Imp (player.gd pet kind 3): no dash; it spits a small shot from where it
# stands at the nearest enemy within spit_range of the Player instead.
@export var spits: bool = false
@export var spit_range: float = 260.0
@export var spit_speed: float = 320.0
@export var spit_travel: float = 320.0
# Ally green (like the AllyMark) so it never reads as the ranged enemy's violet
# shot. Only the look grows (spit_visual_scale on Glow/Core/Shadow); the hit
# shape stays at the old 0.7 size so hits land exactly as before.
@export var spit_color: Color = Color(0.45, 1, 0.4, 0.75)
@export var spit_core_color: Color = Color(0.92, 1, 0.85, 1)
@export var spit_visual_scale: float = 2.0
@export var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")

var player: Node2D
var flash_left: float = 0.0
var bite_left: float = 0.0
var lunge_target: Node2D = null
var lunge_left: float = 0.0
var pop_left: float = 0.0

@onready var visual: Node2D = $Visual
@onready var body: Polygon2D = $Visual/Body
@onready var base_color: Color = body.color


func _ready() -> void:
	bite_left = bite_cooldown


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	if lunge_left > 0.0:
		_update_lunge(delta)
	else:
		var target := player.position + Vector2(-player.facing * follow_offset.x, follow_offset.y)
		position = position.lerp(target, 1.0 - exp(-follow_speed * delta))
		visual.scale.x = player.facing
		if bite_left > 0.0:
			bite_left -= delta
		elif not player.is_dead:
			_try_bite()
	if flash_left > 0.0:
		flash_left -= delta
		if flash_left <= 0.0:
			body.color = base_color
	var size := 1.0
	if pop_left > 0.0:
		pop_left -= delta
		size = lerpf(1.0, bite_pop, maxf(pop_left, 0.0) / flash_duration)
	visual.scale = Vector2(signf(visual.scale.x) * size, size)


func flash() -> void:
	body.color = flash_color
	flash_left = flash_duration


# Red Pup passive (player.gd): skip the wait and bite now if an enemy is in
# range. Does nothing mid-dash.
func bite_now() -> void:
	if lunge_left <= 0.0:
		_try_bite()


func _try_bite() -> void:
	var best: Node2D = null
	var best_dist := spit_range if spits else bite_range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_queued_for_deletion():
			continue
		var d: float = enemy.global_position.distance_to(player.global_position)
		if d <= best_dist:
			best = enemy
			best_dist = d
	if best == null:
		return
	if spits:
		_spit(best)
		return
	lunge_target = best
	lunge_left = lunge_max_time
	bite_left = bite_cooldown


func _update_lunge(delta: float) -> void:
	lunge_left -= delta
	if not is_instance_valid(lunge_target) or lunge_target.is_queued_for_deletion():
		lunge_left = 0.0
		return
	# Stop just short of the enemy, on the pet's own side of it.
	var side := 1.0 if global_position.x >= lunge_target.global_position.x else -1.0
	var spot := lunge_target.global_position + Vector2(side * 16.0, 0.0)
	visual.scale.x = -side
	global_position = global_position.move_toward(spot, lunge_speed * delta)
	if global_position.distance_to(spot) < 2.0 or lunge_left <= 0.0:
		lunge_left = 0.0
		if global_position.distance_to(spot) < 24.0:
			lunge_target.take_damage(bite_damage, 0, 1.0, 2)
			body.color = bite_color
			flash_left = flash_duration
			pop_left = flash_duration
			print("Pet bit %s for %d" % [lunge_target.name, bite_damage])


func _spit(target: Node2D) -> void:
	bite_left = bite_cooldown
	var shot := projectile_scene.instantiate()
	shot.hits_enemies = true
	shot.position = global_position
	# Aim at the enemy's body (both sit on their feet, so feet to feet).
	shot.aim = (target.global_position - global_position).normalized()
	shot.speed = spit_speed
	shot.damage = bite_damage
	shot.lifetime = spit_travel / spit_speed
	shot.get_node("Glow").color = spit_color
	shot.get_node("Core").color = spit_core_color
	shot.splash_color = spit_color
	shot.scale = Vector2(0.7, 0.7)
	for part in ["Glow", "Core", "Shadow"]:
		shot.get_node(part).scale = Vector2(spit_visual_scale, spit_visual_scale)
	get_parent().add_child(shot)
	body.color = bite_color
	flash_left = flash_duration
	pop_left = flash_duration
	print("Pet spat at %s" % target.name)
