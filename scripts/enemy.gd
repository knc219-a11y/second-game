extends StaticBody2D

# Stationary test dummy: no AI or attack. Only moves when knocked back.
@export var max_hp: int = 30
# Knockback: slides knockback_distance px over knockback_duration s, then stops.
@export var knockback_distance: float = 24.0
@export var knockback_duration: float = 0.1
@export var flash_duration: float = 0.08
@export var flash_color: Color = Color(1, 1, 1, 1)

var hp: int
var knockback_dir: int = 0
var knockback_time_left: float = 0.0
var flash_time_left: float = 0.0

@onready var hp_label: Label = $HpLabel
@onready var body: Polygon2D = $Body
@onready var base_color: Color = body.color


func _ready() -> void:
	hp = max_hp
	hp_label.text = str(hp)


func _physics_process(delta: float) -> void:
	if knockback_time_left > 0.0:
		var step := minf(delta, knockback_time_left)
		knockback_time_left -= step
		# move_and_collide so walls and other bodies stop the slide.
		move_and_collide(Vector2(knockback_dir * knockback_distance / knockback_duration * step, 0.0))

	if flash_time_left > 0.0:
		flash_time_left -= delta
		if flash_time_left <= 0.0:
			body.color = base_color


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
