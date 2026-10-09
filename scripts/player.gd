extends CharacterBody2D

@export var speed: float = 220.0

# Basic melee attack timing (seconds). Total = startup + active + recovery,
# with recovery taken from combo_recovery for the current hit.
@export var attack_startup: float = 0.08
@export var attack_active: float = 0.10
# 3-hit combo on X. A press in the last combo_window s of a hit (end of ACTIVE
# + RECOVERY) is remembered and the next hit starts as soon as this one ends.
# No press in time and the combo goes back to hit 1. After hit 3 it loops.
# Holding X counts as pressing it every frame, so a held X chains the combo at
# the same pace as the fastest mashing (no extra damage or speed).
# Per-hit tables, index 0..2. combo_hitstop is the brief global freeze when
# the hit lands (real-time seconds).
@export var combo_window: float = 0.2
@export var combo_damage: Array[int] = [10, 10, 15]
@export var combo_recovery: Array[float] = [0.17, 0.17, 0.28]
# Multiplies the enemy's own knockback distance.
@export var combo_knockback_scale: Array[float] = [1.0, 1.0, 2.0]
@export var combo_hitstop: Array[float] = [0.05, 0.05, 0.08]
# Placeholder look: the arc is drawn bigger on the finisher (hitbox unchanged).
@export var combo_arc_scale: Array[float] = [1.0, 1.0, 1.3]
@export var max_hp: int = 100
# Hit reaction when an enemy lands a hit: color flash, a short freeze and a
# left/right push away from the enemy. Attacks keep running (no stagger) and a
# roll cancels the push.
@export var hurt_flash_duration: float = 0.1
@export var hurt_flash_color: Color = Color(1, 0.35, 0.35, 1)
@export var hurt_hitstop_duration: float = 0.08
@export var hurt_knockback_distance: float = 16.0
@export var hurt_knockback_duration: float = 0.12
# Heal orb pickup (enemy.heal_drop_chance): restores heal_amount HP, capped at
# max_hp, with a short green flash.
@export var heal_amount: int = 15
@export var heal_flash_color: Color = Color(0.45, 1, 0.55, 1)
@export var dead_color: Color = Color(0.3, 0.3, 0.3, 1)
# Roll (Space): short burst in the move direction (facing if idle).
# Travel = roll_speed * roll_duration (~110 px). Invincible for the first
# roll_invincible s. roll_cooldown is measured from one roll start to the next.
@export var roll_speed: float = 500.0
@export var roll_duration: float = 0.22
@export var roll_invincible: float = 0.18
@export var roll_cooldown: float = 0.6
# Weapons enemies can drop (scenes/loot.tscn), one entry per tier: tier 1 Iron
# Sword (any enemy), tier 2 Steel Sword (tough enemies only). Walking over a drop
# equips it for the rest of the run if it beats the current one: every combo hit
# deals that tier's bonus more and the swing arc takes its color. Bonuses stay
# small so one item is never a big jump (each tier shaves about one hit):
# enemy 30 HP takes 3 hits unarmed / Iron / Steel; tough 100 HP: 9 / 8 / 7.
# R restart reloads the scene, so it starts unarmed again.
@export var weapon_names: Array[String] = ["Iron Sword", "Steel Sword"]
@export var weapon_damage_bonus: Array[int] = [2, 4]
@export var weapon_arc_color: Array[Color] = [Color(0.55, 0.95, 1, 1), Color(0.8, 0.5, 1, 1)]
# Second slot: armor any enemy can rarely drop (see enemy.armor_drop_chance).
# Once worn, every enemy hit deals armor_damage_reduction less (10 -> 8), about
# as small a step as one weapon tier. One armor only for now; R resets it.
@export var armor_name: String = "Leather Armor"
@export var armor_damage_reduction: int = 2
# Third slot: a ring any enemy can rarely drop (see enemy.ring_drop_chance).
# Once worn, rolling through an enemy grazes it for ring_roll_damage (once per
# enemy per roll, no push, so it doesn't set off a normal enemy's counter).
# Small on its own; it mostly turns a dodge into a little damage. R resets it.
@export var ring_name: String = "Spark Ring"
@export var ring_roll_damage: int = 3
# Placeholder spark burst at each graze (grows and fades over graze_spark_duration),
# and a crackling halo behind the Player while rolling with the ring.
@export var graze_spark_color: Color = Color(1, 0.8, 0.25, 1)
@export var graze_spark_duration: float = 0.18
@export var graze_spark_size: float = 1.8
# Placeholder sounds, synthesized once in _ready (no audio files): a short
# noisy "thwack" when a Player hit lands (one per frame, like the hitstop; the
# finisher plays it lower and heavier) and a falling "oof" tone when hurt.
# Also a noisy whoosh on roll, a deep crunch when an enemy dies (enemy.gd calls
# it, since the enemy is freed at once) and a rising chime on any pickup
# (loot.gd calls it; the heal orb plays it higher).
# Enemy wind-ups ping a short warning (enemy.gd calls play_warn_sound as the
# telegraph starts): a rising beep for a normal swing, a sharp high chirp for
# a magenta counter, a low growl for the tough variant. One shared player, so
# several enemies winding up together restart one sound instead of stacking.
# Volumes live on the *Sound nodes in player.tscn.
@export var combo_hit_pitch: Array[float] = [1.0, 1.12, 0.8]
# Set effect, on only while any weapon AND the armor are worn: the 3rd combo hit
# also releases a shockwave ring around the Player's feet. Every enemy inside
# takes shockwave_damage and is pushed away (left/right) with
# shockwave_knockback_scale. The ring is an ellipse (y squashed by
# shockwave_y_scale) to match the top-down 2.5D floor; hit test uses the same shape.
# With the ring worn too (full set, 3 pieces) the shockwave grows to the
# full_set_* values: wider, harder and a hotter color.
@export var set_name: String = "Warrior's Set"
@export var shockwave_radius: float = 120.0
@export var shockwave_y_scale: float = 0.5
@export var shockwave_damage: int = 5
@export var shockwave_knockback_scale: float = 1.5
@export var shockwave_duration: float = 0.25
@export var shockwave_color: Color = Color(1, 0.95, 0.6, 1)
@export var full_set_radius: float = 170.0
@export var full_set_damage: int = 10
@export var full_set_color: Color = Color(1, 0.55, 0.2, 1)
# Pets, one entry per kind (pet_kind 1, 2). Each follows the Player, bites
# nearby enemies for a little damage (see pet.gd) and lends a small form of its
# monster's passive:
# 1 Brute Cub (tough enemies, rarely, test_map tough_pet_drop_chance): while the
#   Player is attacking, enemy hits don't push the Player back (damage and the
#   hit freeze still apply).
# 2 Red Pup (normal enemies, rarely, enemy.pet_drop_chance): bites back - when
#   an enemy hits the Player, the pup bites right away (its bite cooldown is
#   skipped), like the normal enemy's counter.
# The two bite differently so they read apart: the Cub chomps rarely but harder
# with a big pop, the Pup nibbles often for less (both about 2 damage a second).
# The Pup is rose, not the normal enemy's red, so it doesn't read as an enemy.
# One pet at a time: walking over a different pet swaps to it. R resets it.
@export var pet_names: Array[String] = ["Brute Cub", "Red Pup"]
@export var pet_colors: Array[Color] = [Color(0.6, 0.18, 0.28, 1), Color(1, 0.6, 0.72, 1)]
@export var pet_bite_damage: Array[int] = [5, 2]
@export var pet_bite_cooldown: Array[float] = [2.5, 0.9]
# Size the pet swells to on a bite (pet.gd bite_pop).
@export var pet_bite_pop: Array[float] = [1.6, 1.15]
@export var pet_passive_text: Array[String] = ["no push while attacking", "bites back when you're hit"]
@export var pet_scene: PackedScene = preload("res://scenes/pet.tscn")
# Screen shake on big moments: the combo finisher landing, the set shockwave
# (bigger with the full set) and the Player getting hit. The camera offset jumps
# to a random spot up to the strength (px) and fades to zero over
# shake_duration. It runs on game time, so it holds still during hitstop and
# never outlives the freeze. A stronger shake replaces a weaker one; weaker ones
# don't cut a stronger one short.
@export var shake_finisher: float = 1.5
@export var shake_shockwave: float = 2.5
@export var shake_full_set: float = 3.5
@export var shake_hurt: float = 2.0
@export var shake_duration: float = 0.15
# Q skill, Dash Slash: a quick left/right dash in the facing direction that
# cuts every enemy it passes (once each per dash) for dash_damage and pushes
# it the dash way. It passes through enemies like a roll but is NOT
# invincible, and dash_cooldown is long, so it's a gap-closer / line cutter
# that sits beside the X combo and the roll, not a replacement. Travel =
# dash_speed * dash_duration (~130 px). Weapon bonus doesn't apply.
# Reuses the hit sound, hitstop and a small shake when it lands.
@export var dash_speed: float = 650.0
@export var dash_duration: float = 0.2
@export var dash_damage: int = 12
@export var dash_cooldown: float = 5.0
@export var dash_hitstop: float = 0.06
@export var dash_hit_pitch: float = 0.9
@export var shake_dash: float = 3.0
# Cut box around the Player's body, slightly ahead in the dash direction.
@export var dash_hit_size: Vector2 = Vector2(48, 58)
@export var dash_trail_fade: float = 0.15
# A roll passes through enemy bodies (physics layer "enemy_body"); walls still
# block it. Both ways are turned off: the Player ignores enemies, and its body
# leaves "world" so chasing enemies don't get shoved ahead of the roll. If the
# roll ends inside an enemy, this lasts until the Player has walked out, so it
# never gets stuck in or shoved out of one.
const WORLD_LAYER := 1
const ENEMY_BODY_LAYER := 4

enum AttackPhase { NONE, STARTUP, ACTIVE, RECOVERY }

# 1 = right, -1 = left. Art faces right by default; left is a horizontal flip.
var facing: int = 1

var attack_phase: AttackPhase = AttackPhase.NONE
var attack_time: float = 0.0
# Enemies already hit by the current attack (one hit per enemy per attack).
var hit_targets: Array[Node] = []
# Which combo hit is running (0, 1, 2) and whether the next one is queued.
var combo_index: int = 0
var combo_queued: bool = false
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
# True from a roll start until the Player's feet are clear of every enemy body.
var passing_enemies: bool = false
# 0 = unarmed, otherwise the index+1 of the equipped weapon above.
var weapon_tier: int = 0
var has_armor: bool = false
var has_ring: bool = false
# Enemies already grazed by the current roll (Spark Ring).
var roll_hit_targets: Array[Node] = []
var shockwave_time_left: float = 0.0
var pet: Node2D = null
# 0 = no pet, otherwise the index+1 of the pet above.
var pet_kind: int = 0
var shake_strength: float = 0.0
var shake_left: float = 0.0
var dash_time_left: float = 0.0
var dash_cooldown_left: float = 0.0
var dash_dir: int = 1
# Enemies already cut by the current dash.
var dash_hit_targets: Array[Node] = []
var dash_shape := RectangleShape2D.new()

@onready var visual: Node2D = $Visual
@onready var camera: Camera2D = $Camera2D
@onready var feet: CollisionShape2D = $CollisionShape2D
# Placeholder attack visual. Its direction is locked to facing when the attack starts.
@onready var attack_pivot: Node2D = $AttackPivot
@onready var attack_arc: Polygon2D = $AttackPivot/AttackArc
# Monitoring is on only during ACTIVE.
@onready var hitbox: Area2D = $AttackPivot/Hitbox
@onready var body: Polygon2D = $Visual/Body
@onready var base_color: Color = body.color
# Test readout only, not a HUD.
@onready var hp_label: Label = $HpLabel
# Placeholder "Game Over" text, shown on death.
@onready var game_over: CanvasLayer = $GameOver
# Placeholder readout of the equipped weapon (top-left of the screen).
@onready var weapon_label: Label = $Hud/WeaponLabel
@onready var armor_label: Label = $Hud/ArmorLabel
@onready var ring_label: Label = $Hud/RingLabel
@onready var set_label: Label = $Hud/SetLabel
@onready var pet_label: Label = $Hud/PetLabel
@onready var skill_label: Label = $Hud/SkillLabel
# Placeholder streak behind the Player while dashing (fades after).
@onready var dash_trail: Polygon2D = $DashTrail
# Placeholder ring for the set shockwave, grows and fades over shockwave_duration.
@onready var shockwave_ring: Line2D = $ShockwaveRing
@onready var roll_sparks: Polygon2D = $RollSparks
@onready var hit_sound: AudioStreamPlayer = $HitSound
@onready var hurt_sound: AudioStreamPlayer = $HurtSound
@onready var roll_sound: AudioStreamPlayer = $RollSound
@onready var kill_sound: AudioStreamPlayer = $KillSound
@onready var pickup_sound: AudioStreamPlayer = $PickupSound
@onready var warn_sound: AudioStreamPlayer = $WarnSound
# Indexed by enemy.gd's warn kind: 0 normal, 1 counter, 2 tough.
var warn_streams: Array[AudioStreamWAV] = []


func _ready() -> void:
	hp = max_hp
	hp_label.text = str(hp)
	_build_shockwave_ring()
	dash_shape.size = dash_hit_size
	_update_skill_label()
	hit_sound.stream = _synth_sound(0.07, 220.0, 90.0, 0.6)
	hurt_sound.stream = _synth_sound(0.14, 330.0, 140.0, 0.15)
	roll_sound.stream = _synth_sound(0.18, 600.0, 250.0, 0.85)
	kill_sound.stream = _synth_sound(0.24, 160.0, 45.0, 0.45)
	pickup_sound.stream = _synth_sound(0.12, 660.0, 1320.0, 0.0)
	warn_streams = [
		_synth_sound(0.12, 520.0, 780.0, 0.0),
		_synth_sound(0.10, 1100.0, 1600.0, 0.1),
		_synth_sound(0.22, 140.0, 220.0, 0.3),
	]


# Mono 16-bit blip: a sine sweeping from freq_from to freq_to mixed with
# white noise (noise = 0..1 share), with a fast attack and linear fade out.
func _synth_sound(duration: float, freq_from: float, freq_to: float, noise: float) -> AudioStreamWAV:
	var rate := 22050
	var count := int(duration * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		phase += TAU * lerpf(freq_from, freq_to, t) / rate
		var env := minf(t * 40.0, 1.0) * (1.0 - t)
		var sample := (sin(phase) * (1.0 - noise) + randf_range(-1.0, 1.0) * noise) * env
		data.encode_s16(i * 2, int(sample * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav


func _build_shockwave_ring() -> void:
	var points := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		points.append(Vector2(cos(a), sin(a) * shockwave_y_scale) * _shockwave_radius())
	shockwave_ring.points = points
	shockwave_ring.default_color = full_set_color if has_full_set() else shockwave_color


func _physics_process(delta: float) -> void:
	if hurt_flash_left > 0.0:
		hurt_flash_left -= delta
		if hurt_flash_left <= 0.0:
			body.color = base_color

	if roll_cooldown_left > 0.0:
		roll_cooldown_left -= delta

	if dash_cooldown_left > 0.0:
		dash_cooldown_left -= delta
		_update_skill_label()

	if shake_left > 0.0:
		_update_shake(delta)

	if shockwave_time_left > 0.0:
		shockwave_time_left -= delta
		_update_shockwave_ring()

	if passing_enemies and roll_time_left <= 0.0 and dash_time_left <= 0.0 and not _overlaps_enemy():
		_set_passing_enemies(false)

	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)

	if dash_time_left > 0.0:
		# Dashing: no roll, attack or steering until it ends.
		_update_dash(delta)
		return

	if roll_time_left <= 0.0 and roll_cooldown_left <= 0.0 and Input.is_action_just_pressed("roll"):
		_start_roll(input)

	if roll_time_left <= 0.0 and dash_cooldown_left <= 0.0 and Input.is_action_just_pressed("skill_q"):
		_start_dash()
		_update_dash(delta)
		return

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
		if Input.is_action_pressed("attack") and _attack_total() - attack_time <= combo_window:
			combo_queued = true
		_update_attack(delta)
	elif Input.is_action_pressed("attack"):
		_start_attack(0)


func _start_roll(input: Vector2) -> void:
	# A roll cancels any attack in progress (dodge beats commitment for now).
	if attack_phase != AttackPhase.NONE:
		_cancel_attack()
	roll_dir = input.normalized() if input != Vector2.ZERO else Vector2(facing, 0)
	if roll_dir.x != 0.0:
		facing = 1 if roll_dir.x > 0.0 else -1
		visual.scale.x = facing
	roll_time_left = roll_duration
	hurt_knockback_left = 0.0
	roll_cooldown_left = roll_cooldown
	roll_hit_targets.clear()
	_set_passing_enemies(true)
	is_invincible = roll_invincible > 0.0
	# Placeholder look: squashed while rolling, see-through while invincible.
	visual.scale.y = 0.6
	visual.modulate.a = 0.45 if is_invincible else 1.0
	roll_sparks.visible = has_ring
	roll_sound.pitch_scale = 1.0
	roll_sound.play()


func _update_roll(delta: float) -> void:
	velocity = roll_dir * roll_speed
	move_and_slide()
	if has_ring:
		_roll_graze()
		# Crackle: jump the spiky halo around each frame.
		roll_sparks.rotation += 0.7
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
	roll_sparks.visible = false


func _start_dash() -> void:
	# Like the roll, the dash cancels any attack in progress.
	if attack_phase != AttackPhase.NONE:
		_cancel_attack()
	# Left/right only: always along the current facing.
	dash_dir = facing
	dash_time_left = dash_duration
	dash_cooldown_left = dash_cooldown
	hurt_knockback_left = 0.0
	dash_hit_targets.clear()
	_set_passing_enemies(true)
	# Placeholder look: stretched forward, with a streak behind.
	visual.scale = Vector2(facing * 1.3, 0.85)
	dash_trail.scale.x = dash_dir
	dash_trail.modulate.a = 1.0
	dash_trail.visible = true
	roll_sound.pitch_scale = 1.4
	roll_sound.play()
	_update_skill_label()


func _update_dash(delta: float) -> void:
	# Scaled on the last partial frame so the travel is exactly speed * duration.
	var step := minf(delta, dash_time_left)
	velocity = Vector2(dash_dir * dash_speed * (step / delta if delta > 0.0 else 0.0), 0.0)
	move_and_slide()
	_dash_hits()
	dash_time_left -= step
	if dash_time_left < 0.0001:
		dash_time_left = 0.0
	if dash_time_left <= 0.0:
		_end_dash()


func _end_dash() -> void:
	if dash_time_left <= 0.0 and not dash_trail.visible:
		return
	dash_time_left = 0.0
	visual.scale = Vector2(facing, 1.0)
	var tween := dash_trail.create_tween()
	tween.tween_property(dash_trail, "modulate:a", 0.0, dash_trail_fade)
	tween.tween_callback(dash_trail.hide)


# Every enemy hurtbox inside the cut box takes dash_damage once this dash.
func _dash_hits() -> void:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = dash_shape
	query.transform = Transform2D(0.0, global_position + Vector2(dash_dir * 16.0, -29.0))
	query.collision_mask = 2
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var landed := false
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 8):
		var target: Node = hit.collider.get_parent()
		if target in dash_hit_targets or not target.has_method("take_damage") or target.is_queued_for_deletion():
			continue
		dash_hit_targets.append(target)
		print("Dash Slash hit %s" % target.name)
		target.take_damage(dash_damage, dash_dir)
		landed = true
	# One hitstop per frame, like the combo.
	if landed:
		_start_hitstop(dash_hitstop)
		hit_sound.pitch_scale = dash_hit_pitch
		hit_sound.play()
		_shake(shake_dash)


func _update_skill_label() -> void:
	if dash_cooldown_left > 0.0:
		skill_label.text = "Q Dash Slash: %.1fs" % dash_cooldown_left
	else:
		skill_label.text = "Q Dash Slash: ready"


func _set_passing_enemies(on: bool) -> void:
	passing_enemies = on
	set_collision_mask_value(ENEMY_BODY_LAYER, not on)
	set_collision_layer_value(WORLD_LAYER, not on)


# Spark Ring: every enemy hurtbox the Player's hurtbox touches mid-roll takes
# ring_roll_damage once this roll, with no knockback.
func _roll_graze() -> void:
	var hurt_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = hurt_shape.shape
	query.transform = hurt_shape.global_transform
	query.collision_mask = 2
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 8):
		var target: Node = hit.collider.get_parent()
		if target in roll_hit_targets or not target.has_method("take_damage") or target.is_queued_for_deletion():
			continue
		roll_hit_targets.append(target)
		print("Spark Ring grazed %s" % target.name)
		# Spark between the two hurtbox centers, i.e. where they rub.
		var enemy_center: Vector2 = hit.collider.get_node("CollisionShape2D").global_position
		_spawn_graze_spark((hurt_shape.global_position + enemy_center) / 2.0)
		target.take_damage(ring_roll_damage, 0)


# One-off star burst in the world (not on the enemy, which may die from the graze).
func _spawn_graze_spark(pos: Vector2) -> void:
	var spark := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		var r := 18.0 if i % 2 == 0 else 6.0
		points.append(Vector2(cos(a), sin(a)) * r)
	spark.polygon = points
	spark.color = graze_spark_color
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([Vector2(0, -6), Vector2(4, 0), Vector2(0, 6), Vector2(-4, 0)])
	core.color = Color.WHITE
	spark.add_child(core)
	spark.global_position = pos
	spark.rotation = randf() * TAU
	spark.z_index = 10
	get_parent().add_child(spark)
	spark.scale = Vector2.ONE * 0.5
	var tween := spark.create_tween().set_parallel()
	tween.tween_property(spark, "scale", Vector2.ONE * graze_spark_size, graze_spark_duration)
	tween.tween_property(spark, "modulate:a", 0.0, graze_spark_duration).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(spark.queue_free)


func _overlaps_enemy() -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = feet.shape
	query.transform = feet.global_transform
	query.collision_mask = 1 << (ENEMY_BODY_LAYER - 1)
	return not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _start_attack(index: int) -> void:
	combo_index = index
	combo_queued = false
	attack_time = 0.0
	hit_targets.clear()
	# Each hit locks to the facing at its own start, so the Player can turn between hits.
	attack_pivot.scale.x = facing
	attack_pivot.visible = true
	attack_arc.scale = Vector2.ONE * combo_arc_scale[combo_index]
	_set_attack_phase(AttackPhase.STARTUP)


func _attack_total() -> float:
	return attack_startup + attack_active + combo_recovery[combo_index]


func _update_attack(delta: float) -> void:
	attack_time += delta
	if attack_time < attack_startup:
		_set_attack_phase(AttackPhase.STARTUP)
	elif attack_time < attack_startup + attack_active:
		# Set shockwave goes first so the finisher's own bigger knockback wins on its target.
		if attack_phase != AttackPhase.ACTIVE and combo_index == combo_damage.size() - 1 and has_set():
			_release_shockwave()
		_set_attack_phase(AttackPhase.ACTIVE)
		_apply_hits()
	elif attack_time < _attack_total():
		_set_attack_phase(AttackPhase.RECOVERY)
	elif combo_queued:
		_start_attack((combo_index + 1) % combo_damage.size())
	else:
		_cancel_attack()


# Ends the attack and resets the combo to hit 1.
func _cancel_attack() -> void:
	combo_index = 0
	combo_queued = false
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
		# is_queued_for_deletion: already killed this frame (e.g. by the set shockwave).
		if target in hit_targets or not target.has_method("take_damage") or target.is_queued_for_deletion():
			continue
		hit_targets.append(target)
		# Knock back along the facing locked at attack start, not the current facing.
		target.take_damage(_hit_damage(), int(attack_pivot.scale.x), combo_knockback_scale[combo_index])
		landed = true
	# One hitstop per frame no matter how many enemies were hit together.
	if landed:
		_start_hitstop(combo_hitstop[combo_index])
		hit_sound.pitch_scale = combo_hit_pitch[combo_index]
		hit_sound.play()
		if combo_index == combo_damage.size() - 1:
			_shake(shake_finisher)


func _hit_damage() -> int:
	var bonus := weapon_damage_bonus[weapon_tier - 1] if weapon_tier > 0 else 0
	return combo_damage[combo_index] + bonus


func has_set() -> bool:
	return weapon_tier > 0 and has_armor


func has_full_set() -> bool:
	return has_set() and has_ring


func _shockwave_radius() -> float:
	return full_set_radius if has_full_set() else shockwave_radius


func _release_shockwave() -> void:
	shockwave_time_left = shockwave_duration
	_update_shockwave_ring()
	_shake(shake_full_set if has_full_set() else shake_shockwave)
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_queued_for_deletion():
			continue
		var offset: Vector2 = enemy.global_position - global_position
		offset.y /= shockwave_y_scale
		if offset.length() > _shockwave_radius():
			continue
		var dir := facing if is_zero_approx(offset.x) else int(signf(offset.x))
		enemy.take_damage(full_set_damage if has_full_set() else shockwave_damage, dir, shockwave_knockback_scale)
		count += 1
	print("Set shockwave hit %d enemies" % count)


func _update_shockwave_ring() -> void:
	shockwave_ring.visible = shockwave_time_left > 0.0
	# 0 at release -> 1 at the end: grows from 40% to full size and fades out.
	var t := 1.0 - shockwave_time_left / shockwave_duration
	shockwave_ring.scale = Vector2.ONE * lerpf(0.4, 1.0, t)
	shockwave_ring.modulate.a = 1.0 - t


func _update_set_label() -> void:
	_build_shockwave_ring()
	if has_full_set():
		set_label.text = "Set: %s 3/3 (big 3rd hit shockwave)" % set_name
		print("Full set active: %s" % set_name)
	elif has_set():
		set_label.text = "Set: %s 2/3 (3rd hit shockwave, ring for more)" % set_name
		print("Set active: %s" % set_name)
	else:
		set_label.text = "Set: none (weapon + armor)"


func equip_weapon(tier: int) -> void:
	# A drop no better than the current weapon is just picked up and gone.
	if tier <= weapon_tier or is_dead:
		return
	weapon_tier = tier
	var i := tier - 1
	print("Picked up %s (+%d damage)" % [weapon_names[i], weapon_damage_bonus[i]])
	weapon_label.text = "Weapon: %s (+%d damage)" % [weapon_names[i], weapon_damage_bonus[i]]
	attack_arc.color = weapon_arc_color[i]
	_update_set_label()


func equip_armor() -> void:
	if has_armor or is_dead:
		return
	has_armor = true
	print("Picked up %s (-%d damage taken)" % [armor_name, armor_damage_reduction])
	armor_label.text = "Armor: %s (-%d damage taken)" % [armor_name, armor_damage_reduction]
	_update_set_label()


func equip_ring() -> void:
	if has_ring or is_dead:
		return
	has_ring = true
	print("Picked up %s (roll through enemies: %d damage)" % [ring_name, ring_roll_damage])
	ring_label.text = "Ring: %s (roll graze %d)" % [ring_name, ring_roll_damage]
	_update_set_label()


func equip_pet(kind: int) -> void:
	if kind == pet_kind or is_dead:
		return
	var new_pet := pet_scene.instantiate()
	new_pet.player = self
	new_pet.position = position + Vector2(-facing * new_pet.follow_offset.x, new_pet.follow_offset.y)
	if pet != null:
		# Swap: the old pet leaves, the new one appears where it was.
		new_pet.position = pet.position
		pet.queue_free()
	pet = new_pet
	pet_kind = kind
	# Before add_child so pet.gd's base_color picks it up.
	pet.get_node("Visual/Body").color = pet_colors[kind - 1]
	pet.bite_damage = pet_bite_damage[kind - 1]
	pet.bite_cooldown = pet_bite_cooldown[kind - 1]
	pet.bite_pop = pet_bite_pop[kind - 1]
	# Beside the Player in the scene; pet.tscn's z_index draws it on top so the
	# bite dash is not hidden behind the Player or the enemy it bites.
	get_parent().add_child(pet)
	print("Picked up pet %s" % pet_names[kind - 1])
	pet_label.text = "Pet: %s (%s, bites %d every %.1fs)" % [pet_names[kind - 1], pet_passive_text[kind - 1], pet.bite_damage, pet.bite_cooldown]


# Returns false at full HP (or dead) so the orb stays on the ground.
func heal(amount: int) -> bool:
	if is_dead or hp >= max_hp:
		return false
	hp = mini(hp + amount, max_hp)
	hp_label.text = str(hp)
	print("Healed to %d" % hp)
	body.color = heal_flash_color
	hurt_flash_left = hurt_flash_duration
	return true


# Several deaths or pickups in one frame just restart the same sound.
func play_kill_sound() -> void:
	kill_sound.play()


func play_pickup_sound(pitch: float = 1.0) -> void:
	pickup_sound.pitch_scale = pitch
	pickup_sound.play()


# kind: 0 normal, 1 counter, 2 tough (see warn_streams).
func play_warn_sound(kind: int) -> void:
	warn_sound.stream = warn_streams[kind]
	warn_sound.play()


func _shake(strength: float) -> void:
	# Keep a stronger shake that is still running.
	if shake_left > 0.0 and strength < _current_shake():
		return
	shake_strength = strength
	shake_left = shake_duration
	# Kick right away so the hitstop freeze frame already shows the jolt.
	_jolt_camera(strength)


func _current_shake() -> float:
	return shake_strength * shake_left / shake_duration


func _update_shake(delta: float) -> void:
	# Hitstop (time_scale 0) still ticks with delta 0: hold the current jolt.
	if delta <= 0.0:
		return
	shake_left -= delta
	if shake_left <= 0.0:
		_stop_shake()
	else:
		_jolt_camera(_current_shake())


func _jolt_camera(strength: float) -> void:
	camera.offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))


func _stop_shake() -> void:
	shake_left = 0.0
	camera.offset = Vector2.ZERO


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
	if has_armor:
		# Never below 1 so armor can't make a hit free.
		amount = maxi(amount - armor_damage_reduction, 1)
	hp = maxi(hp - amount, 0)
	hp_label.text = str(hp)
	print("Player HP: %d" % hp)
	hurt_sound.play()
	if hp <= 0:
		_die()
		return
	body.color = hurt_flash_color
	hurt_flash_left = hurt_flash_duration
	# Rolling or dashing already moves the Player, so the push only applies outside them.
	if direction != 0 and hurt_knockback_duration > 0.0 and roll_time_left <= 0.0 and dash_time_left <= 0.0:
		if pet_kind == 1 and attack_phase != AttackPhase.NONE:
			# Pet passive: the attack holds its ground.
			pet.flash()
			print("Pet blocked the push")
		else:
			hurt_knockback_dir = direction
			hurt_knockback_left = hurt_knockback_duration
	if pet_kind == 2:
		pet.bite_now()
	_shake(shake_hurt)
	_start_hitstop(hurt_hitstop_duration)


func _die() -> void:
	is_dead = true
	print("Player died")
	# Minimal death: stop input/movement, cancel any attack, stop taking hits.
	set_physics_process(false)
	velocity = Vector2.ZERO
	_cancel_attack()
	_end_roll()
	_end_dash()
	hurt_knockback_left = 0.0
	shockwave_time_left = 0.0
	shockwave_ring.visible = false
	_stop_shake()
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
