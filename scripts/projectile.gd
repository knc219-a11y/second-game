extends Area2D

# Ranged enemy's shot (enemy.gd is_ranged): flies straight left/right along the
# line it was fired on and hurts the Player once on touch. A rolling Player
# (invincible) lets it fly through; walls and rocks stop it; it vanishes after
# lifetime s. Values are set by the enemy that fires it.
var direction: int = 1
var speed: float = 150.0
var damage: int = 8
var lifetime: float = 2.8


func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	for area in get_overlapping_areas():
		var target := area.get_parent()
		if target.get("is_dead") == true or target.get("is_invincible") == true:
			continue
		if target.has_method("take_damage"):
			target.take_damage(damage, direction)
			queue_free()
			return
	for body in get_overlapping_bodies():
		# The Player's own body is on the world layer too; only its hurtbox counts.
		if not body.is_in_group("player"):
			queue_free()
			return
