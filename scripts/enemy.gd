extends CharacterBody2D

# Test enemy: chases the Player in a straight line (no pathfinding) and stops nearby.
@export var max_hp: int = 30
@export var move_speed: float = 90.0
# Starts chasing when the Player comes within detect_range px.
@export var detect_range: float = 300.0
# Gives up once the Player is farther than lose_range px (> detect_range so it doesn't flicker at the edge).
@export var lose_range: float = 400.0
# Stops approaching at this distance (px) from the Player.
@export var stop_distance: float = 50.0
# Knockback: slides knockback_distance px over knockback_duration s, then stops.
@export var knockback_distance: float = 24.0
@export var knockback_duration: float = 0.1
@export var flash_duration: float = 0.08
@export var flash_color: Color = Color(1, 1, 1, 1)

var hp: int
var knockback_dir: int = 0
var knockback_time_left: float = 0.0
var flash_time_left: float = 0.0
var is_chasing: bool = false
var player: Node2D

@onready var hp_label: Label = $HpLabel
@onready var body: Polygon2D = $Body
@onready var base_color: Color = body.color


func _ready() -> void:
	hp = max_hp
	hp_label.text = str(hp)
	player = get_tree().get_first_node_in_group("player") as Node2D


func _physics_process(delta: float) -> void:
	# Knockback takes priority: no chase movement until it ends.
	if knockback_time_left > 0.0:
		var step := minf(delta, knockback_time_left)
		knockback_time_left -= step
		# move_and_collide so walls and other bodies stop the slide.
		move_and_collide(Vector2(knockback_dir * knockback_distance / knockback_duration * step, 0.0))
	else:
		_chase(delta)

	if flash_time_left > 0.0:
		flash_time_left -= delta
		if flash_time_left <= 0.0:
			body.color = base_color


func _chase(delta: float) -> void:
	velocity = Vector2.ZERO
	if not is_instance_valid(player):
		is_chasing = false
		return

	var to_player := player.global_position - global_position
	var dist := to_player.length()
	if not is_chasing and dist <= detect_range:
		is_chasing = true
	elif is_chasing and dist > lose_range:
		is_chasing = false

	if is_chasing and dist > stop_distance and delta > 0.0:
		# normalized() keeps diagonal speed equal to straight speed.
		# Capped so the last step lands on stop_distance instead of overshooting.
		var speed := minf(move_speed, (dist - stop_distance) / delta)
		velocity = to_player.normalized() * speed
		move_and_slide()


# direction: 1 = right, -1 = left, 0 = no knockback.
func take_damage(amount: int, direction: int = 0) -> void:
	hp -= amount
	hp_label.text = str(hp)
	print("%s HP: %d" % [name, hp])
	if hp <= 0:
		queue_free()
		return

	body.color = flash_color
	flash_time_left = flash_duration

	if direction != 0 and knockback_duration > 0.0:
		knockback_dir = direction
		knockback_time_left = knockback_duration
