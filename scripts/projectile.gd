extends Area2D

# Ranged enemy's shot (enemy.gd is_ranged): flies straight left/right along the
# line it was fired on and hurts the Player once on touch. A rolling Player
# (invincible) lets it fly through; walls and rocks stop it (with a splash); it
# vanishes after lifetime s. Values are set by the enemy that fires it.
# The Spit Imp pet (pet.gd) fires it too, with hits_enemies on: it flies along
# aim instead, hurts the first enemy it touches (small side damage, no push)
# and passes the Player. On that hit it leaves a small splash (a ring in
# splash_color that swells and fades over splash_time).
# The enemy's own shot splashes too (purple, the default splash_color) when it
# hits the Player, so it's clear what just hit you.
# The enemy's shot sits on the enemy_shot layer, which the Player's basic attack
# hitbox also sees: a swing that overlaps it destroys it (parry, with the
# splash). Pet shots leave that layer, so swings never touch them.
var hits_enemies: bool = false
var aim: Vector2 = Vector2.ZERO
var direction: int = 1
var speed: float = 150.0
var damage: int = 8
var lifetime: float = 2.8
var splash_color: Color = Color(0.7, 0.4, 1, 0.8)
var splash_time: float = 0.25
var splash_size: float = 3.0


func _ready() -> void:
	if hits_enemies:
		# World + enemy hurtboxes (the Player's hurtbox is left out).
		collision_mask = 3
		collision_layer = 0


func _physics_process(delta: float) -> void:
	if hits_enemies:
		position += aim * speed * delta
	else:
		position.x += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	for area in get_overlapping_areas():
		var target := area.get_parent()
		if target.get("is_dead") == true or target.get("is_invincible") == true:
			continue
		if target.is_queued_for_deletion():
			continue
		if hits_enemies:
			target.take_damage(damage, 0, 1.0, 2)
			_splash()
			queue_free()
			return
		if target.has_method("take_damage"):
			target.take_damage(damage, direction)
			_splash()
			queue_free()
			return
	# Walls and rocks (world layer) stop it, with the same splash. Enemy bodies
	# are on their own layer (enemy_body), outside both masks, so neither the
	# shooter's body nor a pet shot's target body blocks it. The root must stay
	# monitorable: a non-monitorable Area2D is treated as static by the physics
	# server and never pairs with StaticBody2D walls.
	for body in get_overlapping_bodies():
		# The Player's own body is on the world layer too; only its hurtbox counts.
		if not body.is_in_group("player"):
			_splash()
			queue_free()
			return


# Called by the Player's attack hitbox (player.gd _apply_hits).
func parry() -> void:
	_splash()
	queue_free()


# Its tween follows time_scale, so it holds still during hitstop.
func _splash() -> void:
	var ring := Polygon2D.new()
	ring.polygon = $Glow.polygon
	ring.color = splash_color
	ring.z_index = z_index
	ring.global_position = $Glow.global_position
	ring.scale = scale * 0.8
	get_parent().add_child(ring)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", scale * splash_size, splash_time) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, splash_time)
	tween.tween_callback(ring.queue_free)
