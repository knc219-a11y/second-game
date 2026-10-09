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
# Set effect, on only while any weapon AND the armor are worn: the 3rd combo hit
# also releases a shockwave ring around the Player's feet. Every enemy inside
# takes shockwave_damage and is pushed away (left/right) with
# shockwave_knockback_scale. The ring is an ellipse (y squashed by
# shockwave_y_scale) to match the top-down 2.5D floor; hit test uses the same shape.
@export var set_name: String = "Warrior's Set"
@export var shockwave_radius: float = 120.0
@export var shockwave_y_scale: float = 0.5
@export var shockwave_damage: int = 5
@export var shockwave_knockback_scale: float = 1.5
@export var shockwave_duration: float = 0.25
@export var shockwave_color: Color = Color(1, 0.95, 0.6, 1)
# Pet: tough enemies rarely drop one (see test_map tough_pet_drop_chance). It
# follows the Player and lends the tough enemy's passive in a small form: while
# the Player is attacking, enemy hits don't push the Player back (damage and the
# hit freeze still apply). It also bites nearby enemies for a little damage
# (see pet.gd). One pet only; R resets it.
@export var pet_name: String = "Brute Cub"
@export var pet_scene: PackedScene = preload("res://scenes/pet.tscn")
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
var shockwave_time_left: float = 0.0
var pet: Node2D = null

@onready var visual: Node2D = $Visual
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
@onready var set_label: Label = $Hud/SetLabel
@onready var pet_label: Label = $Hud/PetLabel
# Placeholder ring for the set shockwave, grows and fades over shockwave_duration.
@onready var shockwave_ring: Line2D = $ShockwaveRing


func _ready() -> void:
	hp = max_hp
	hp_label.text = str(hp)
	var points := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		points.append(Vector2(cos(a), sin(a) * shockwave_y_scale) * shockwave_radius)
	shockwave_ring.points = points
	shockwave_ring.default_color = shockwave_color


func _physics_process(delta: float) -> void:
	if hurt_flash_left > 0.0:
		hurt_flash_left -= delta
		if hurt_flash_left <= 0.0:
			body.color = base_color

	if roll_cooldown_left > 0.0:
		roll_cooldown_left -= delta

	if shockwave_time_left > 0.0:
		shockwave_time_left -= delta
		_update_shockwave_ring()

	if passing_enemies and roll_time_left <= 0.0 and not _overlaps_enemy():
		_set_passing_enemies(false)

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
	_set_passing_enemies(true)
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


func _set_passing_enemies(on: bool) -> void:
	passing_enemies = on
	set_collision_mask_value(ENEMY_BODY_LAYER, not on)
	set_collision_layer_value(WORLD_LAYER, not on)


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


func _hit_damage() -> int:
	var bonus := weapon_damage_bonus[weapon_tier - 1] if weapon_tier > 0 else 0
	return combo_damage[combo_index] + bonus


func has_set() -> bool:
	return weapon_tier > 0 and has_armor


func _release_shockwave() -> void:
	shockwave_time_left = shockwave_duration
	_update_shockwave_ring()
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_queued_for_deletion():
			continue
		var offset: Vector2 = enemy.global_position - global_position
		offset.y /= shockwave_y_scale
		if offset.length() > shockwave_radius:
			continue
		var dir := facing if is_zero_approx(offset.x) else int(signf(offset.x))
		enemy.take_damage(shockwave_damage, dir, shockwave_knockback_scale)
		count += 1
	print("Set shockwave hit %d enemies" % count)


func _update_shockwave_ring() -> void:
	shockwave_ring.visible = shockwave_time_left > 0.0
	# 0 at release -> 1 at the end: grows from 40% to full size and fades out.
	var t := 1.0 - shockwave_time_left / shockwave_duration
	shockwave_ring.scale = Vector2.ONE * lerpf(0.4, 1.0, t)
	shockwave_ring.modulate.a = 1.0 - t


func _update_set_label() -> void:
	if has_set():
		set_label.text = "Set: %s (3rd hit shockwave)" % set_name
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


func equip_pet() -> void:
	if pet != null or is_dead:
		return
	pet = pet_scene.instantiate()
	pet.player = self
	pet.position = position + Vector2(-facing * pet.follow_offset.x, pet.follow_offset.y)
	# Beside the Player in the scene; pet.tscn's z_index draws it on top so the
	# bite dash is not hidden behind the Player or the enemy it bites.
	get_parent().add_child(pet)
	print("Picked up pet %s" % pet_name)
	pet_label.text = "Pet: %s (no push while attacking, bites %d)" % [pet_name, pet.bite_damage]


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
	if hp <= 0:
		_die()
		return
	body.color = hurt_flash_color
	hurt_flash_left = hurt_flash_duration
	# Rolling already moves the Player, so the push only applies outside a roll.
	if direction != 0 and hurt_knockback_duration > 0.0 and roll_time_left <= 0.0:
		if pet != null and attack_phase != AttackPhase.NONE:
			# Pet passive: the attack holds its ground.
			pet.flash()
			print("Pet blocked the push")
		else:
			hurt_knockback_dir = direction
			hurt_knockback_left = hurt_knockback_duration
	_start_hitstop(hurt_hitstop_duration)


func _die() -> void:
	is_dead = true
	print("Player died")
	# Minimal death: stop input/movement, cancel any attack, stop taking hits.
	set_physics_process(false)
	velocity = Vector2.ZERO
	_cancel_attack()
	_end_roll()
	hurt_knockback_left = 0.0
	shockwave_time_left = 0.0
	shockwave_ring.visible = false
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
