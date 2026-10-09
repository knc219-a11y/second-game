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
# Crowding: if a closer enemy already holds this side's spot, take the other side
# when it's free; if both are held, wait queue_spacing px behind the one ahead.
@export var queue_spacing: float = 40.0
# While switching to the far side, pass the Player this many px above/below
# instead of walking straight into it.
@export var cross_offset: float = 48.0
# Knockback: slides knockback_distance px over knockback_duration s, then stops.
@export var knockback_distance: float = 24.0
@export var knockback_duration: float = 0.1
@export var flash_duration: float = 0.08
@export var flash_color: Color = Color(1, 1, 1, 1)
# Melee attack: starts when standing at the combat spot beside the Player.
# attack_cooldown is measured from one attack start to the next.
@export var attack_damage: int = 10
# Max horizontal distance (px) to start an attack, a bit over stop_distance so an
# enemy jammed just outside its spot (e.g. by another enemy) can still swing.
# Keep it under the Hitbox reach (~68 px) so a swing started in range can land.
@export var attack_range: float = 60.0
@export var attack_cooldown: float = 1.0
@export var attack_startup: float = 0.38
@export var attack_active: float = 0.1
@export var attack_recovery: float = 0.2
# Telegraph during STARTUP: body turns this color and the danger zone (the real
# Hitbox area) is shown, so the Player can read the swing and step out.
@export var telegraph_color: Color = Color(1, 0.8, 0.2, 1)
# On death, chance (0..1) to drop the Player's weapon of drop_tier (see
# player.gd weapon_names) where it fell. No drop once the Player has that tier
# or better. The tough variant drops tier 2.
@export var drop_chance: float = 0.35
@export var drop_tier: int = 1
# Separate, rarer roll for the Player's armor (any enemy, tough included).
# No drop once the Player wears it.
@export var armor_drop_chance: float = 0.12
# Separate, rarer roll for the Player's ring (any enemy). No drop once worn.
@export var ring_drop_chance: float = 0.1
# Separate, rare roll for a pet of kind pet_drop_kind (player.gd pet_names):
# normal enemies drop the Red Pup (2); test_map.gd gives the tough variant the
# Brute Cub (1) and its own chance. No drop while the Player has that same pet.
@export var pet_drop_chance: float = 0.04
@export var pet_drop_kind: int = 2
# Separate roll for a heal orb (player.gd heal_amount), only while the Player
# is hurt.
@export var heal_drop_chance: float = 0.15
@export var loot_scene: PackedScene = preload("res://scenes/loot.tscn")
# Hits during its own attack neither push it nor cancel the swing (the tough
# variant), so the Player can't just mash through its wind-up and must dodge.
@export var super_armor: bool = false
# Normal enemies bite back: once a hit knocks one back, its next swing starts as
# soon as it is in range again (no cooldown wait) and can't be interrupted, so
# mashing X costs a hit unless the Player steps or rolls out of the wind-up.
# The wind-up shows counter_color (magenta, apart from the red body and the
# yellow normal wind-up) instead of telegraph_color. Not used with
# super_armor (the tough variant keeps its own rule).
@export var counter_color: Color = Color(1, 0.3, 0.9, 1)
# Kept gentle for now: a counter winds up longer than a normal swing (easier to
# read and dodge) and hits for less.
@export var counter_startup: float = 0.45
@export var counter_damage: int = 5

enum AttackPhase { NONE, STARTUP, ACTIVE, RECOVERY }

var hp: int
var knockback_dir: int = 0
var knockback_time_left: float = 0.0
var knockback_push: float = 0.0
var flash_time_left: float = 0.0
var is_chasing: bool = false
# Which side of the Player to stand on: 1 = right, -1 = left.
var side: int = 1
# True while walking round the Player to the free far side (see _chase).
var is_crossing: bool = false
var player: Node2D
var attack_phase: AttackPhase = AttackPhase.NONE
var attack_time: float = 0.0
var cooldown_left: float = 0.0
# True once the current attack has damaged the Player (one hit per attack).
var attack_landed: bool = false
# Set by a knockback; the next swing is a counter (see counter_color).
var counter_ready: bool = false
var is_counter: bool = false

@onready var hp_label: Label = $HpLabel
# Placeholder attack visual; scale.x is locked toward the Player at attack start.
@onready var attack_pivot: Node2D = $AttackPivot
# Monitoring is on only during ACTIVE.
@onready var hitbox: Area2D = $AttackPivot/Hitbox
@onready var attack_arc: Polygon2D = $AttackPivot/AttackArc
# Placeholder danger zone matching the Hitbox; visible only during STARTUP.
@onready var warn_zone: Polygon2D = $AttackPivot/WarnZone
@onready var body: Polygon2D = $Body
@onready var base_color: Color = body.color


func _ready() -> void:
	hp = max_hp
	hp_label.text = str(hp)
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player") as Node2D


func _physics_process(delta: float) -> void:
	if cooldown_left > 0.0:
		cooldown_left -= delta

	# Priority: knockback > attack > chase.
	if knockback_time_left > 0.0:
		var step := minf(delta, knockback_time_left)
		knockback_time_left -= step
		# move_and_collide so walls and other bodies stop the slide.
		move_and_collide(Vector2(knockback_dir * knockback_push / knockback_duration * step, 0.0))
	elif attack_phase != AttackPhase.NONE:
		# Stands still for the whole attack so it never slides mid-swing.
		velocity = Vector2.ZERO
		_update_attack(delta)
	else:
		_chase(delta)

	if flash_time_left > 0.0:
		flash_time_left -= delta
		if flash_time_left <= 0.0:
			body.color = _body_color()


func _chase(delta: float) -> void:
	velocity = Vector2.ZERO
	if not is_instance_valid(player) or _player_is_dead():
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

	# Default to the side we're already on; directly above/below keeps the last side.
	var dx := global_position.x - player.global_position.x
	var near_side := side
	if dx != 0.0:
		near_side = 1 if dx > 0.0 else -1
	# Crossing is over once level with the far spot (it then steps onto the line).
	if is_crossing and dx * side >= stop_distance - 1.0:
		is_crossing = false
	# Keep going round to the far side until there, unless someone else took it.
	if is_crossing and _count_ahead(side, INF) == 0:
		pass
	# Near side's spot held by a closer enemy and the far side empty: go there.
	elif _count_ahead(near_side) > 0 and _count_ahead(-near_side, INF) == 0:
		side = -near_side
		is_crossing = true
	else:
		side = near_side
		is_crossing = false
	# Stopped only when on the Player's Y line and at a left/right attack distance.
	# Lower bound (half of stop_distance) keeps it from parking right above/below the Player.
	var on_line := absf(to_player.y) <= vertical_tolerance
	var in_attack_range := not is_crossing and on_line and absf(dx) <= attack_range and absf(dx) >= stop_distance * 0.5
	if in_attack_range and (cooldown_left <= 0.0 or counter_ready):
		_start_attack()
		return
	var at_side := absf(dx) <= stop_distance and absf(dx) >= stop_distance * 0.5
	if on_line and at_side:
		return

	# Head for the combat spot beside the Player instead of the Player itself,
	# one queue_spacing further out per enemy already ahead on this side.
	var spot := Vector2(side * (stop_distance + _count_ahead(side) * queue_spacing), 0.0)
	if is_crossing:
		# Go round past the Player's top/bottom, not through it or the enemy in front.
		spot.y = cross_offset if to_player.y <= 0.0 else -cross_offset
	var to_spot := player.global_position + spot - global_position
	# Capped so the last step lands on the spot instead of overshooting (no jitter).
	var speed := minf(move_speed, to_spot.length() / delta)
	velocity = to_spot.normalized() * speed
	move_and_slide()


# Other chasing enemies on side s (by their chosen side) closer to the Player
# than this one, or than max_dist when given.
func _count_ahead(s: int, max_dist: float = -1.0) -> int:
	var my_dist := global_position.distance_to(player.global_position) if max_dist < 0.0 else max_dist
	var count := 0
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not other.is_chasing or other.side != s:
			continue
		if other.global_position.distance_to(player.global_position) < my_dist:
			count += 1
	return count


func _player_is_dead() -> bool:
	return player.get("is_dead") == true


func _start_attack() -> void:
	attack_time = 0.0
	attack_landed = false
	is_counter = counter_ready
	counter_ready = false
	cooldown_left = attack_cooldown
	# Left/right only: swing toward the side the Player is on.
	attack_pivot.scale.x = 1 if player.global_position.x >= global_position.x else -1
	attack_pivot.visible = true
	_set_attack_phase(AttackPhase.STARTUP)
	# Audible cue with the telegraph (see player.play_warn_sound).
	if player.has_method("play_warn_sound"):
		player.play_warn_sound(2 if super_armor else (1 if is_counter else 0))


func _update_attack(delta: float) -> void:
	attack_time += delta
	var startup := counter_startup if is_counter else attack_startup
	if attack_time < startup:
		_set_attack_phase(AttackPhase.STARTUP)
	elif attack_time < startup + attack_active:
		_set_attack_phase(AttackPhase.ACTIVE)
		_apply_hit()
	elif attack_time < startup + attack_active + attack_recovery:
		_set_attack_phase(AttackPhase.RECOVERY)
	else:
		_end_attack()


func _end_attack() -> void:
	is_counter = false
	attack_pivot.visible = false
	_set_attack_phase(AttackPhase.NONE)


func _set_attack_phase(phase: AttackPhase) -> void:
	attack_phase = phase
	hitbox.monitoring = phase == AttackPhase.ACTIVE
	# Wind-up shows only the danger zone; the swing arc appears from ACTIVE on.
	warn_zone.visible = phase == AttackPhase.STARTUP
	attack_arc.visible = phase != AttackPhase.STARTUP
	# Don't overwrite a hit flash still in progress; it restores the color when done.
	if flash_time_left <= 0.0:
		body.color = _body_color()
	match phase:
		AttackPhase.STARTUP:
			attack_pivot.modulate = Color(1, 1, 1, 1)
		AttackPhase.ACTIVE:
			attack_pivot.modulate = Color(1, 1, 1, 1)
		AttackPhase.RECOVERY:
			attack_pivot.modulate = Color(0.6, 0.6, 0.6, 0.45)


func _body_color() -> Color:
	if attack_phase != AttackPhase.STARTUP:
		return base_color
	return counter_color if is_counter else telegraph_color


func _apply_hit() -> void:
	if attack_landed:
		return
	for area in hitbox.get_overlapping_areas():
		var target := area.get_parent()
		if target.has_method("take_damage"):
			# Push the Player the way the swing faces (left/right only).
			target.take_damage(counter_damage if is_counter else attack_damage, int(attack_pivot.scale.x))
			attack_landed = true
			return


# direction: 1 = right, -1 = left, 0 = no knockback.
# knockback_scale: multiplies knockback_distance (the Player's combo finisher pushes further).
func take_damage(amount: int, direction: int = 0, knockback_scale: float = 1.0) -> void:
	hp -= amount
	hp_label.text = str(hp)
	print("%s HP: %d" % [name, hp])
	if hp <= 0:
		_try_drop_loot()
		_try_drop_armor()
		_try_drop_ring()
		_try_drop_pet()
		_try_drop_heal()
		if is_instance_valid(player):
			player.play_kill_sound()
		queue_free()
		return

	body.color = flash_color
	flash_time_left = flash_duration

	if (super_armor or is_counter) and attack_phase != AttackPhase.NONE:
		return
	if direction != 0 and knockback_duration > 0.0:
		# Knockback interrupts the attack; the cooldown keeps running.
		if attack_phase != AttackPhase.NONE:
			_end_attack()
		knockback_dir = direction
		knockback_time_left = knockback_duration
		knockback_push = knockback_distance * knockback_scale
		if not super_armor:
			counter_ready = true


func _try_drop_loot() -> void:
	if not is_instance_valid(player) or player.weapon_tier >= drop_tier:
		return
	if randf() >= drop_chance:
		return
	var loot := loot_scene.instantiate()
	loot.position = global_position
	loot.tier = drop_tier
	loot.get_node("Visual/Sword").color = player.weapon_arc_color[drop_tier - 1]
	# Next to the Player in the scene (not under Enemies, which the map counts),
	# drawn just below it so the Player walks over the drop.
	var parent := player.get_parent()
	parent.add_child.call_deferred(loot)
	parent.move_child.call_deferred(loot, player.get_index())
	print("%s dropped loot (tier %d)" % [name, drop_tier])


func _try_drop_armor() -> void:
	if not is_instance_valid(player) or player.has_armor:
		return
	if randf() >= armor_drop_chance:
		return
	var loot := loot_scene.instantiate()
	# A little lower than a weapon drop so both stay visible if they drop together.
	loot.position = global_position + Vector2(0, 24)
	loot.is_armor = true
	var parent := player.get_parent()
	parent.add_child.call_deferred(loot)
	parent.move_child.call_deferred(loot, player.get_index())
	print("%s dropped armor" % name)


func _try_drop_ring() -> void:
	if not is_instance_valid(player) or player.has_ring:
		return
	if randf() >= ring_drop_chance:
		return
	var loot := loot_scene.instantiate()
	# Left of the death spot (the heal orb goes right) so all drops stay visible.
	loot.position = global_position + Vector2(-28, 0)
	loot.is_ring = true
	var parent := player.get_parent()
	parent.add_child.call_deferred(loot)
	parent.move_child.call_deferred(loot, player.get_index())
	print("%s dropped a ring" % name)


func _try_drop_pet() -> void:
	if not is_instance_valid(player) or player.pet_kind == pet_drop_kind:
		return
	if randf() >= pet_drop_chance:
		return
	var loot := loot_scene.instantiate()
	# A little higher than a weapon drop so all three stay visible together.
	loot.position = global_position + Vector2(0, -24)
	loot.is_pet = true
	loot.tier = pet_drop_kind
	loot.get_node("Visual/Pet").color = player.pet_colors[pet_drop_kind - 1]
	var parent := player.get_parent()
	parent.add_child.call_deferred(loot)
	parent.move_child.call_deferred(loot, player.get_index())
	print("%s dropped pet kind %d" % [name, pet_drop_kind])


func _try_drop_heal() -> void:
	if not is_instance_valid(player) or player.is_dead or player.hp >= player.max_hp:
		return
	if randf() >= heal_drop_chance:
		return
	var loot := loot_scene.instantiate()
	# Beside the other drops so all of them stay visible together.
	loot.position = global_position + Vector2(28, 0)
	loot.is_heal = true
	var parent := player.get_parent()
	parent.add_child.call_deferred(loot)
	parent.move_child.call_deferred(loot, player.get_index())
	print("%s dropped a heal orb" % name)
