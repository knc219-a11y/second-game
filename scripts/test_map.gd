extends Node2D

# The game starts in the hub town (no enemies). Its gates lead into stages
# 1-3 and, once stage 3 is cleared, the special dungeon; each stage gate shows
# that stage's best grade, and locked gates are greyed out. Normal play is
# stage by stage (adventure): each stage places a fixed set of enemies from
# STAGES. Killing them all clears the stage (unlocking the next one in the save
# file), an exit appears at the right edge, and walking into it fades back to
# town, all on the same map. The Player node stays, so gear, pet and HP carry
# over. R restart (after death) reloads the scene: back to town, gear, pet,
# grades and unlocks kept (player.gd SAVE_PATH).
#
# Each stage also has its own rock layout (STAGE_ROCKS) and floor tint; moving
# on clears drops left on the ground.
#
# endless_mode is the special dungeon: the old test-map loop below (respawns +
# rising pressure) with no exit. Set from the start it skips the stages.
@export var endless_mode: bool = false
# Kinds: "normal", "tough", "ranged" (variants made by _make_tough/_make_ranged).
# Positions sit inside the walls and clear of rocks; enemies wait there until
# the Player comes within their detect_range.
const STAGES := [
	[["normal", Vector2(420, 450)], ["normal", Vector2(290, 760)], ["normal", Vector2(750, 450)]],
	[["normal", Vector2(650, 180)], ["normal", Vector2(800, 720)], ["tough", Vector2(1150, 450)], ["normal", Vector2(1300, 750)]],
	[["tough", Vector2(800, 450)], ["normal", Vector2(600, 760)], ["ranged", Vector2(1200, 130)], ["ranged", Vector2(1420, 640)], ["normal", Vector2(1150, 800)]],
]
# Rock layout per stage, same order as STAGES: [center, size] boxes. Stage 1
# matches the Rock1-4 placed in test_map.tscn (still used as-is by endless
# mode). Every layout leaves a way from player_start to exit_position and
# keeps clear of the stage's enemy positions.
# Region names (lore: the town sits on a dead god's corpse; each stage is one
# body lineage: 1 skin, 2 bone, 3 blood-flesh), shown on banners, gates and HUD.
# Stage 1 brings normal (skin), stage 2 adds tough (bone), stage 3 ranged (blood).
const TOWN_NAME := "Hidehold"
const STAGE_NAMES := ["Husk Flats", "Rib Field", "Vein Hollow"]
const DUNGEON_NAME := "The Wound"
const STAGE_ROCKS := [
	# Open field with a few scattered rocks.
	[[Vector2(500, 300), Vector2(120, 60)], [Vector2(1000, 550), Vector2(80, 160)], [Vector2(1250, 250), Vector2(200, 40)], [Vector2(350, 650), Vector2(60, 60)]],
	# Two broken walls make a middle lane with doorways (enemies only chase in
	# a straight line, so a long unbroken wall would strand them); a pillar
	# sits in front of the exit.
	[[Vector2(550, 280), Vector2(300, 40)], [Vector2(1000, 280), Vector2(300, 40)], [Vector2(650, 620), Vector2(300, 40)], [Vector2(1100, 620), Vector2(300, 40)], [Vector2(1350, 450), Vector2(60, 120)]],
	# Four pillars around the tough enemy; a split wall guards the exit side.
	[[Vector2(650, 300), Vector2(60, 60)], [Vector2(950, 300), Vector2(60, 60)], [Vector2(650, 600), Vector2(60, 60)], [Vector2(950, 600), Vector2(60, 60)], [Vector2(1300, 250), Vector2(40, 260)], [Vector2(1300, 720), Vector2(40, 200)]],
]
# Placeholder lineage colors per stage: 1 dried pinkish skin (apart from the
# town's ochre) with callus-yellow rocks, 2 dark marrow ground with dull bone
# rocks (dimmer than the bone tough enemy), 3 dark clotted red with raw-flesh
# rocks. Kept dark so the red normal, bone tough and violet ranged
# enemies, the pet and the drops stay readable on top.
const STAGE_FLOOR_COLORS := [Color(0.4, 0.3, 0.29, 1), Color(0.2, 0.19, 0.18, 1), Color(0.22, 0.1, 0.11, 1)]
# Stage 1 rocks wear painted props instead of the flat boxes. Both PNGs have
# their origin at the bottom centre (offset below); collisions stay the boxes.
const ROCK_PILE_TEX := preload("res://art/stage1/props/s1_rock_pile.png")
const ROCK_PILLAR_TEX := preload("res://art/stage1/props/s1_rock_pillar.png")
const ROCK_PILE_OFFSET := Vector2(-64, -92)
const ROCK_PILLAR_OFFSET := Vector2(-52, -212)
# Stage 1 landmark: a bone arch (320x264, origin at bottom centre 160,260)
# with only its two feet solid. The image is cut in two at ARCH_SPLIT_Y: the
# lower part draws under characters, the upper part over them, so walking
# through the arch puts you under its top without a Y-sort pass.
const BONE_ARCH_TEX := preload("res://art/stage1/props/s1_bone_arch.png")
const BONE_ARCH_ORIGIN := Vector2(160, 260)
const ARCH_SPLIT_Y := 190
const ARCH_TOP_Z := 4
const ARCH_FEET := [[Vector2(-85, -12), Vector2(48, 20)], [Vector2(105, -12), Vector2(56, 20)]]
@export var bone_arch_position: Vector2 = Vector2(820, 330)
const STAGE_ROCK_COLORS := [Color(0.6, 0.5, 0.34, 1), Color(0.52, 0.5, 0.44, 1), Color(0.45, 0.17, 0.2, 1)]
# Special dungeon: an open arena with four pillars around the middle, away from
# the edge spawn_points and the player_start, on a near-black floor with a red
# tinge (an open wound; a bright red floor once hid the tough enemies, which
# are now bone-colored).
const DUNGEON_ROCKS := [[Vector2(550, 280), Vector2(70, 70)], [Vector2(1050, 280), Vector2(70, 70)], [Vector2(550, 620), Vector2(70, 70)], [Vector2(1050, 620), Vector2(70, 70)]]
const DUNGEON_FLOOR_COLOR := Color(0.12, 0.08, 0.09, 1)
const DUNGEON_ROCK_COLOR := Color(0.55, 0.12, 0.16, 1)
const LOOT_SCRIPT := preload("res://scripts/loot.gd")
const CHEST_SCRIPT := preload("res://scripts/chest.gd")
const SHOT_SCRIPT := preload("res://scripts/projectile.gd")
@export var player_start: Vector2 = Vector2(200, 450)
@export var exit_position: Vector2 = Vector2(1545, 450)
# Walking within this many px of the exit moves on.
@export var exit_radius: float = 50.0
@export var fade_time: float = 0.3

var stage: int = 1
# Hub town: gate positions for stage 1..STAGES.size(), then the dungeon. The
# highest unlocked stage is saved (section "progress", key "unlocked");
# unlocked = STAGES.size() + 1 opens the dungeon gate.
const HUB_GATES := [Vector2(600, 540), Vector2(850, 540), Vector2(1100, 540), Vector2(1350, 540)]
const HUB_FLOOR_COLOR := Color(0.33, 0.3, 0.25, 1)
# Stage 1 floor is painted with s1_ground.png tiles (atlas row 0: 4 base, 2
# cracked, 2 red vein). Fixed seed so the floor looks the same every visit;
# other stages, town and dungeon keep the flat colour floor and grid.
const GROUND_SIZE := Vector2i(25, 15)
const GROUND_SEED := 1
@export var ground_crack_chance: float = 0.08
@export var ground_vein_chance: float = 0.04
const LOCKED_GATE_COLOR := Color(0.55, 0.55, 0.55, 0.6)
const DUNGEON_GATE_COLOR := Color(1, 0.35, 0.3, 0.8)
var in_hub: bool = false
var hub_gates: Array = []
var unlocked: int = 1
# Stage grade from hits taken (player.gd hits_taken) during the stage: S up to
# grade_s_hits, A up to grade_a_hits, else B. Shown on the clear banner; the
# best grade per stage is kept in the save file (player.gd SAVE_PATH, section
# "grades", key "stage_N", N = 1..STAGES.size()).
@export var grade_s_hits: int = 0
@export var grade_a_hits: int = 2
const GRADE_COLORS := {"S": Color(1, 0.85, 0.2, 1), "A": Color(0.5, 0.85, 1, 1), "B": Color(1, 1, 1, 1)}
@export var clear_banner_time: float = 2.5
# Reward chests by grade, placed in front of the exit: B = 1 chest, A = 2
# chests and opening one makes the other vanish, S = the same pick where one
# chest has s_special_chance to be a gold chest holding the special-effect item
# (the Nerve Ring, while not yet worn). Contents are the normal drops: the next
# weapon tier, the armor while not worn, or else an ichor drop.
@export var chest_scene: PackedScene = preload("res://scenes/chest.tscn")
@export var chest_offset_x: float = -110.0
@export var chest_gap_y: float = 160.0
@export var s_special_chance: float = 0.5
var stage_cleared: bool = false
var moving_on: bool = false

# Endless mode only: keeps a few enemies around so a fight doesn't end after 3 kills.
# While fewer than keep_alive enemies are alive, one more appears every
# respawn_delay s at the nearest map-edge point at least spawn_min_distance px
# from the Player, so there are never more than keep_alive. Stops once the Player is dead (R reloads the scene).
@export var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
@export var keep_alive: int = 3
@export var respawn_delay: float = 1.5
# Map-edge spawn points, inside the walls and clear of rocks.
@export var spawn_points: PackedVector2Array = PackedVector2Array([
	Vector2(60, 60), Vector2(400, 60), Vector2(800, 60), Vector2(1200, 60), Vector2(1540, 60),
	Vector2(60, 450), Vector2(1540, 450),
	Vector2(60, 840), Vector2(400, 840), Vector2(800, 840), Vector2(1200, 840), Vector2(1540, 840),
])
# Kept beyond detect_range (300) so a new enemy never pops up right next to the
# Player. Not strictly off-screen: the map is barely bigger than the view, so an
# off-screen point would mean a 7-15 s walk before the enemy arrives.
@export var spawn_min_distance: float = 400.0
# Rising pressure: every pressure_kills kills one more enemy is kept alive at
# once (keep_alive +1), up to max_keep_alive, so a geared-up run keeps getting
# busier instead of staying flat. The HUD counts kills; on each step up the
# label pops in pressure_color. R restart reloads the scene and resets both.
@export var pressure_kills: int = 10
@export var max_keep_alive: int = 6
@export var pressure_color: Color = Color(1, 0.55, 0.2, 1)
@export var pressure_flash_time: float = 1.0

# Tough variant: this fraction of respawns has more HP, a better drop chance, drops
# the Bone Blade (tier 2) instead of the Callus Blade, and super armor (keeps swinging when hit), drawn bigger and bone-colored (bone lineage) to read at a glance.
@export var tough_chance: float = 0.3
@export var tough_hp: int = 100
@export var tough_drop_chance: float = 0.7
@export var tough_drop_tier: int = 2
# Tough enemies rarely drop the Marrow Cub (player.gd pet kind 1) instead of
# the normal enemies' Scab Pup.
@export var tough_pet_drop_chance: float = 0.08
@export var tough_pet_drop_kind: int = 1
@export var tough_body_scale: float = 1.25
@export var tough_color: Color = Color(0.8, 0.74, 0.6, 1)
# Ranged variant (enemy.gd is_ranged): this further fraction of respawns keeps
# its distance and shoots; low HP, slower, drawn smaller and violet.
@export var ranged_chance: float = 0.2
@export var ranged_hp: int = 20
@export var ranged_move_speed: float = 80.0
@export var ranged_body_scale: float = 0.85
@export var ranged_color: Color = Color(0.5, 0.35, 0.9, 1)
# Ranged enemies rarely drop the Clot Imp (player.gd pet kind 3).
@export var ranged_pet_drop_chance: float = 0.1
@export var ranged_pet_drop_kind: int = 3

var respawn_left: float = 0.0
# keep_alive grows with kills in the dungeon; back to this when leaving it.
var base_keep_alive: int = 3
var kills: int = 0

@onready var enemies: Node2D = $World/Enemies
@onready var player: Node2D = $World/Player
@onready var kill_label: Label = $Hud/KillLabel
@onready var stage_banner: Label = $Hud/StageBanner
@onready var fade: ColorRect = $Hud/Fade
@onready var exit_gate: Node2D = $ExitGate
@onready var obstacles: Node2D = $World/Obstacles
# Y-sorted: rocks, Player, pet, enemies and their drops draw back to front by y.
@onready var world: Node2D = $World
@onready var floor_poly: Polygon2D = $Floor
@onready var ground: TileMapLayer = $Ground
@onready var grid: Node2D = $Grid


func _ready() -> void:
	base_keep_alive = keep_alive
	exit_gate.visible = false
	if not endless_mode:
		# The scene's placed enemies are only for endless mode; stages bring their own.
		for e in enemies.get_children():
			enemies.remove_child(e)
			e.free()
		_build_hub_gates()
		_enter_hub()
	enemies.child_exiting_tree.connect(_on_enemy_exiting)
	_update_kill_label()


# The town gates are copies of the exit gate, kept under the World in draw order.
func _build_hub_gates() -> void:
	for i in HUB_GATES.size():
		var gate := exit_gate.duplicate() as Node2D
		gate.name = "HubGate%d" % (i + 1)
		gate.position = HUB_GATES[i]
		var label := gate.get_node("Label") as Label
		label.offset_left = -60.0
		label.offset_right = 60.0
		label.offset_top = -126.0
		add_child(gate)
		move_child(gate, world.get_index())
		hub_gates.append(gate)


func _enter_hub() -> void:
	in_hub = true
	stage_cleared = false
	exit_gate.visible = false
	_build_rocks([])
	floor_poly.color = HUB_FLOOR_COLOR
	_show_ground(false)
	var cfg := ConfigFile.new()
	cfg.load(player.SAVE_PATH)
	unlocked = cfg.get_value("progress", "unlocked", 1)
	for i in hub_gates.size():
		var gate: Node2D = hub_gates[i]
		var label := gate.get_node("Label") as Label
		var open := i + 1 <= unlocked
		gate.visible = true
		gate.modulate = Color(1, 1, 1, 1) if open else LOCKED_GATE_COLOR
		label.modulate = Color(1, 1, 1, 1)
		if i >= STAGES.size():
			(gate.get_node("Door") as Polygon2D).color = DUNGEON_GATE_COLOR
			label.text = DUNGEON_NAME if open else DUNGEON_NAME + "\nLocked"
			continue
		var best: String = cfg.get_value("grades", "stage_%d" % (i + 1), "")
		if not open:
			label.text = "%s\nLocked" % STAGE_NAMES[i]
		elif best == "":
			label.text = "%s\nNew" % STAGE_NAMES[i]
		else:
			label.text = "%s\nBest %s" % [STAGE_NAMES[i], best]
			label.modulate = GRADE_COLORS[best]
	print("Town: unlocked %d" % unlocked)
	_show_banner(TOWN_NAME)


func _spawn_stage() -> void:
	stage_cleared = false
	player.hits_taken = 0
	_build_rocks(STAGE_ROCKS[(stage - 1) % STAGE_ROCKS.size()], STAGE_ROCK_COLORS[(stage - 1) % STAGE_ROCK_COLORS.size()])
	if stage == 1:
		_dress_rocks()
		_build_bone_arch()
	floor_poly.color = STAGE_FLOOR_COLORS[(stage - 1) % STAGE_FLOOR_COLORS.size()]
	_show_ground(stage == 1)
	for entry in STAGES[(stage - 1) % STAGES.size()]:
		var enemy := enemy_scene.instantiate()
		enemy.position = entry[1]
		if entry[0] == "tough":
			_make_tough(enemy)
		elif entry[0] == "ranged":
			_make_ranged(enemy)
		enemies.add_child(enemy)
	print("Stage %d: %d enemies" % [stage, enemies.get_child_count()])
	_show_banner("Stage %d  %s" % [stage, _stage_name()])


# Tiled floor on, grid off (or the other way round). Fills the layer once.
func _show_ground(on: bool) -> void:
	ground.visible = on
	grid.visible = not on
	if not on or ground.get_used_cells().size() > 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = GROUND_SEED
	for y in GROUND_SIZE.y:
		for x in GROUND_SIZE.x:
			var roll := rng.randf()
			var tile := rng.randi_range(0, 3)
			if roll < ground_vein_chance:
				tile = 6 + rng.randi_range(0, 1)
			elif roll < ground_vein_chance + ground_crack_chance:
				tile = 4 + rng.randi_range(0, 1)
			ground.set_cell(Vector2i(x, y), 0, Vector2i(tile, 0))


# Stage 1: hides each rock's box and stands a prop on the box's bottom edge.
# Tall boxes get the pillar, wide ones two piles, the rest one pile scaled to
# the box width.
func _dress_rocks() -> void:
	for rock in obstacles.get_children():
		if not rock.name.begins_with("Rock"):
			continue
		var size: Vector2 = ((rock.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size
		var bottom := Vector2(0, size.y / 2)
		(rock.get_node("Visual") as Polygon2D).visible = false
		if size.y > size.x * 1.5:
			_add_rock_sprite(rock, ROCK_PILLAR_TEX, ROCK_PILLAR_OFFSET, bottom, 1.0)
		elif size.x > 150:
			_add_rock_sprite(rock, ROCK_PILE_TEX, ROCK_PILE_OFFSET, bottom + Vector2(-size.x / 4, 0), 0.85)
			_add_rock_sprite(rock, ROCK_PILE_TEX, ROCK_PILE_OFFSET, bottom + Vector2(size.x / 4, 0), 0.85)
		else:
			_add_rock_sprite(rock, ROCK_PILE_TEX, ROCK_PILE_OFFSET, bottom, minf(1.0, size.x / 96.0))


# Named Rock* so the next _build_rocks clears it with the rocks.
func _build_bone_arch() -> void:
	var arch := StaticBody2D.new()
	arch.name = "RockBoneArch"
	arch.position = bone_arch_position
	for foot in ARCH_FEET:
		var shape := RectangleShape2D.new()
		shape.size = foot[1]
		var col := CollisionShape2D.new()
		col.shape = shape
		col.position = foot[0]
		arch.add_child(col)
	var h := BONE_ARCH_TEX.get_height()
	for part in [[0, ARCH_SPLIT_Y, ARCH_TOP_Z], [ARCH_SPLIT_Y, h - ARCH_SPLIT_Y, 0]]:
		var sprite := Sprite2D.new()
		sprite.texture = BONE_ARCH_TEX
		sprite.centered = false
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0, part[0], BONE_ARCH_TEX.get_width(), part[1])
		sprite.offset = Vector2(-BONE_ARCH_ORIGIN.x, part[0] - BONE_ARCH_ORIGIN.y)
		sprite.z_index = part[2]
		arch.add_child(sprite)
	obstacles.add_child(arch)


func _add_rock_sprite(rock: Node2D, tex: Texture2D, offset: Vector2, pos: Vector2, s: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.offset = offset
	sprite.position = pos
	sprite.scale = Vector2(s, s)
	rock.add_child(sprite)


# Replaces every Rock* under Obstacles (walls stay) with the given boxes.
func _build_rocks(boxes: Array, color: Color = Color.WHITE) -> void:
	for child in obstacles.get_children():
		if child.name.begins_with("Rock"):
			obstacles.remove_child(child)
			child.queue_free()
	for i in boxes.size():
		var center: Vector2 = boxes[i][0]
		var half: Vector2 = boxes[i][1] / 2.0
		var rock := StaticBody2D.new()
		rock.name = "Rock%d" % (i + 1)
		rock.position = center
		var shape := RectangleShape2D.new()
		shape.size = boxes[i][1]
		var col := CollisionShape2D.new()
		col.name = "CollisionShape2D"
		col.shape = shape
		rock.add_child(col)
		var visual := Polygon2D.new()
		visual.name = "Visual"
		visual.color = color
		visual.polygon = PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
		rock.add_child(visual)
		obstacles.add_child(rock)


func _stage_name() -> String:
	return STAGE_NAMES[(stage - 1) % STAGE_NAMES.size()]


func _show_banner(text: String, color: Color = Color(1, 1, 1, 1), hold: float = 1.2) -> void:
	stage_banner.text = text
	stage_banner.modulate = color
	var tween := stage_banner.create_tween()
	tween.tween_interval(hold)
	tween.tween_property(stage_banner, "modulate", Color(1, 1, 1, 0), 0.5)


func _alive_enemies() -> int:
	var alive := 0
	for e in enemies.get_children():
		if not e.is_queued_for_deletion():
			alive += 1
	return alive


# Enemies leave the tree only when killed (enemy.gd queue_free at 0 HP); the
# hp check also skips the scene being freed on restart.
func _on_enemy_exiting(enemy: Node) -> void:
	if enemy.get("hp") == null or enemy.hp > 0 or player.get("is_dead") == true:
		return
	kills += 1
	if not endless_mode:
		# Kills in the same frame as the clear would overwrite its exit hint.
		if not stage_cleared:
			_update_kill_label()
		# The dying enemy is already queued for deletion, so it isn't counted.
		# Several dying in one frame all see 0: clear only once.
		if _alive_enemies() == 0 and not stage_cleared:
			_clear_stage()
		return
	var before := keep_alive
	keep_alive = mini(keep_alive + (1 if kills % pressure_kills == 0 else 0), max_keep_alive)
	_update_kill_label()
	if keep_alive > before:
		print("Pressure up: %d enemies at once" % keep_alive)
		kill_label.modulate = pressure_color
		kill_label.scale = Vector2(1.3, 1.3)
		var tween := kill_label.create_tween().set_parallel()
		tween.tween_property(kill_label, "modulate", Color(1, 1, 1, 1), pressure_flash_time)
		tween.tween_property(kill_label, "scale", Vector2.ONE, pressure_flash_time * 0.3)


func _update_kill_label() -> void:
	if in_hub:
		kill_label.text = TOWN_NAME + "   Walk into a gate to start"
	elif endless_mode:
		kill_label.text = DUNGEON_NAME + "   Kills: %d   Enemies at once: %d" % [kills, keep_alive]
	else:
		kill_label.text = "%s   Enemies left: %d" % [_stage_name(), _alive_enemies()]


func _clear_stage() -> void:
	stage_cleared = true
	var hits: int = player.hits_taken
	var grade := "S" if hits <= grade_s_hits else ("A" if hits <= grade_a_hits else "B")
	var best := _save_best_grade(grade)
	_save_unlock(stage + 1)
	print("Stage %d clear: grade %s (%d hits), best %s" % [stage, grade, hits, best])
	_show_banner("%s Clear!\nGrade %s  (%d hits)   Best %s" % [_stage_name(), grade, hits, best], GRADE_COLORS[grade], clear_banner_time)
	kill_label.text = "%s   Clear! Back to %s on the right ->" % [_stage_name(), TOWN_NAME]
	exit_gate.position = exit_position
	exit_gate.visible = true
	_spawn_chests(grade)


func _spawn_chests(grade: String) -> void:
	# Upgrades the Player doesn't have yet; an ichor drop when there are none left.
	var pool: Array = []
	if player.weapon_tier < player.weapon_names.size():
		pool.append(["weapon", player.weapon_tier + 1])
	if not player.has_armor:
		pool.append(["armor", 1])
	pool.shuffle()
	var count := 1 if grade == "B" else 2
	var contents: Array = []
	for i in count:
		contents.append(pool[i] if i < pool.size() else ["heal", 1])
	var special: bool = grade == "S" and not player.has_ring and randf() < s_special_chance
	if special:
		contents[count - 1] = ["ring", 1]
	for i in count:
		var chest := chest_scene.instantiate()
		chest.kind = contents[i][0]
		chest.tier = contents[i][1]
		chest.special = special and i == count - 1
		var y := 0.0 if count == 1 else (i - 0.5) * chest_gap_y
		chest.position = exit_position + Vector2(chest_offset_x, y)
		chest.opened.connect(_on_chest_opened)
		add_child(chest)
		move_child(chest, world.get_index())
	print("Chests: %s%s" % [str(contents), " (special)" if special else ""])


# Pick one: the other chests vanish empty.
func _on_chest_opened(opened_chest: Node) -> void:
	for child in get_children():
		if child.get_script() == CHEST_SCRIPT and child != opened_chest and not child.is_open:
			child.vanish()


# Keeps the better of the saved and the new grade ("S" > "A" > "B") for this
# stage and returns it.
func _save_best_grade(grade: String) -> String:
	var cfg := ConfigFile.new()
	cfg.load(player.SAVE_PATH)
	var key := "stage_%d" % ((stage - 1) % STAGES.size() + 1)
	var best: String = cfg.get_value("grades", key, "")
	if best == "" or "SAB".find(grade) < "SAB".find(best):
		best = grade
		cfg.set_value("grades", key, best)
		cfg.save(player.SAVE_PATH)
	return best


# Opens stages up to n (n = STAGES.size() + 1 opens the dungeon) in the save file.
func _save_unlock(n: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(player.SAVE_PATH)
	if n > cfg.get_value("progress", "unlocked", 1):
		cfg.set_value("progress", "unlocked", n)
		cfg.save(player.SAVE_PATH)


# Fade out, put the Player (and pet) back at the start, bring in the target
# (0 = town, 1..STAGES.size() = that stage, above = the dungeon), fade in.
# Drops and chests left on the ground are cleared.
func _move_on(target: int) -> void:
	moving_on = true
	exit_gate.visible = false
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, fade_time)
	await tween.finished
	# Enemy drops sit in the World; chests (and what they give) under the map.
	for child in get_children() + world.get_children():
		if child.get_script() == LOOT_SCRIPT or child.get_script() == CHEST_SCRIPT:
			child.queue_free()
	player.position = player_start
	player.velocity = Vector2.ZERO
	if player.pet != null:
		player.pet.position = player_start + Vector2(-player.pet.follow_offset.x, player.pet.follow_offset.y)
	player.camera.reset_smoothing()
	in_hub = false
	for gate in hub_gates:
		gate.visible = false
	if target == 0:
		_enter_hub()
	elif target > STAGES.size():
		_enter_dungeon()
	else:
		stage = target
		_spawn_stage()
	_update_kill_label()
	tween = create_tween()
	tween.tween_property(fade, "color:a", 0.0, fade_time)
	await tween.finished
	moving_on = false


# Pause menu "Return to Town" from a stage or the dungeon: drops what is left
# there (enemies, shots in the air, dungeon loop) and fades back to town.
# Gear, pet and saved progress stay as they are.
func return_to_town() -> void:
	endless_mode = false
	keep_alive = base_keep_alive
	for e in enemies.get_children():
		e.queue_free()
	for child in world.get_children():
		if child.get_script() == SHOT_SCRIPT:
			child.queue_free()
	print("Return to town")
	_move_on(0)


# Turns the endless loop on from a fresh count; the first enemy comes after
# respawn_delay.
func _enter_dungeon() -> void:
	endless_mode = true
	kills = 0
	respawn_left = respawn_delay
	_build_rocks(DUNGEON_ROCKS, DUNGEON_ROCK_COLOR)
	floor_poly.color = DUNGEON_FLOOR_COLOR
	_show_ground(false)
	print("Dungeon")
	_show_banner(DUNGEON_NAME)


func _physics_process(delta: float) -> void:
	if player.get("is_dead") == true:
		return
	if not endless_mode:
		if moving_on:
			return
		if in_hub:
			for i in hub_gates.size():
				if i + 1 <= unlocked and player.position.distance_to(hub_gates[i].position) <= exit_radius:
					_move_on(i + 1)
					return
		elif stage_cleared and player.position.distance_to(exit_position) <= exit_radius:
			_move_on(0)
		return
	var alive := _alive_enemies()
	if alive >= keep_alive:
		respawn_left = respawn_delay
		return
	respawn_left -= delta
	if respawn_left <= 0.0:
		respawn_left = respawn_delay
		_spawn_enemy()


func _spawn_enemy() -> void:
	var best := spawn_points[0]
	var best_dist := INF
	for p in spawn_points:
		var d := p.distance_to(player.global_position)
		if d >= spawn_min_distance and d < best_dist:
			best = p
			best_dist = d
	var enemy := enemy_scene.instantiate()
	enemy.position = best
	# Spawned beyond detect_range: make it come for the Player anyway.
	enemy.detect_range = INF
	enemy.lose_range = INF
	var roll := randf()
	if roll < tough_chance:
		_make_tough(enemy)
	elif roll < tough_chance + ranged_chance:
		_make_ranged(enemy)
	enemies.add_child(enemy)


# Called before add_child, so enemy._ready picks up the new HP and color.
func _make_tough(enemy: Node) -> void:
	enemy.name = "Tough"
	enemy.max_hp = tough_hp
	enemy.drop_chance = tough_drop_chance
	enemy.drop_tier = tough_drop_tier
	enemy.pet_drop_chance = tough_pet_drop_chance
	enemy.pet_drop_kind = tough_pet_drop_kind
	enemy.super_armor = true
	var body := enemy.get_node("Body") as Polygon2D
	body.color = tough_color
	body.scale = Vector2(tough_body_scale, tough_body_scale)


func _make_ranged(enemy: Node) -> void:
	enemy.name = "Ranged"
	enemy.max_hp = ranged_hp
	enemy.move_speed = ranged_move_speed
	enemy.is_ranged = true
	enemy.pet_drop_chance = ranged_pet_drop_chance
	enemy.pet_drop_kind = ranged_pet_drop_kind
	var body := enemy.get_node("Body") as Polygon2D
	body.color = ranged_color
	body.scale = Vector2(ranged_body_scale, ranged_body_scale)
