extends CharacterBody2D

# Test enemy: chases the Player in a straight line (no pathfinding) and stops
# beside it on the same Y line, where the Player's left/right attack can reach.
# Lore (design doc worldbuilding-mapping.md, names not shown in game): each kind
# is regrown tissue of the dead god and shares its body lineage with its pet and
# weapon drop. normal = Husk Crawler (skin: Scab Pup, Callus Blade), tough =
# Rib Brute (bone: Marrow Cub, Bone Blade), ranged = Blood Spitter (blood:
# Clot Imp, shares the Callus Blade).
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
# normal enemies drop the Scab Pup (2); test_map.gd gives the tough variant the
# Marrow Cub (1) and its own chance. No drop while the Player has that same pet.
@export var pet_drop_chance: float = 0.04
@export var pet_drop_kind: int = 2
# Separate roll for an ichor drop (player.gd heal_amount), only while the Player
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
# Floating damage number above the enemy on each hit: rises damage_number_rise px
# and fades over damage_number_time s. Style (take_damage number_style):
# 0 = normal hit, 1 = big hit (combo finisher, Q Dash Slash, set shockwave),
# 2 = small side damage (pet bite, Nerve Ring graze).
@export var damage_number_time: float = 0.5
@export var damage_number_rise: float = 28.0
@export var damage_number_sizes: PackedInt32Array = PackedInt32Array([16, 22, 12])
@export var damage_number_colors: PackedColorArray = PackedColorArray([
	Color(1, 1, 1, 1), Color(1, 0.85, 0.2, 1), Color(0.65, 0.9, 1, 1),
])
# Ranged variant (test_map.gd mixes it into respawns): instead of closing in, it
# keeps keep_distance px to the Player's side on the same line, winds up for
# shot_startup s (aim line shown, its own warning ping) and fires one slow
# projectile left/right that a roll passes through or a step off the line dodges.
# Never counters; a hit during the wind-up still cancels the shot.
@export var is_ranged: bool = false
@export var keep_distance: float = 200.0
# Fires only while on the Player's line between these horizontal distances.
@export var shot_min_distance: float = 120.0
@export var shot_range: float = 280.0
@export var shot_startup: float = 0.55
@export var shot_cooldown: float = 2.2
@export var shot_speed: float = 150.0
@export var shot_damage: int = 8
# How far (px) the shot flies before it vanishes.
@export var shot_travel: float = 420.0
@export var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")
# Line of sight: only winds up when no rock or wall blocks the shot's lane, and
# stands lane_margin px short of the first one in the way (see _keep_range).
@export var lane_margin: float = 30.0
# Death burst (placeholder): instead of just vanishing, a white copy of the body
# topples over away from the hit, slides death_slide px and fades over
# death_duration s, while death_shard_count chips of its color fly out. Like
# the damage numbers it runs on game time, so it holds still during hitstop.
@export var death_duration: float = 0.35
@export var death_slide: float = 28.0
@export var death_shard_count: int = 6
@export var death_shard_distance: float = 46.0
# How far ahead (px) it looks for something in its way before sidestepping.
@export var sidestep_lookahead: float = 8.0

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
# Ranged variant: 1 = down, -1 = up while sidestepping round something, else 0.
var sidestep_dir: int = 0
# Same size as the shot's collision box (projectile.tscn), for the lane check.
var lane_shape := RectangleShape2D.new()

@onready var hp_label: Label = $HpLabel
# Placeholder attack visual; scale.x is locked toward the Player at attack start.
@onready var attack_pivot: Node2D = $AttackPivot
# Monitoring is on only during ACTIVE.
@onready var hitbox: Area2D = $AttackPivot/Hitbox
@onready var attack_arc: Polygon2D = $AttackPivot/AttackArc
# Placeholder danger zone matching the Hitbox; visible only during STARTUP.
@onready var warn_zone: Polygon2D = $AttackPivot/WarnZone
# Ranged variant's wind-up: the lane its shot will fly along.
@onready var aim_line: Polygon2D = $AttackPivot/AimLine
@onready var body: Polygon2D = $Body
@onready var base_color: Color = body.color


func _ready() -> void:
	hp = max_hp
	lane_shape.size = Vector2(14, 12)
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
	if is_ranged:
		_keep_range(to_player, delta)
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


# Ranged variant: hold keep_distance px to the Player's current side on its line
# (backing off when the Player closes in) and shoot when lined up and ready.
func _keep_range(to_player: Vector2, delta: float) -> void:
	var dx := global_position.x - player.global_position.x
	if dx != 0.0:
		side = 1 if dx > 0.0 else -1
	# Line of sight: stand only where nothing blocks the lane to the Player, a bit
	# closer than keep_distance if a rock or wall is in the way, or on the
	# Player's other side if there's no room (under shot_min_distance) on this one.
	var hold := _clear_hold(side)
	if hold < shot_min_distance:
		var other_hold := _clear_hold(-side)
		if other_hold > hold:
			side = -side
			hold = other_hold
	hold = maxf(hold, shot_min_distance)
	var on_line := absf(to_player.y) <= vertical_tolerance
	if on_line and absf(dx) >= shot_min_distance and absf(dx) <= shot_range and cooldown_left <= 0.0 \
			and _lane_clear_distance(global_position, -1 if dx > 0.0 else 1, absf(dx)) >= absf(dx):
		_start_attack()
		return
	var to_spot := player.global_position + Vector2(side * hold, 0.0) - global_position
	var speed := minf(move_speed, to_spot.length() / delta)
	velocity = to_spot.normalized() * speed
	# Something (a rock, the Player, another enemy) right in the way: sidestep
	# up/down past it instead of pushing into it, away from its middle.
	var ahead := move_and_collide(to_spot.normalized() * minf(sidestep_lookahead, to_spot.length()), true)
	if ahead:
		if sidestep_dir == 0:
			var blocker := ahead.get_collider() as Node2D
			sidestep_dir = 1 if blocker == null or blocker.global_position.y <= global_position.y else -1
		if test_move(global_transform, Vector2(0.0, sidestep_dir * sidestep_lookahead)):
			sidestep_dir = -sidestep_dir
		velocity = Vector2(0.0, sidestep_dir * move_speed)
	else:
		sidestep_dir = 0
	move_and_slide()


# How far (px) from the Player the ranged enemy can stand on side s with a clear
# lane: up to keep_distance, minus lane_margin before the first rock or wall.
func _clear_hold(s: int) -> float:
	var reach := keep_distance + lane_margin
	return minf(keep_distance, _lane_clear_distance(player.global_position, s, reach) - lane_margin)


# How far (px, up to length) a shot-sized box flies from `from` along dir
# (1 = right, -1 = left) before touching a wall or rock (world layer, as the
# shot does). The Player's own body is on that layer too and is skipped.
func _lane_clear_distance(from: Vector2, dir: int, length: float) -> float:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = lane_shape
	query.transform = Transform2D(0.0, from + Vector2(0.0, -28.0))
	query.motion = Vector2(dir * length, 0.0)
	query.collision_mask = 1
	query.exclude = [player.get_rid(), get_rid()]
	return get_world_2d().direct_space_state.cast_motion(query)[0] * length


# Other chasing enemies on side s (by their chosen side) closer to the Player
# than this one, or than max_dist when given.
func _count_ahead(s: int, max_dist: float = -1.0) -> int:
	var my_dist := global_position.distance_to(player.global_position) if max_dist < 0.0 else max_dist
	var count := 0
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or other.is_ranged or not other.is_chasing or other.side != s:
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
	cooldown_left = shot_cooldown if is_ranged else attack_cooldown
	# Left/right only: swing toward the side the Player is on.
	attack_pivot.scale.x = 1 if player.global_position.x >= global_position.x else -1
	attack_pivot.visible = true
	_set_attack_phase(AttackPhase.STARTUP)
	# Audible cue with the telegraph (see player.play_warn_sound).
	if player.has_method("play_warn_sound"):
		var kind := 2 if super_armor else (1 if is_counter else 0)
		player.play_warn_sound(3 if is_ranged else kind)


func _update_attack(delta: float) -> void:
	attack_time += delta
	var startup := counter_startup if is_counter else attack_startup
	if is_ranged:
		startup = shot_startup
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
	warn_zone.visible = phase == AttackPhase.STARTUP and not is_ranged
	aim_line.visible = phase == AttackPhase.STARTUP and is_ranged
	attack_arc.visible = phase != AttackPhase.STARTUP and not is_ranged
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
	if is_ranged:
		_fire()
		return
	for area in hitbox.get_overlapping_areas():
		var target := area.get_parent()
		if target.has_method("take_damage"):
			# Push the Player the way the swing faces (left/right only).
			target.take_damage(counter_damage if is_counter else attack_damage, int(attack_pivot.scale.x))
			attack_landed = true
			return


# One shot per attack (attack_landed marks it fired), from the enemy's feet line
# so it travels the same Y line the Player walks on.
func _fire() -> void:
	attack_landed = true
	var shot := projectile_scene.instantiate()
	shot.direction = int(attack_pivot.scale.x)
	shot.position = global_position + Vector2(shot.direction * 20.0, 0.0)
	shot.speed = shot_speed
	shot.damage = shot_damage
	shot.lifetime = shot_travel / shot_speed
	player.get_parent().add_child(shot)


# direction: 1 = right, -1 = left, 0 = no knockback.
# knockback_scale: multiplies knockback_distance (the Player's combo finisher pushes further).
# number_style: look of the floating damage number (see damage_number_sizes).
func take_damage(amount: int, direction: int = 0, knockback_scale: float = 1.0, number_style: int = 0) -> void:
	hp -= amount
	_spawn_damage_number(amount, number_style)
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
		_spawn_death_burst(direction)
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
		if not super_armor and not is_ranged:
			counter_ready = true


# A one-off Label in the world (not on the enemy, which may die from this hit).
# Its tween follows time_scale, so it holds still during hitstop.
func _spawn_damage_number(amount: int, style: int) -> void:
	if not is_instance_valid(player):
		return
	var label := Label.new()
	label.text = str(amount)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(60, 30)
	label.add_theme_font_size_override("font_size", damage_number_sizes[style])
	label.add_theme_color_override("font_color", damage_number_colors[style])
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.z_index = 20
	# Above the HP label, nudged sideways so numbers from quick hits don't stack exactly.
	label.position = global_position + Vector2(-30 + randf_range(-8.0, 8.0), -110)
	player.get_parent().add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - damage_number_rise, damage_number_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, damage_number_time * 0.5) \
		.set_delay(damage_number_time * 0.5)
	tween.tween_callback(label.queue_free)


# One-off nodes in the world (the enemy itself is freed this frame).
func _spawn_death_burst(direction: int) -> void:
	if not is_instance_valid(player):
		return
	# No push (pet bite, ring graze): fall away from the Player.
	var dir := direction
	if dir == 0:
		dir = 1 if global_position.x >= player.global_position.x else -1
	var world := player.get_parent()
	# Body copy, pivot at the feet like the real one, so it tips over sideways.
	var corpse := Polygon2D.new()
	corpse.polygon = body.polygon
	corpse.color = Color.WHITE
	corpse.scale = body.scale
	corpse.global_position = global_position
	corpse.z_index = 5
	world.add_child(corpse)
	var tween := corpse.create_tween()
	tween.tween_property(corpse, "color", base_color, death_duration * 0.3)
	tween.parallel().tween_property(corpse, "rotation", dir * PI * 0.5, death_duration * 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(corpse, "position:x", corpse.position.x + dir * death_slide, death_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(corpse, "modulate:a", 0.0, death_duration * 0.5).set_delay(death_duration * 0.5)
	tween.tween_callback(corpse.queue_free)
	# Chips burst from the chest, mostly toward the hit direction.
	var center := global_position + Vector2(0, -28) * body.scale.y
	for i in death_shard_count:
		var shard := Polygon2D.new()
		shard.polygon = PackedVector2Array([Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)])
		shard.color = base_color.lightened(0.2)
		shard.global_position = center
		shard.rotation = randf() * TAU
		shard.z_index = 6
		world.add_child(shard)
		var angle := randf_range(-PI * 0.45, PI * 0.45)
		var to := Vector2(cos(angle) * dir, sin(angle)) * death_shard_distance * randf_range(0.6, 1.0)
		var t := shard.create_tween().set_parallel()
		t.tween_property(shard, "position", shard.position + to, death_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(shard, "rotation", shard.rotation + dir * TAU, death_duration)
		t.tween_property(shard, "scale", Vector2.ONE * 0.3, death_duration)
		t.tween_property(shard, "modulate:a", 0.0, death_duration * 0.4).set_delay(death_duration * 0.6)
		t.chain().tween_callback(shard.queue_free)


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
	# Left of the death spot (the ichor drop goes right) so all drops stay visible.
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
	print("%s dropped an ichor drop" % name)
