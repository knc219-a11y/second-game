extends CharacterBody2D

@export var speed: float = 220.0

# Basic melee attack timing (seconds). Total = startup + active + recovery.
@export var attack_startup: float = 0.08
@export var attack_active: float = 0.10
@export var attack_recovery: float = 0.17
@export var attack_damage: int = 10
# Brief global freeze when an attack lands (real-time seconds).
@export var hitstop_duration: float = 0.05

enum AttackPhase { NONE, STARTUP, ACTIVE, RECOVERY }

# 1 = right, -1 = left. Art faces right by default; left is a horizontal flip.
var facing: int = 1

var attack_phase: AttackPhase = AttackPhase.NONE
var attack_time: float = 0.0
# Enemies already hit by the current attack (one hit per enemy per attack).
var hit_targets: Array[Node] = []
var in_hitstop: bool = false

@onready var visual: Node2D = $Visual
# Placeholder attack visual. Its direction is locked to facing when the attack starts.
@onready var attack_pivot: Node2D = $AttackPivot
# Monitoring is on only during ACTIVE.
@onready var hitbox: Area2D = $AttackPivot/Hitbox


func _physics_process(delta: float) -> void:
	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
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
		_start_hitstop()


func _start_hitstop() -> void:
	# A hitstop already running is not extended or stacked.
	if in_hitstop or hitstop_duration <= 0.0:
		return
	in_hitstop = true
	Engine.time_scale = 0.0
	# ignore_time_scale = true so the timer itself still runs while time is frozen.
	get_tree().create_timer(hitstop_duration, true, false, true).timeout.connect(_end_hitstop)


func _end_hitstop() -> void:
	in_hitstop = false
	Engine.time_scale = 1.0


func _exit_tree() -> void:
	# Never leave the game frozen if the player is removed mid-hitstop.
	if in_hitstop:
		_end_hitstop()
