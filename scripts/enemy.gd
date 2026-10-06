extends CharacterBody2D

# Test enemy: chases the Player in a straight line (no pathfinding) and stops
# beside it on the same Y line, where the Player's left/right attack can reach.
@export var max_hp: int = 30
@export var move_speed: float = 90.0
# Starts chasing when the Player comes within detect_range px.
@export var detect_range: float = 300.0
# Gives up once the Player is farther than lose_range px (> detect_range so it doesn't flicker at the edge).
@export var lose_range: float = 400.0
# Horizontal distance (px) kept from the Player once on the same combat line.
@export var stop_distance: float = 50.0
# Max Y difference (px) that still counts as the Player's combat line.
# The Player only attacks left/right, so the enemy must be within this to stop.
@export var vertical_tolerance: float = 24.0
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
# Which side of the Player to stand on: 1 = right, -1 = left.
var side: int = 1
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

	if not is_chasing or delta <= 0.0:
		return

	# Stay on the side we're already on; directly above/below keeps the last side.
	var dx := global_position.x - player.global_position.x
	if dx != 0.0:
		side = 1 if dx > 0.0 else -1
	# Stopped only when on the Player's Y line and at a left/right attack distance.
	# Lower bound (half of stop_distance) keeps it from parking right above/below the Player.
	var on_line := absf(to_player.y) <= vertical_tolerance
	var at_side := absf(dx) <= stop_distance and absf(dx) >= stop_distance * 0.5
	if on_line and at_side:
		return

	# Head for the combat spot beside the Player instead of the Player itself.
	var to_spot := player.global_position + Vector2(side * stop_distance, 0.0) - global_position
	# Capped so the last step lands on the spot instead of overshooting (no jitter).
	var speed := minf(move_speed, to_spot.length() / delta)
	velocity = to_spot.normalized() * speed
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
