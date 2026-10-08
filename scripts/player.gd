extends CharacterBody2D

@export var speed: float = 220.0

# Basic melee attack timing (seconds). Total = startup + active + recovery.
@export var attack_startup: float = 0.08
@export var attack_active: float = 0.10
@export var attack_recovery: float = 0.17
@export var attack_damage: int = 10
# Brief global freeze when an attack lands (real-time seconds).
@export var hitstop_duration: float = 0.05
@export var max_hp: int = 100
# Hit reaction when an enemy lands a hit: color flash, a short freeze and a
# left/right push away from the enemy. Attacks keep running (no stagger) and a
# roll cancels the push.
@export var hurt_flash_duration: float = 0.1
@export var hurt_flash_color: Color = Color(1, 0.35, 0.35, 1)
@export var hurt_hitstop_duration: float = 0.08
@export var hurt_knockback_distance: float = 16.0
@export var hurt_knockback_duration: float = 0.12
@export var dead_color: Color = Color(0.3, 0.3, 0.3, 1)
# Roll (Space): short burst in the move direction (facing if idle).
# Travel = roll_speed * roll_duration (~110 px). Invincible for the first
# roll_invincible s. roll_cooldown is measured from one roll start to the next.
@export var roll_speed: float = 500.0
@export var roll_duration: float = 0.22
@export var roll_invincible: float = 0.18
@export var roll_cooldown: float = 0.6

enum AttackPhase { NONE, STARTUP, ACTIVE, RECOVERY }

# 1 = right, -1 = left. Art faces right by default; left is a horizontal flip.
var facing: int = 1

var attack_phase: AttackPhase = AttackPhase.NONE
var attack_time: float = 0.0
# Enemies already hit by the current attack (one hit per enemy per attack).
var hit_targets: Array[Node] = []
var in_hitstop: bool = false
var hp: int
var is_dead: bool = false
var hurt_flash_left: float = 0.0
var roll_time_left: float = 0.0
var roll_dir: Vector2 = Vector2.ZERO
var roll_cooldown_left: float = 0.0
var is_invincible: bool = false
var hurt_knockback_dir: int = 0
var hurt_knockback_left: float = 0.0

@onready var visual: Node2D = $Visual
# Placeholder attack visual. Its direction is locked to facing when the attack starts.
@onready var attack_pivot: Node2D = $AttackPivot
# Monitoring is on only during ACTIVE.
@onready var hitbox: Area2D = $AttackPivot/Hitbox
@onready var body: Polygon2D = $Visual/Body
@onready var base_color: Color = body.color
# Test readout only, not a HUD.
@onready var hp_label: Label = $HpLabel
# Placeholder "Game Over" text, shown on death.
@onready var game_over: CanvasLayer = $GameOver


func _ready() -> void:
	hp = max_hp
	hp_label.text = str(hp)


func _physics_process(delta: float) -> void:
	if hurt_flash_left > 0.0:
		hurt_flash_left -= delta
		if hurt_flash_left <= 0.0:
			body.color = base_color

	if roll_cooldown_left > 0.0:
		roll_cooldown_left -= delta

	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)

	if roll_time_left <= 0.0 and roll_cooldown_left <= 0.0 and Input.is_action_just_pressed("roll"):
		_start_roll(input)

	if roll_time_left > 0.0:
		# Rolling: direction is fixed, no attacking until it ends.
		_update_roll(delta)
		return

	if hurt_knockback_left > 0.0:
		# Pushed back: the push replaces movement input until it ends.
		var step := minf(delta, hurt_knockback_left)
		hurt_knockback_left -= step
		# Scaled on the last partial frame so the total push is exactly the distance.
		var push_speed := hurt_knockback_distance / hurt_knockback_duration
		velocity = Vector2(hurt_knockback_dir * push_speed * (step / delta if delta > 0.0 else 0.0), 0.0)
	else:
		# Normalize so diagonal movement is not faster than straight movement.
		velocity = input.normalized() * speed
	move_and_slide()

	# Only horizontal input changes facing; W/S alone keeps the last facing.
	if input.x != 0.0:
		facing = 1 if input.x > 0.0 else -1
		visual.scale.x = facing

	if attack_phase != AttackPhase.NONE:
		_update_attack(delta)
	# No combo or input buffer: a press during an attack is ignored.
	elif Input.is_action_just_pressed("attack"):
		_start_attack()


func _start_roll(input: Vector2) -> void:
	# A roll cancels any attack in progress (dodge beats commitment for now).
	if attack_phase != AttackPhase.NONE:
		attack_pivot.visible = false
		_set_attack_phase(AttackPhase.NONE)
	roll_dir = input.normalized() if input != Vector2.ZERO else Vector2(facing, 0)
	if roll_dir.x != 0.0:
		facing = 1 if roll_dir.x > 0.0 else -1
		visual.scale.x = facing
	roll_time_left = roll_duration
	hurt_knockback_left = 0.0
	roll_cooldown_left = roll_cooldown
	is_invincible = roll_invincible > 0.0
	# Placeholder look: squashed while rolling, see-through while invincible.
	visual.scale.y = 0.6
	visual.modulate.a = 0.45 if is_invincible else 1.0


func _update_roll(delta: float) -> void:
	velocity = roll_dir * roll_speed
	move_and_slide()
	roll_time_left -= delta
	if is_invincible and roll_duration - roll_time_left >= roll_invincible:
		is_invincible = false
		visual.modulate.a = 1.0
	if roll_time_left <= 0.0:
		_end_roll()


func _end_roll() -> void:
	roll_time_left = 0.0
	is_invincible = false
	visual.scale.y = 1.0
	visual.modulate.a = 1.0


func _start_attack() -> void:
	attack_time = 0.0
	hit_targets.clear()
	attack_pivot.scale.x = facing
	attack_pivot.visible = true
	_set_attack_phase(AttackPhase.STARTUP)


func _update_attack(delta: float) -> void:
	attack_time += delta
	if attack_time < attack_startup:
		_set_attack_phase(AttackPhase.STARTUP)
	elif attack_time < attack_startup + attack_active:
		_set_attack_phase(AttackPhase.ACTIVE)
		_apply_hits()
	elif attack_time < attack_startup + attack_active + attack_recovery:
		_set_attack_phase(AttackPhase.RECOVERY)
	else:
		attack_pivot.visible = false
		_set_attack_phase(AttackPhase.NONE)


func _set_attack_phase(phase: AttackPhase) -> void:
	attack_phase = phase
	hitbox.monitoring = phase == AttackPhase.ACTIVE
	# Placeholder look per phase: faint (startup), solid (active), dim (recovery).
	match phase:
		AttackPhase.STARTUP:
			attack_pivot.modulate = Color(1, 1, 1, 0.3)
		AttackPhase.ACTIVE:
			attack_pivot.modulate = Color(1, 1, 1, 1)
		AttackPhase.RECOVERY:
			attack_pivot.modulate = Color(0.6, 0.6, 0.6, 0.45)


func _apply_hits() -> void:
	var landed := false
	for area in hitbox.get_overlapping_areas():
		var target := area.get_parent()
		if target in hit_targets or not target.has_method("take_damage"):
			continue
		hit_targets.append(target)
		# Knock back along the facing locked at attack start, not the current facing.
		target.take_damage(attack_damage, int(attack_pivot.scale.x))
		landed = true
	# One hitstop per frame no matter how many enemies were hit together.
	if landed:
		_start_hitstop(hitstop_duration)


func _start_hitstop(duration: float) -> void:
	# A hitstop already running is not extended or stacked.
	if in_hitstop or duration <= 0.0:
		return
	in_hitstop = true
	Engine.time_scale = 0.0
	# ignore_time_scale = true so the timer itself still runs while time is frozen.
	get_tree().create_timer(duration, true, false, true).timeout.connect(_end_hitstop)


func _end_hitstop() -> void:
	in_hitstop = false
	Engine.time_scale = 1.0


# direction: 1 = push right, -1 = push left, 0 = no knockback.
func take_damage(amount: int, direction: int = 0) -> void:
	# Roll i-frames: the hit is dodged (the enemy's swing still counts as spent).
	if is_dead or is_invincible:
		return
	hp = maxi(hp - amount, 0)
	hp_label.text = str(hp)
	print("Player HP: %d" % hp)
	if hp <= 0:
		_die()
		return
	body.color = hurt_flash_color
	hurt_flash_left = hurt_flash_duration
	# Rolling already moves the Player, so the push only applies outside a roll.
	if direction != 0 and hurt_knockback_duration > 0.0 and roll_time_left <= 0.0:
		hurt_knockback_dir = direction
		hurt_knockback_left = hurt_knockback_duration
	_start_hitstop(hurt_hitstop_duration)


func _die() -> void:
	is_dead = true
	print("Player died")
	# Minimal death: stop input/movement, cancel any attack, stop taking hits.
	set_physics_process(false)
	velocity = Vector2.ZERO
	attack_pivot.visible = false
	_set_attack_phase(AttackPhase.NONE)
	_end_roll()
	hurt_knockback_left = 0.0
	$Hurtbox.set_deferred("monitorable", false)
	hurt_flash_left = 0.0
	body.color = dead_color
	game_over.visible = true


func _process(_delta: float) -> void:
	# _physics_process is off after death, so the restart key is read here.
	if is_dead and Input.is_action_just_pressed("restart"):
		_restart()


func _restart() -> void:
	# Unfreeze first in case death happened during hitstop.
	if in_hitstop:
		_end_hitstop()
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func _exit_tree() -> void:
	# Never leave the game frozen if the player is removed mid-hitstop.
	if in_hitstop:
		_end_hitstop()
