extends Node2D

# Placeholder pet: a small copy of the tough enemy that trails behind the Player
# (on the side away from facing). It doesn't fight; the passive lives in
# player.gd take_damage. Flashes when the passive blocks a push.
@export var follow_offset: Vector2 = Vector2(36, -6)
# Higher = catches up faster (exponential smoothing per second).
@export var follow_speed: float = 6.0
@export var flash_duration: float = 0.15
@export var flash_color: Color = Color(1, 0.95, 0.6, 1)

var player: Node2D
var flash_left: float = 0.0

@onready var visual: Node2D = $Visual
@onready var body: Polygon2D = $Visual/Body
@onready var base_color: Color = body.color


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var target := player.position + Vector2(-player.facing * follow_offset.x, follow_offset.y)
	position = position.lerp(target, 1.0 - exp(-follow_speed * delta))
	visual.scale.x = player.facing
	if flash_left > 0.0:
		flash_left -= delta
		if flash_left <= 0.0:
			body.color = base_color


func flash() -> void:
	body.color = flash_color
	flash_left = flash_duration
