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
# Kinds: "normal", "tough", "ranged" (variants made by _make_tough/_make_ranged);
# Stage 1 areas also use "flinger", "leader" and "boss".
# Positions sit inside the walls and clear of rocks; enemies wait there until
# the Player comes within their detect_range. An optional third value is a
# pack number: when one of a pack spots the Player, the whole pack comes.
# Stage 1 is played as areas instead (STAGE1_AREAS); its entry here is unused.
const STAGES := [
	[],
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
# Stage 1 areas 1-1, 1-2, 1-3, played in a row on the same map: clearing one
# opens the exit to the next (HP and hits taken carry on, drops left on the
# ground are cleared; no grade or chests in between). Clearing the last one clears Stage 1 (grade,
# chests, unlock) as before. Packs: 1-1 a pair past the start and three north
# of the bone arch; 1-2 three groups spread round the field; 1-3 adds the camp,
# 2 with their leader (a bigger Husk Crawler that leaps, see _make_leader); then
# the boss alone. Scab Flingers (ranged, _make_flinger) sit at the back of two
# 1-2 groups and of the 1-3 arch pack.
const STAGE1_AREAS := [
	[["normal", Vector2(560, 470), 0], ["normal", Vector2(610, 570), 0],
	["normal", Vector2(780, 170), 1], ["normal", Vector2(900, 140), 1], ["normal", Vector2(860, 230), 1]],
	[["normal", Vector2(520, 180), 0], ["normal", Vector2(620, 130), 0],
	["normal", Vector2(700, 700), 1], ["normal", Vector2(790, 780), 1], ["flinger", Vector2(630, 800), 1],
	["normal", Vector2(1250, 450), 2], ["flinger", Vector2(1350, 380), 2]],
	[["normal", Vector2(560, 470), 0], ["normal", Vector2(610, 570), 0],
	["normal", Vector2(780, 170), 1], ["flinger", Vector2(900, 140), 1], ["normal", Vector2(860, 230), 1],
	["normal", Vector2(1250, 700), 2], ["leader", Vector2(1380, 720), 2], ["normal", Vector2(1450, 600), 2]],
	[["boss", Vector2(1150, 450)]],
]
# The last area is the boss fight (see _make_boss).
const STAGE1_AREA_NAMES := ["1-1", "1-2", "1-3", "1-BOSS"]
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
# Stage 1 rock layout per area, same order as STAGE1_AREAS, so each area reads
# as a different stretch of the flats. 1-1 keeps STAGE_ROCKS[0]; the camp props
# (bone arch, tent, torches, watchtower) stay put in every area, so no rock
# goes near them, the enemy positions, the brood spots, player_start or the
# exit. 1-2: a pillar east of the arch and a low ridge splitting the south
# field; 1-3: a pillar in the middle of the field and a ridge in the
# south-west; the boss arena stays open with two small piles.
const STAGE1_AREA_ROCKS := [
	[[Vector2(500, 300), Vector2(120, 60)], [Vector2(1000, 550), Vector2(80, 160)], [Vector2(1250, 250), Vector2(200, 40)], [Vector2(350, 650), Vector2(60, 60)]],
	[[Vector2(420, 610), Vector2(70, 70)], [Vector2(1100, 190), Vector2(80, 170)], [Vector2(1000, 640), Vector2(200, 40)], [Vector2(1460, 260), Vector2(60, 60)], [Vector2(360, 230), Vector2(90, 50)]],
	[[Vector2(380, 250), Vector2(120, 60)], [Vector2(1010, 450), Vector2(80, 160)], [Vector2(1220, 160), Vector2(60, 60)], [Vector2(420, 760), Vector2(200, 40)]],
	[[Vector2(520, 690), Vector2(70, 70)], [Vector2(1330, 230), Vector2(70, 70)]],
]
# Placeholder lineage colors per stage: 1 dried pinkish skin (apart from the
# town's ochre) with callus-yellow rocks, 2 dark marrow ground with dull bone
# rocks (dimmer than the bone tough enemy), 3 dark clotted red with raw-flesh
# rocks. Kept dark so the red normal, bone tough and violet ranged
# enemies, the pet and the drops stay readable on top.
const STAGE_FLOOR_COLORS := [Color(0.4, 0.3, 0.29, 1), Color(0.2, 0.19, 0.18, 1), Color(0.22, 0.1, 0.11, 1)]
# Stages 2 and 3 paint the floor polygon with one seamless 512px texture,
# repeated (made by godot-arpg-design/s23-ground-check/make_floor.py; no
# source art yet): 2 porous grey bone with half-buried ribs, 3 raw wet flesh
# with veins and clotted pools. Stage 1 has its tiles instead (null here).
const STAGE_FLOOR_TEXTURES := [null, preload("res://art/stage2/tiles/s2_floor.png"), preload("res://art/stage3/tiles/s3_floor.png")]
# Stages 2 and 3 dress their rock boxes with painted heaps instead (2 bone
# heaps, 3 flesh mounds; 128x96, origin at the bottom centre; made by
# godot-arpg-design/s23-rock-check/make_props.py, no source art yet).
# Collisions stay the boxes. A wall gets a row of heaps along its bottom edge,
# a tall box a stack of them; each heap sorts on its own foot.
const STAGE_HEAPS := [
	[],
	[preload("res://art/stage2/props/s2_bone_heap_0.png"), preload("res://art/stage2/props/s2_bone_heap_1.png"), preload("res://art/stage2/props/s2_bone_heap_2.png")],
	[preload("res://art/stage3/props/s3_flesh_mound_0.png"), preload("res://art/stage3/props/s3_flesh_mound_1.png"), preload("res://art/stage3/props/s3_flesh_mound_2.png")],
]
const HEAP_OFFSET := Vector2(-64, -90)
# Heaps along a wall every ~HEAP_STEP px, up a tall box every ~HEAP_STACK px.
const HEAP_STEP := 70.0
const HEAP_STACK := 45.0
# Stage 1 rocks wear painted props instead of the flat boxes. Both PNGs have
# their origin at the bottom centre (offset below); collisions stay the boxes.
# Stage 1 normal enemy (Husk Crawler): 4 frames of 80x64, origin at the feet
# centre (40,60); see enemy.gd sprite_sheet.
const HUSK_CRAWLER_TEX := preload("res://art/stage1/enemies/s1_husk_crawler.png")
const BOSS_TEX := preload("res://art/stage1/enemies/s1_boss_husk_matron.png")
# Tough (bone) and ranged (blood) enemies wear Husk Crawler strips recoloured
# by godot-arpg-design/s23-enemy-check/recolor_crawler.py (same frames and
# origin; placeholder until real art): an ivory Rib Crawler with dark marrow,
# a crimson Vein Spitter with glowing magenta veins. Normal enemies wear the
# Husk Crawler everywhere (skin lineage).
const RIB_CRAWLER_TEX := preload("res://art/stage2/enemies/s2_rib_crawler.png")
const VEIN_SPITTER_TEX := preload("res://art/stage3/enemies/s3_vein_spitter.png")
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
# Stage 1 prop: a bone-pole hide tent (208x168, origin at bottom centre 104,164)
# in the open bottom-right corner. Only a low box on its footprint is solid;
# the World's Y-sort draws it in front of or behind characters.
const TENT_TEX := preload("res://art/stage1/props/s1_tent.png")
const TENT_ORIGIN := Vector2(104, 164)
const TENT_FOOTPRINT := [Vector2(0, -12), Vector2(170, 24)]
@export var tent_position: Vector2 = Vector2(1330, 860)
# Stage 1 prop: bone torches flanking the tent. The pole (44x116, origin at
# bottom centre 22,112) has no flame of its own; a 4-frame flame strip (36x46
# per frame, base at the bottom centre) loops in its bowl, with a soft additive
# glow that breathes. Only a small box at the foot is solid.
const TORCH_POLE_TEX := preload("res://art/stage1/props/s1_torch_pole.png")
const TORCH_FLAME_TEX := preload("res://art/stage1/props/s1_torch_flame.png")
const TORCH_ORIGIN := Vector2(22, 112)
const TORCH_FOOTPRINT := [Vector2(0, -4), Vector2(18, 10)]
const TORCH_BOWL := Vector2(3, -93)
const TORCH_FLAME_FPS := 8.0
@export var torch_positions: PackedVector2Array = PackedVector2Array([Vector2(1200, 872), Vector2(1462, 876)])
# Stage 1 prop: a bone-and-hide watchtower (194x304, origin at bottom centre
# 97,298), the tallest prop, standing at the bottom edge left of the camp. Only
# a low box across its legs is solid.
const WATCHTOWER_TEX := preload("res://art/stage1/props/s1_watchtower.png")
const WATCHTOWER_ORIGIN := Vector2(97, 298)
const WATCHTOWER_FOOTPRINT := [Vector2(0, -22), Vector2(140, 28)]
@export var watchtower_position: Vector2 = Vector2(1095, 888)
# Stage 1 props (rocks, arch top, tent, torches, watchtower) fade while they
# would hide the Player or an enemy: a body box overlaps the sprite and that
# character is drawn behind it (north of the prop, or under the arch top).
@export var prop_fade_alpha: float = 0.45
@export var prop_fade_time: float = 0.15
const CHAR_BODY_RECT := Rect2(-14, -56, 28, 56)
var fade_sprites: Array[Sprite2D] = []
# Stage 1 backdrop: the plateau sits on the god's corpse. Read outward it goes
# floor -> cut lip -> fog-filled gorge -> far bone shapes, and behind the top
# wall a skin cliff and spined ridge rise. Nothing here is solid (the walls
# still are). Each piece is [texture, bottom centre, scale, flip_h, haze
# amount, fade_from]: backdrop_fade.gdshader tints it toward the haze at its
# depth and dissolves its bottom from fade_from (UV.y) down, so no piece ends
# on a flat cut. Back pieces draw under the floor (the floor hides their
# feet), front ones over the floor's edge but under the World.
const BG_CLIFF_TEX := preload("res://art/stage1/bg/s1_bg_cliff.png")
const BG_RIDGE_TEX := preload("res://art/stage1/bg/s1_bg_ridge.png")
const BG_DOME_TEX := preload("res://art/stage1/bg/s1_bg_dome.png")
const BG_RIBS_TEX := preload("res://art/stage1/bg/s1_bg_ribs.png")
const BG_LEDGE_TEX := preload("res://art/stage1/bg/s1_bg_ledge.png")
const BG_PILLAR_TEX := preload("res://art/stage1/bg/s1_bg_pillar.png")
const BACKDROP_FADE_SHADER := preload("res://scripts/backdrop_fade.gdshader")
const BACKDROP_BACK := [
	# Far shapes behind the top cliffs, filling the gaps in their skyline.
	[BG_DOME_TEX, Vector2(260, -150), 1.3, false, 0.6, 0.7],
	[BG_DOME_TEX, Vector2(1340, -170), 1.3, true, 0.6, 0.7],
	# Gorge: left, right, bottom.
	[BG_RIDGE_TEX, Vector2(-130, 470), 0.7, true, 0.45, 0.55],
	[BG_PILLAR_TEX, Vector2(-120, 860), 0.8, false, 0.4, 0.55],
	[BG_PILLAR_TEX, Vector2(1720, 330), 0.8, true, 0.4, 0.55],
	[BG_RIBS_TEX, Vector2(1700, 800), 0.7, false, 0.45, 0.55],
	[BG_LEDGE_TEX, Vector2(380, 1130), 0.8, false, 0.4, 0.5],
	[BG_RIBS_TEX, Vector2(1000, 1150), 0.8, true, 0.4, 0.5],
	[BG_DOME_TEX, Vector2(1480, 1110), 0.8, false, 0.5, 0.5],
]
const BACKDROP_FRONT := [
	# Feet overlap the floor's top edge and fade out on the floor itself.
	[BG_RIDGE_TEX, Vector2(800, 62), 1.2, false, 0.12, 0.9],
	[BG_CLIFF_TEX, Vector2(-160, 72), 1.0, false, 0.08, 0.92],
	[BG_CLIFF_TEX, Vector2(1760, 72), 1.0, true, 0.08, 0.92],
]
# Haze behind it all: pale far above, dark deep below (stops at these y).
const BACKDROP_HAZE := [Color(0.56, 0.5, 0.48), Color(0.36, 0.3, 0.3), Color(0.16, 0.12, 0.12)]
const BACKDROP_HAZE_Y := [-700.0, 450.0, 1300.0]
# Fog band over the gorge: clear at the plateau edge, thick this far out.
const BACKDROP_FOG_DEPTH := 170.0
const BACKDROP_FOG_ALPHA := 0.75
# The plateau's broken edge (_add_cliff_edge): a skin rim from the plain
# ground tiles over a cliff face of uneven height (min, max px).
const S1_GROUND_TEX := preload("res://art/stage1/tiles/s1_ground.png")
const BG_FACE_TEX := preload("res://art/stage1/bg/s1_bg_cliff_face.png")
const BACKDROP_RIM_SHADE := Color(0.92, 0.86, 0.84)
const BACKDROP_FACE_SHADE := Color(0.78, 0.7, 0.69)
const BACKDROP_FACE_DEPTH := Vector2(70, 150)
# Fog over the gorge starts this far past the walls (so the face shows first).
const BACKDROP_FOG_START := 40.0
# Stage 1-3 camera stops this far past the walls (it showed up to 640px of
# outside before): the backdrop frames the plateau instead of filling half the screen.
const STAGE1_CAMERA_LIMITS := Rect2(-200, -300, 2000, 1400)
# Stages 2 and 3 get the same broken edge and fog (no painted far shapes):
# their own haze, a cliff face gradient-mapped from the Stage 1 one
# (godot-arpg-design/s23-edge-check/make_faces.py, placeholder) and a rim cut
# from their floor texture. The top edge there is a face rising away into
# the haze instead of the Stage 1 cliff paintings.
const STAGE_EDGE_LOOKS := [
	{},
	{"haze": [Color(0.5, 0.49, 0.46), Color(0.3, 0.29, 0.27), Color(0.11, 0.1, 0.1)], "floor": preload("res://art/stage2/tiles/s2_floor.png"), "face": preload("res://art/stage2/bg/s2_bg_cliff_face.png"), "rim_shade": Color(0.95, 0.95, 0.95), "face_shade": Color(0.9, 0.9, 0.9)},
	{"haze": [Color(0.5, 0.26, 0.27), Color(0.3, 0.12, 0.14), Color(0.11, 0.03, 0.05)], "floor": preload("res://art/stage3/tiles/s3_floor.png"), "face": preload("res://art/stage3/bg/s3_bg_cliff_face.png"), "rim_shade": Color(0.95, 0.95, 0.95), "face_shade": Color(0.9, 0.9, 0.9)},
	# The dungeon (key 4, its _move_on target): a darker wound, dim flesh face.
	{"haze": [Color(0.3, 0.12, 0.13), Color(0.16, 0.05, 0.06), Color(0.05, 0.01, 0.02)], "floor": WOUND_FLOOR_TEX, "face": preload("res://art/stage3/bg/s3_bg_cliff_face.png"), "rim_shade": Color(0.8, 0.75, 0.75), "face_shade": Color(0.62, 0.55, 0.55)},
]
var backdrop_back: Node2D
var backdrop_front: Node2D
var lip_texture: ImageTexture
# Per stage: [back, front] edge layers (Stage 1's are backdrop_back/front).
var stage_edges := {}
# What the edge builders below paint with; set per stage while building.
var edge_haze: Array = BACKDROP_HAZE
var edge_face: Texture2D = BG_FACE_TEX
var edge_rim_shade := BACKDROP_RIM_SHADE
var edge_face_shade := BACKDROP_FACE_SHADE
const STAGE_ROCK_COLORS := [Color(0.6, 0.5, 0.34, 1), Color(0.52, 0.5, 0.44, 1), Color(0.45, 0.17, 0.2, 1)]
# Special dungeon: an open arena with four pillars around the middle, away from
# the edge spawn_points and the player_start, on dark wound flesh
# (WOUND_FLOOR_TEX; DUNGEON_FLOOR_COLOR and DUNGEON_ROCK_COLOR are only the
# placeholder colours under the art).
const DUNGEON_ROCKS := [[Vector2(550, 280), Vector2(70, 70)], [Vector2(1050, 280), Vector2(70, 70)], [Vector2(550, 620), Vector2(70, 70)], [Vector2(1050, 620), Vector2(70, 70)]]
const DUNGEON_FLOOR_COLOR := Color(0.12, 0.08, 0.09, 1)
const DUNGEON_ROCK_COLOR := Color(0.55, 0.12, 0.16, 1)
# The dungeon wears a darker flesh floor (make_floor.py, placeholder), the
# Stage 3 flesh mounds on its pillars and its own edge (STAGE_EDGE_LOOKS[3]).
const WOUND_FLOOR_TEX := preload("res://art/dungeon/tiles/wound_floor.png")
const LOOT_SCRIPT := preload("res://scripts/loot.gd")
const CHEST_SCRIPT := preload("res://scripts/chest.gd")
const SHOT_SCRIPT := preload("res://scripts/projectile.gd")
@export var player_start: Vector2 = Vector2(200, 450)
@export var exit_position: Vector2 = Vector2(1545, 450)
# Walking within this many px of the exit moves on.
@export var exit_radius: float = 50.0
@export var fade_time: float = 0.3

var stage: int = 1
# Current Stage 1 area (1..STAGE1_AREAS.size()); always 1 in other stages.
var area: int = 1
# Hub town: gate positions for stage 1..STAGES.size(), then the dungeon. The
# highest unlocked stage is saved (section "progress", key "unlocked");
# unlocked = STAGES.size() + 1 opens the dungeon gate.
const HUB_GATES := [Vector2(600, 540), Vector2(850, 540), Vector2(1100, 540), Vector2(1350, 540)]
const HUB_FLOOR_COLOR := Color(0.33, 0.3, 0.25, 1)
# Stage 1 floor is painted with s1_ground.png tiles (atlas row 0: 4 base, 2
# cracked, 2 red vein). Fixed seed so the floor looks the same every visit;
# stages 2-3 have a painted floor texture (STAGE_FLOOR_TEXTURES); town and
# dungeon keep the flat colour floor and grid.
const GROUND_SIZE := Vector2i(25, 15)
const GROUND_SEED := 1
@export var ground_crack_chance: float = 0.08
@export var ground_vein_chance: float = 0.04
const LOCKED_GATE_COLOR := Color(0.55, 0.55, 0.55, 0.6)
const DUNGEON_GATE_COLOR := Color(1, 0.35, 0.3, 0.8)
var in_hub: bool = false
var hub_gates: Array = []
# Town blacksmith (placeholder anvil, town only): standing within
# blacksmith_radius and pressing `interact` (C) forges the worn piece with the
# lowest level +1 for Skin Crystal (player.gd forge_next / forge_costs), or
# once nothing can be forged, buys more bag slots (player.gd grow_bag). There
# `attack` (X) picks another piece to forge instead of swinging
# (player.gd cycle_forge_choice). Its label shows that piece and the cost.
const BLACKSMITH_POSITION := Vector2(330, 260)
@export var blacksmith_radius: float = 80.0
var blacksmith: Node2D = null
var blacksmith_label: Label = null
var unlocked: int = 1
# Stage grade from hits taken (player.gd hits_taken) during the stage: S up to
# grade_s_hits, A up to grade_a_hits, else B. Shown on the clear banner; the
# best grade per stage is kept in the save file (player.gd SAVE_PATH, section
# "grades", key "stage_N", N = 1..STAGES.size()).
@export var grade_s_hits: int = 0
@export var grade_a_hits: int = 2
# Stage 1 runs four areas (about 20 enemies and the boss) in one grade, so it
# allows more hits for S and A than the one-screen stages.
@export var stage1_grade_s_hits: int = 3
@export var stage1_grade_a_hits: int = 8
const GRADE_COLORS := {"S": Color(1, 0.85, 0.2, 1), "A": Color(0.5, 0.85, 1, 1), "B": Color(1, 1, 1, 1)}
@export var clear_banner_time: float = 2.5
# Reward chests by grade, placed in front of the exit: B = 1 chest, A = 2
# chests and opening one makes the other vanish, S = the same pick where one
# chest has s_special_chance to be a gold chest holding the special-effect item
# (a Nerve Ring roll). Contents are the normal drops, each rolling its own
# rarity: a weapon (_weapon_offer) and the armor.
@export var chest_scene: PackedScene = preload("res://scenes/chest.tscn")
@export var chest_offset_x: float = -110.0
@export var chest_gap_y: float = 160.0
@export var s_special_chance: float = 0.5
var stage_cleared: bool = false
var moving_on: bool = false
# First Stage 3 clear: walking into its exit shows the ending card (_show_ending)
# before town. The ending fires once, when the clear opens the dungeon.
var ending_pending: bool = false
var card: CanvasLayer = null
var card_to_town: bool = false
# X can't close the card until it has faded in, so the press that started the
# game (or a mashed attack) doesn't skip it.
@export var card_lock_time: float = 1.0
var card_lock_left: float = 0.0
# New Game (title.gd sets this meta on the root) opens on this card in town.
const INTRO_TEXT := """Hidehold

A god died, and its corpse became our land.
The body still heals itself. What grows back wakes up hungry.
We live on its remains: hunters bring back skin, bone and blood.

Walk into the Husk Flats gate to start your first hunt.
Between hunts, forge your gear at the anvil here (C).
Esc > Controls lists every key.

X: begin"""
const ENDING_TEXT := """THE END

The heart of the dead god beat once, then went still.
Husk Flats, Rib Field and Vein Hollow fall quiet.
Hidehold lives on what you carried back.

But the corpse keeps growing.
Below the town, The Wound has opened.

Thanks for playing.

X: return to Hidehold"""

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
	_build_backdrop()
	_build_boss_bar()
	exit_gate.visible = false
	if not endless_mode:
		# The scene's placed enemies are only for endless mode; stages bring their own.
		for e in enemies.get_children():
			enemies.remove_child(e)
			e.free()
		_build_hub_gates()
		_build_blacksmith()
		_enter_hub()
		if get_tree().root.has_meta("new_game_intro"):
			get_tree().root.remove_meta("new_game_intro")
			_show_card(INTRO_TEXT, false)
			print("Intro")
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


# Placeholder anvil with a forge glow behind it, in the y-sorted World.
func _build_blacksmith() -> void:
	blacksmith = Node2D.new()
	blacksmith.name = "Blacksmith"
	blacksmith.position = BLACKSMITH_POSITION
	var glow := Polygon2D.new()
	glow.color = Color(1, 0.45, 0.1, 0.35)
	glow.polygon = PackedVector2Array([Vector2(-46, -10), Vector2(-30, -62), Vector2(0, -76), Vector2(30, -62), Vector2(46, -10)])
	blacksmith.add_child(glow)
	var anvil := Polygon2D.new()
	anvil.color = Color(0.48, 0.48, 0.54, 1)
	anvil.polygon = PackedVector2Array([Vector2(-34, -40), Vector2(30, -40), Vector2(40, -30), Vector2(12, -26), Vector2(12, -14), Vector2(22, 0), Vector2(-22, 0), Vector2(-12, -14), Vector2(-12, -26), Vector2(-34, -30)])
	blacksmith.add_child(anvil)
	blacksmith_label = Label.new()
	blacksmith_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blacksmith_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	blacksmith_label.position = Vector2(-160, -212)
	blacksmith_label.size = Vector2(320, 72)
	blacksmith_label.add_theme_constant_override("outline_size", 6)
	blacksmith_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	blacksmith.add_child(blacksmith_label)
	blacksmith.visible = false
	world.add_child(blacksmith)


func _near_blacksmith() -> bool:
	return player.position.distance_to(BLACKSMITH_POSITION) <= blacksmith_radius


func _update_blacksmith_label() -> void:
	var cost: int = player.forge_cost()
	var kind: String = player.forge_target()
	var line := "Forge %s +%d: %d %s" % [kind.capitalize(), player.forge_level(kind) + 1, cost, player.material_name]
	if cost < 0:
		# Nothing to forge: C buys bag slots instead (player.gd grow_bag).
		cost = player.bag_grow_cost()
		line = "Bag +%d slots: %d %s" % [player.bag_grow_slots, cost, player.material_name]
		if cost < 0:
			line = "Forge and bag maxed"
	var near := _near_blacksmith()
	if near and cost > 0:
		line = "[C] " + line
	# With two or more pieces to forge, list them and mark the picked one.
	var picks: Array[String] = []
	for k in ["weapon", "armor", "ring"]:
		if player.can_forge(k):
			picks.append("<%s>" % k.capitalize() if k == kind else k.capitalize())
	if picks.size() >= 2:
		line += "\n%s%s" % ["[X] " if near else "", " ".join(picks)]
	blacksmith_label.text = "Blacksmith\n" + line
	blacksmith_label.modulate = Color(1, 1, 1, 1) if near else Color(1, 1, 1, 0.6)


func _enter_hub() -> void:
	in_hub = true
	player.drop_luck = 0
	if blacksmith != null:
		blacksmith.visible = true
		_update_blacksmith_label()
	stage_cleared = false
	exit_gate.visible = false
	_build_rocks([])
	_set_floor(HUB_FLOOR_COLOR)
	_show_ground(false)
	_show_backdrop(0)
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
			label.text += "\nDrop luck +%d" % _replay_luck(i + 1)
			label.modulate = GRADE_COLORS[best]
	print("Town: unlocked %d" % unlocked)
	_show_banner(TOWN_NAME)


func _spawn_stage() -> void:
	stage_cleared = false
	brood_called = 0
	# The grade counts hits over the whole stage, every area of it.
	if area == 1:
		player.hits_taken = 0
		player.drop_luck = _replay_luck(stage)
	var rocks: Array = STAGE1_AREA_ROCKS[area - 1] if stage == 1 else STAGE_ROCKS[(stage - 1) % STAGE_ROCKS.size()]
	_build_rocks(rocks, STAGE_ROCK_COLORS[(stage - 1) % STAGE_ROCK_COLORS.size()])
	if stage == 1:
		_dress_rocks()
		_build_bone_arch()
		_build_tent()
		_build_torches()
		_build_watchtower()
		if area == 1:
			_spawn_hidden_cache()
		elif AREA_CACHES.has(area):
			_spawn_hidden_cache(AREA_CACHES[area][0], AREA_CACHES[area][1])
	var floor_i := (stage - 1) % STAGE_FLOOR_COLORS.size()
	if not STAGE_HEAPS[floor_i].is_empty():
		_dress_heaps(STAGE_HEAPS[floor_i])
	_set_floor(STAGE_FLOOR_COLORS[floor_i], STAGE_FLOOR_TEXTURES[floor_i])
	_show_ground(stage == 1)
	_show_backdrop(stage)
	var packs := {}
	var entries: Array = STAGE1_AREAS[area - 1] if stage == 1 else STAGES[(stage - 1) % STAGES.size()]
	for entry in entries:
		var enemy := enemy_scene.instantiate()
		if entry.size() > 2:
			if not packs.has(entry[2]):
				packs[entry[2]] = []
			packs[entry[2]].append(enemy)
		enemy.position = entry[1]
		if entry[0] == "tough":
			_make_tough(enemy)
		elif entry[0] == "ranged":
			_make_ranged(enemy)
		elif entry[0] == "leader":
			_make_leader(enemy)
		elif entry[0] == "flinger":
			_make_flinger(enemy)
		elif entry[0] == "boss":
			_make_boss(enemy)
		else:
			# Normal (Husk Crawler) wears its painted sprite.
			enemy.sprite_sheet = HUSK_CRAWLER_TEX
		enemies.add_child(enemy)
	for pack in packs.values():
		for enemy in pack:
			enemy.pack_mates.assign(pack.filter(func(e): return e != enemy))
	print("Stage %s: %d enemies" % [_stage_number(), enemies.get_child_count()])
	var banner := "Stage %s  %s" % [_stage_number(), _stage_name()]
	if area == 1 and player.drop_luck > 0:
		banner += "\n%s" % _luck_text()
	_show_banner(banner, Color(1, 1, 1, 1) if player.drop_luck == 0 else LUCK_COLOR)


# Repeat-farming reward: replaying a stage already cleared gives drop luck +1
# (player.gd luck_weight_shift), +2 once its best grade is S; an S clear adds
# one more for that clear's chests. Shown on the stage and clear banners, the
# town gate labels (what entering gives) and the stage HUD line.
const LUCK_COLOR := Color(0.6, 1, 0.75, 1)


func _replay_luck(for_stage: int) -> int:
	var cfg := ConfigFile.new()
	cfg.load(player.SAVE_PATH)
	var best: String = cfg.get_value("grades", "stage_%d" % ((for_stage - 1) % STAGES.size() + 1), "")
	if best == "":
		return 0
	return 2 if best == "S" else 1


func _luck_text() -> String:
	var w: Array[int] = player.luck_weights()
	return "Drop luck +%d  (Rare %d%%  Legendary %d%%)" % [player.drop_luck, w[2], w[3]]


# Short HUD tail for the stage line, empty without luck.
func _luck_hud() -> String:
	return "   Drop luck +%d" % player.drop_luck if player.drop_luck > 0 else ""


# Flat colour floor, or a repeated painted texture (no grid over it).
func _set_floor(color: Color, tex: Texture2D = null) -> void:
	floor_poly.texture = tex
	floor_poly.color = Color(1, 1, 1, 1) if tex else color
	grid.visible = tex == null


# Tiled floor on, grid off (or the other way round). Fills the layer once.
func _show_ground(on: bool) -> void:
	ground.visible = on
	grid.visible = not on and floor_poly.texture == null
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


# Built once, hidden; _show_backdrop turns on one stage's edge at a time.
func _build_backdrop() -> void:
	backdrop_back = Node2D.new()
	backdrop_back.name = "BackdropBack"
	add_child(backdrop_back)
	move_child(backdrop_back, floor_poly.get_index())
	var ys: Array = [-1600.0] + BACKDROP_HAZE_Y + [2400.0]
	var cs: Array = [BACKDROP_HAZE[0]] + BACKDROP_HAZE + [BACKDROP_HAZE[2]]
	for i in ys.size() - 1:
		var haze := Polygon2D.new()
		haze.polygon = PackedVector2Array([Vector2(-1600, ys[i]), Vector2(3200, ys[i]), Vector2(3200, ys[i + 1]), Vector2(-1600, ys[i + 1])])
		haze.vertex_colors = PackedColorArray([cs[i], cs[i], cs[i + 1], cs[i + 1]])
		backdrop_back.add_child(haze)
	for piece in BACKDROP_BACK:
		backdrop_back.add_child(_backdrop_sprite(piece))
	backdrop_front = Node2D.new()
	backdrop_front.name = "BackdropFront"
	add_child(backdrop_front)
	move_child(backdrop_front, grid.get_index() + 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = GROUND_SEED
	lip_texture = ImageTexture.create_from_image(S1_GROUND_TEX.get_image().get_region(Rect2i(0, 0, 256, 64)))
	# A broken cliff edge on all three open sides (the bottom one also covers
	# the floor tiles that run past y 900), then fog over it so the face sinks
	# into the gorge. The rim repeats the plain ground tiles only (no red veins).
	# The bottom face runs on past both corners and draws last, so it wraps
	# over the feet of the side faces.
	_add_cliff_edge(Vector2(0, 0), Vector2(0, 1), Vector2(-1, 0), 900.0, 40.0, rng)
	_add_cliff_edge(Vector2(1600, 900), Vector2(0, -1), Vector2(1, 0), 900.0, 40.0, rng)
	_add_cliff_edge(Vector2(1600, 900), Vector2(-1, 0), Vector2(0, 1), 1600.0, 170.0, rng)
	_add_fog()
	# Soft shade on the floor at the cliff's foot, then the cliffs.
	var shade := Polygon2D.new()
	shade.polygon = PackedVector2Array([Vector2(-200, 0), Vector2(1800, 0), Vector2(1800, 90), Vector2(-200, 90)])
	var dark := Color(0.12, 0.08, 0.08, 0.35)
	var clear := Color(0.12, 0.08, 0.08, 0.0)
	shade.vertex_colors = PackedColorArray([dark, dark, clear, clear])
	backdrop_front.add_child(shade)
	for piece in BACKDROP_FRONT:
		backdrop_front.add_child(_backdrop_sprite(piece))
	stage_edges[1] = [backdrop_back, backdrop_front]
	for st in [2, 3, 4]:
		_build_stage_edges(st)
	_show_backdrop(0)


# Stage 2/3 edge (see STAGE_EDGE_LOOKS): haze behind, then a broken edge on all
# four sides with fog over the gorge. Built once, hidden.
func _build_stage_edges(st: int) -> void:
	var look: Dictionary = STAGE_EDGE_LOOKS[st - 1]
	edge_haze = look["haze"]
	edge_face = look["face"]
	edge_rim_shade = look["rim_shade"]
	edge_face_shade = look["face_shade"]
	var back := Node2D.new()
	back.name = "Edge%dBack" % st
	add_child(back)
	move_child(back, floor_poly.get_index())
	var ys: Array = [-1600.0] + BACKDROP_HAZE_Y + [2400.0]
	var cs: Array = [edge_haze[0]] + edge_haze + [edge_haze[2]]
	for i in ys.size() - 1:
		var haze := Polygon2D.new()
		haze.polygon = PackedVector2Array([Vector2(-1600, ys[i]), Vector2(3200, ys[i]), Vector2(3200, ys[i + 1]), Vector2(-1600, ys[i + 1])])
		haze.vertex_colors = PackedColorArray([cs[i], cs[i], cs[i + 1], cs[i + 1]])
		back.add_child(haze)
	var front := Node2D.new()
	front.name = "Edge%dFront" % st
	add_child(front)
	move_child(front, grid.get_index() + 1)
	var saved := backdrop_front
	backdrop_front = front
	var floor_tex: Texture2D = look["floor"]
	lip_texture = ImageTexture.create_from_image(floor_tex.get_image().get_region(Rect2i(0, 0, 256, 64)))
	var rng := RandomNumberGenerator.new()
	rng.seed = GROUND_SEED + st
	_add_cliff_edge(Vector2(0, 0), Vector2(1, 0), Vector2(0, -1), 1600.0, 40.0, rng, true)
	_add_cliff_edge(Vector2(0, 0), Vector2(0, 1), Vector2(-1, 0), 900.0, 40.0, rng)
	_add_cliff_edge(Vector2(1600, 900), Vector2(0, -1), Vector2(1, 0), 900.0, 40.0, rng)
	_add_cliff_edge(Vector2(1600, 900), Vector2(-1, 0), Vector2(0, 1), 1600.0, 170.0, rng)
	_add_fog()
	backdrop_front = saved
	stage_edges[st] = [back, front]
	edge_haze = BACKDROP_HAZE
	edge_face = BG_FACE_TEX
	edge_rim_shade = BACKDROP_RIM_SHADE
	edge_face_shade = BACKDROP_FACE_SHADE


func _haze_at(y: float) -> Color:
	if y <= BACKDROP_HAZE_Y[0]:
		return edge_haze[0]
	for i in 2:
		if y <= BACKDROP_HAZE_Y[i + 1]:
			return edge_haze[i].lerp(edge_haze[i + 1], (y - BACKDROP_HAZE_Y[i]) / (BACKDROP_HAZE_Y[i + 1] - BACKDROP_HAZE_Y[i]))
	return edge_haze[2]


# Fog over the gorge on the left, right and bottom: a ring with mitred
# corners (so the bands don't stack into a darker box there), clear
# BACKDROP_FOG_START past the walls and thick BACKDROP_FOG_DEPTH further out,
# then solid beyond. Its top end hides behind the top cliffs.
func _add_fog() -> void:
	var i0 := Vector2(-BACKDROP_FOG_START, -200)
	var i1 := Vector2(1600 + BACKDROP_FOG_START, 900 + BACKDROP_FOG_START)
	var o0 := i0 - Vector2(BACKDROP_FOG_DEPTH, 0)
	var o1 := i1 + Vector2(BACKDROP_FOG_DEPTH, BACKDROP_FOG_DEPTH)
	var inner := [i0, Vector2(i0.x, i1.y), i1, Vector2(i1.x, i0.y)]
	var outer := [o0, Vector2(o0.x, o1.y), o1, Vector2(o1.x, o0.y)]
	for side in 3:
		var pts := [inner[side], inner[side + 1], outer[side + 1], outer[side]]
		var cols := PackedColorArray()
		for k in 4:
			var c := _haze_at(pts[k].y)
			c.a = 0.0 if k < 2 else BACKDROP_FOG_ALPHA
			cols.append(c)
		var fog := Polygon2D.new()
		fog.polygon = PackedVector2Array(pts)
		fog.vertex_colors = cols
		backdrop_front.add_child(fog)
	for r in [Rect2(-1600, -200, o0.x + 1600, 2600), Rect2(o1.x, -200, 1600, 2600), Rect2(o0.x, o1.y, o1.x - o0.x, 1200)]:
		var solid := Polygon2D.new()
		solid.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		var top := _haze_at(r.position.y)
		var low := _haze_at(r.end.y)
		top.a = BACKDROP_FOG_ALPHA
		low.a = BACKDROP_FOG_ALPHA
		solid.vertex_colors = PackedColorArray([top, top, low, low])
		backdrop_front.add_child(solid)


# The plateau's broken edge, from `start` along `along` for `length`, falling
# away in direction `out`. Rows: a ragged skin rim (ground texture) that bites
# up to ~18px into the floor, then a cliff face (furrows, fibres and bone
# spurs from s1_bg_cliff_face.png) of uneven height that darkens toward its
# foot in the fog. Only the look is ragged: the straight walls still collide.
# fade_far: the face fades out at its far end (a top edge rising into haze).
func _add_cliff_edge(start: Vector2, along: Vector2, out: Vector2, length: float, extend: float, rng: RandomNumberGenerator, fade_far: bool = false) -> void:
	var waves := []
	for k in 3:
		waves.append([rng.randf_range(0.004, 0.02) * (k + 1), rng.randf_range(0, TAU)])
	var rim_v := []
	var face_v := []
	var d := -extend
	while d <= length + extend:
		var n0 := 0.0
		var n1 := 0.0
		for w in waves:
			n0 += sin(d * w[0] + w[1])
			n1 += sin(d * w[0] * 1.7 + w[1] * 2.0)
		n0 = clampf(n0 / 3.0 * 0.5 + 0.5 + rng.randf_range(-0.12, 0.12), 0.0, 1.0)
		n1 = clampf(n1 / 3.0 * 0.5 + 0.5 + rng.randf_range(-0.15, 0.15), 0.0, 1.0)
		var top := start + along * d - out * (18.0 * n0)
		var rim := top + out * rng.randf_range(8.0, 14.0)
		var bottom := rim + out * lerpf(BACKDROP_FACE_DEPTH.x, BACKDROP_FACE_DEPTH.y, n1)
		rim_v.append([top, rim, d])
		face_v.append([rim, bottom, d])
		d += rng.randf_range(14.0, 26.0)
	var mid_shade := edge_face_shade
	var top_shade := edge_face_shade.darkened(0.4)
	# Solid to its ragged foot (a fade would show the floor tiles that run
	# past y 900); the fog over it does the dissolving.
	var low_shade := edge_face_shade.darkened(0.62)
	if fade_far:
		low_shade.a = 0.0
	var face_h := float(edge_face.get_height())
	var rim_mesh := []
	var face_mesh := []
	for row in rim_v:
		# The rim stops at the floor's corners; the face runs on past them.
		var past: float = maxf(-row[2], row[2] - length)
		var fade := clampf(1.0 - past / 16.0, 0.0, 1.0)
		var rim_top := edge_rim_shade
		var rim_low := edge_rim_shade.darkened(0.25)
		rim_top.a = fade
		rim_low.a = fade
		rim_mesh.append([row[0], Vector2(row[2], 0), rim_top])
		rim_mesh.append([row[1], Vector2(row[2], 14), rim_low])
	var taper := minf(70.0, extend)
	for row in face_v:
		var p0: Vector2 = row[0]
		var p1: Vector2 = row[1]
		# Past the floor's corners the face thins out instead of ending on a cut.
		var past: float = maxf(-row[2], row[2] - length)
		var a := clampf((extend - past) / taper, 0.0, 1.0) if past > 0.0 else 1.0
		var shades := [top_shade, mid_shade, low_shade]
		for k in 3:
			shades[k] = Color(shades[k], shades[k].a * a)
		face_mesh.append([p0, Vector2(row[2], 0), shades[0]])
		face_mesh.append([p0.lerp(p1, 0.25), Vector2(row[2], face_h * 0.25), shades[1]])
		face_mesh.append([p1, Vector2(row[2], face_h), shades[2]])
	_add_strip(face_mesh, 3, edge_face)
	_add_strip(rim_mesh, 2, lip_texture)


# A textured strip from columns of `rows` vertices [position, uv, colour].
func _add_strip(verts: Array, rows: int, tex: Texture2D) -> void:
	var pos := PackedVector2Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var size := tex.get_size()
	for c in verts.size() / rows - 1:
		for r in rows - 1:
			var q := [verts[c * rows + r], verts[(c + 1) * rows + r], verts[(c + 1) * rows + r + 1], verts[c * rows + r + 1]]
			for i in [0, 1, 2, 0, 2, 3]:
				pos.append(q[i][0])
				uv.append(q[i][1] / size)
				col.append(q[i][2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = col
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance2D.new()
	node.mesh = mesh
	node.texture = tex
	node.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	backdrop_front.add_child(node)


func _backdrop_sprite(piece: Array) -> Sprite2D:
	var tex: Texture2D = piece[0]
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
	sprite.position = piece[1]
	sprite.scale = Vector2(piece[2], piece[2])
	sprite.flip_h = piece[3]
	var mat := ShaderMaterial.new()
	mat.shader = BACKDROP_FADE_SHADER
	mat.set_shader_parameter("haze", _haze_at(piece[1].y - tex.get_height() * piece[2] * 0.5))
	mat.set_shader_parameter("haze_amount", piece[4])
	mat.set_shader_parameter("fade_from", piece[5])
	sprite.material = mat
	return sprite


# The plain wall strips show in town and the dungeon; in stages 1-3 (`st`,
# 0 = none) that stage's edge layers are the edge and the camera stops short
# of the far outside.
func _show_backdrop(st: int) -> void:
	for k in stage_edges:
		for layer in stage_edges[k]:
			layer.visible = k == st
	var on := stage_edges.has(st)
	for wall in ["WallTop", "WallBottom", "WallLeft", "WallRight"]:
		(obstacles.get_node(wall).get_node("Visual") as CanvasItem).visible = not on
	var cam: Camera2D = player.camera
	var r := STAGE1_CAMERA_LIMITS if on else Rect2(-10000000, -10000000, 20000000, 20000000)
	cam.limit_left = int(r.position.x)
	cam.limit_top = int(r.position.y)
	cam.limit_right = int(r.end.x)
	cam.limit_bottom = int(r.end.y)


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
			fade_sprites.append(_add_rock_sprite(rock, ROCK_PILLAR_TEX, ROCK_PILLAR_OFFSET, bottom, 1.0))
		elif size.x > 150:
			fade_sprites.append(_add_rock_sprite(rock, ROCK_PILE_TEX, ROCK_PILE_OFFSET, bottom + Vector2(-size.x / 4, 0), 0.85))
			fade_sprites.append(_add_rock_sprite(rock, ROCK_PILE_TEX, ROCK_PILE_OFFSET, bottom + Vector2(size.x / 4, 0), 0.85))
		else:
			fade_sprites.append(_add_rock_sprite(rock, ROCK_PILE_TEX, ROCK_PILE_OFFSET, bottom, minf(1.0, size.x / 96.0)))


# Stages 2-3: hides each rock's box and lines it with heaps (STAGE_HEAPS),
# each on its own anchor at its foot so the Player sorts and fades against
# that heap, not the middle of a long wall.
func _dress_heaps(heaps: Array) -> void:
	var n := 0
	for rock in obstacles.get_children():
		if not rock.name.begins_with("Rock"):
			continue
		var size: Vector2 = ((rock.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size
		(rock.get_node("Visual") as Polygon2D).visible = false
		rock.y_sort_enabled = true
		var feet: Array[Vector2] = []
		var width := size.x
		if size.y > size.x * 1.5:
			var count := ceili(size.y / HEAP_STACK)
			for i in count:
				feet.append(Vector2(0, -size.y / 2 + size.y * (i + 1) / count))
		else:
			var count := ceili(size.x / HEAP_STEP)
			width = size.x / count
			for i in count:
				feet.append(Vector2(-size.x / 2 + width * (i + 0.5), size.y / 2))
		var s := clampf(width * 1.6 / 128.0, 0.6, 1.0)
		for foot in feet:
			var anchor := Node2D.new()
			anchor.position = foot
			rock.add_child(anchor)
			var sprite := _add_rock_sprite(anchor, heaps[n % heaps.size()], HEAP_OFFSET, Vector2.ZERO, s)
			sprite.flip_h = n % 2 == 1
			fade_sprites.append(sprite)
			n += 1


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
		if part[2] > 0:
			fade_sprites.append(sprite)
	obstacles.add_child(arch)


# Named Rock* so the next _build_rocks clears it with the rocks.
func _build_tent() -> void:
	var tent := StaticBody2D.new()
	tent.name = "RockTent"
	tent.position = tent_position
	var shape := RectangleShape2D.new()
	shape.size = TENT_FOOTPRINT[1]
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = TENT_FOOTPRINT[0]
	tent.add_child(col)
	var sprite := Sprite2D.new()
	sprite.texture = TENT_TEX
	sprite.centered = false
	sprite.offset = -TENT_ORIGIN
	tent.add_child(sprite)
	fade_sprites.append(sprite)
	obstacles.add_child(tent)


# Named Rock* so the next _build_rocks clears them with the rocks.
func _build_torches() -> void:
	var frames := SpriteFrames.new()
	for i in 4:
		var atlas := AtlasTexture.new()
		atlas.atlas = TORCH_FLAME_TEX
		atlas.region = Rect2(i * 36, 0, 36, 46)
		frames.add_frame("default", atlas)
	frames.set_animation_speed("default", TORCH_FLAME_FPS)
	var glow_tex := GradientTexture2D.new()
	glow_tex.width = 112
	glow_tex.height = 112
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(0.5, 0.0)
	glow_tex.gradient = Gradient.new()
	glow_tex.gradient.set_color(0, Color(1.0, 0.45, 0.15, 0.28))
	glow_tex.gradient.set_color(1, Color(1.0, 0.35, 0.1, 0.0))
	var glow_mat := CanvasItemMaterial.new()
	glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in torch_positions.size():
		var torch := StaticBody2D.new()
		torch.name = "RockTorch%d" % i
		torch.position = torch_positions[i]
		var shape := RectangleShape2D.new()
		shape.size = TORCH_FOOTPRINT[1]
		var col := CollisionShape2D.new()
		col.shape = shape
		col.position = TORCH_FOOTPRINT[0]
		torch.add_child(col)
		var pole := Sprite2D.new()
		pole.texture = TORCH_POLE_TEX
		pole.centered = false
		pole.offset = -TORCH_ORIGIN
		torch.add_child(pole)
		# The pole's box decides; the whole torch (flame and glow too) fades.
		pole.set_meta("fade_node", torch)
		fade_sprites.append(pole)
		var flame := AnimatedSprite2D.new()
		flame.sprite_frames = frames
		flame.centered = false
		flame.offset = Vector2(-18, -46)
		flame.position = TORCH_BOWL
		flame.frame = i * 2 % 4
		flame.play()
		torch.add_child(flame)
		var glow := Sprite2D.new()
		glow.texture = glow_tex
		glow.material = glow_mat
		glow.position = TORCH_BOWL + Vector2(0, -14)
		torch.add_child(glow)
		var tween := glow.create_tween().set_loops()
		tween.tween_property(glow, "scale", Vector2(1.12, 1.12), 0.35 + 0.07 * i)
		tween.tween_property(glow, "scale", Vector2(0.92, 0.92), 0.4 + 0.05 * i)
		obstacles.add_child(torch)


# Named Rock* so the next _build_rocks clears it with the rocks.
func _build_watchtower() -> void:
	var tower := StaticBody2D.new()
	tower.name = "RockWatchtower"
	tower.position = watchtower_position
	var shape := RectangleShape2D.new()
	shape.size = WATCHTOWER_FOOTPRINT[1]
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = WATCHTOWER_FOOTPRINT[0]
	tower.add_child(col)
	var sprite := Sprite2D.new()
	sprite.texture = WATCHTOWER_TEX
	sprite.centered = false
	sprite.offset = -WATCHTOWER_ORIGIN
	tower.add_child(sprite)
	fade_sprites.append(sprite)
	obstacles.add_child(tower)


func _add_rock_sprite(rock: Node2D, tex: Texture2D, offset: Vector2, pos: Vector2, s: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.offset = offset
	sprite.position = pos
	sprite.scale = Vector2(s, s)
	rock.add_child(sprite)
	return sprite


# Replaces every Rock* under Obstacles (walls stay) with the given boxes.
func _build_rocks(boxes: Array, color: Color = Color.WHITE) -> void:
	fade_sprites.clear()
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


# Stage 1 itself (not the town or the dungeon): loot.gd and chest.gd show the
# Stage 1 regen fiber art and name for the shared heal drop here.
func is_stage_one() -> bool:
	return stage == 1 and not in_hub and not endless_mode


func _stage_name() -> String:
	return STAGE_NAMES[(stage - 1) % STAGE_NAMES.size()]


# "1-2" inside Stage 1, else just the stage number.
func _stage_number() -> String:
	return STAGE1_AREA_NAMES[area - 1] if stage == 1 else str(stage)


func _area_count() -> int:
	return STAGE1_AREAS.size() if stage == 1 else 1


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
	if enemy.name == "Boss":
		_boss_falls()
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
		kill_label.text = "%s %s   Enemies left: %d" % [_stage_name(), _stage_number(), _alive_enemies()] + _luck_hud()


# Clearing a Stage 1 area before the last one gives back this much HP (capped
# at max_hp), a breather on the way to the boss; the gain shows on the banner.
@export var area_clear_heal: int = 20


func _clear_stage() -> void:
	stage_cleared = true
	var exit_label := exit_gate.get_node("Label") as Label
	exit_gate.position = exit_position
	exit_gate.visible = true
	if area < _area_count():
		var next: String = STAGE1_AREA_NAMES[area]
		print("Area %s clear" % _stage_number())
		var banner := "%s Clear!" % _stage_number()
		var before: int = player.hp
		if player.heal(area_clear_heal):
			banner += "   +%d HP" % (player.hp - before)
		_show_banner(banner, Color(1, 1, 1, 1), clear_banner_time)
		kill_label.text = "%s %s   Clear! On to %s on the right ->" % [_stage_name(), _stage_number(), next]
		exit_label.text = next
		return
	exit_label.text = TOWN_NAME.to_upper()
	var hits: int = player.hits_taken
	var s_hits := stage1_grade_s_hits if stage == 1 else grade_s_hits
	var a_hits := stage1_grade_a_hits if stage == 1 else grade_a_hits
	var grade := "S" if hits <= s_hits else ("A" if hits <= a_hits else "B")
	var best := _save_best_grade(grade)
	var cfg := ConfigFile.new()
	cfg.load(player.SAVE_PATH)
	ending_pending = stage == STAGES.size() and cfg.get_value("progress", "unlocked", 1) <= STAGES.size()
	_save_unlock(stage + 1)
	if grade == "S":
		player.drop_luck = mini(player.drop_luck + 1, player.max_drop_luck)
	print("Stage %d clear: grade %s (%d hits), best %s, drop luck %d" % [stage, grade, hits, best, player.drop_luck])
	var text := "%s Clear!\nGrade %s  (%d hits)   Best %s" % [_stage_name(), grade, hits, best]
	if player.drop_luck > 0:
		text += "\nChests: " + _luck_text()
	_show_banner(text, GRADE_COLORS[grade], clear_banner_time)
	kill_label.text = "%s   Clear! Back to %s on the right ->" % [_stage_name(), TOWN_NAME] + _luck_hud()
	_spawn_chests(grade)


func _spawn_chests(grade: String) -> void:
	# A weapon (_weapon_offer) and the armor; each rolls its own rarity, so even
	# worn gear can come back better. An ichor drop if the pool runs short.
	var pool: Array = [_weapon_offer(), ["armor", 1]]
	pool.shuffle()
	var count := 1 if grade == "B" else 2
	var contents: Array = []
	for i in count:
		contents.append(pool[i] if i < pool.size() else ["heal", 1])
	var special: bool = grade == "S" and randf() < s_special_chance
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


# A chest weapon: the next tier while there is one, else another roll of the
# top tier (rarity and bonus roll in chest.gd, so it can still beat the worn one).
func _weapon_offer() -> Array:
	return ["weapon", mini(player.weapon_tier + 1, player.weapon_names.size())]


# Stage 1 hidden cache: one chest tucked behind the watchtower (the tower fades
# when the Player walks behind it), there from the start of every visit. It
# holds one upgrade (a weapon, armor or ring roll). Chests sit below the World, so the tower hides it.
@export var hidden_cache_position: Vector2 = Vector2(1070, 790)
# 1-2 and 1-3 hide one more each, behind the north side of that area's rock
# pillar (see STAGE1_AREA_ROCKS): [position, holds an upgrade]. 1-2's is only a
# heal; 1-3's rolls an upgrade like 1-1's.
const AREA_CACHES := {2: [Vector2(1100, 100), false], 3: [Vector2(1010, 360), true]}


func _spawn_hidden_cache(at: Vector2 = hidden_cache_position, upgrade: bool = true) -> void:
	var pool: Array = []
	if upgrade:
		pool = [_weapon_offer(), ["armor", 1], ["ring", 1]]
	var content: Array = pool.pick_random() if not pool.is_empty() else ["heal", 1]
	var chest := chest_scene.instantiate()
	chest.name = "HiddenCache"
	chest.set_meta("hidden_cache", true)
	chest.kind = content[0]
	chest.tier = content[1]
	chest.position = at
	add_child(chest)
	move_child(chest, world.get_index())
	print("Hidden cache: %s" % [content])


# Pick one: the other chests vanish empty (the hidden cache isn't one of them).
func _on_chest_opened(opened_chest: Node) -> void:
	for child in get_children():
		if child.get_script() == CHEST_SCRIPT and child != opened_chest and not child.is_open and not child.has_meta("hidden_cache"):
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
func _move_on(target: int, next_area: int = 1) -> void:
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
	player.attack_blocked = false
	for gate in hub_gates:
		gate.visible = false
	if blacksmith != null:
		blacksmith.visible = false
	if target == 0:
		_enter_hub()
	elif target > STAGES.size():
		_enter_dungeon()
	else:
		stage = target
		area = next_area
		_spawn_stage()
	_update_kill_label()
	tween = create_tween()
	tween.tween_property(fade, "color:a", 0.0, fade_time)
	await tween.finished
	moving_on = false


# Full-screen card over everything; the Player stands still under it (physics
# off, as on death) until X or Enter. The ending then fades back to town; the
# New Game intro just lets the Player walk in town.
func _show_ending() -> void:
	ending_pending = false
	_show_card(ENDING_TEXT, true)
	print("Ending")


func _show_card(text: String, to_town: bool) -> void:
	card_to_town = to_town
	card_lock_left = card_lock_time
	# Keeps the pause menu and inventory shut; _move_on or _close_card clears it.
	moving_on = true
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	card = CanvasLayer.new()
	card.name = "Card"
	card.layer = 20
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.02, 0.03, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(bg)
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.text = text
	card.add_child(label)
	bg.modulate.a = 0.0
	label.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(bg, "modulate:a", 1.0, 0.6)
	tween.tween_property(label, "modulate:a", 1.0, 0.8)
	add_child(card)


func _close_card() -> void:
	card.queue_free()
	card = null
	player.set_physics_process(true)
	if card_to_town:
		_move_on(0)
	else:
		moving_on = false


# Pause menu "Return to Town" from a stage or the dungeon: drops what is left
# there (enemies, shots in the air, dungeon loop) and fades back to town.
# Gear, pet and saved progress stay as they are.
func return_to_town() -> void:
	# Leaving the first Stage 3 clear from the pause menu still shows the ending.
	if ending_pending:
		_show_ending()
		return
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
	player.drop_luck = 0
	kills = 0
	respawn_left = respawn_delay
	_build_rocks(DUNGEON_ROCKS, DUNGEON_ROCK_COLOR)
	_dress_heaps(STAGE_HEAPS[2])
	_set_floor(DUNGEON_FLOOR_COLOR, WOUND_FLOOR_TEX)
	_show_ground(false)
	_show_backdrop(STAGE_EDGE_LOOKS.size())
	print("Dungeon")
	_show_banner(DUNGEON_NAME)


func _physics_process(delta: float) -> void:
	if card != null:
		card_lock_left -= delta
		if card_lock_left <= 0.0 and Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("ui_accept"):
			_close_card()
		return
	_update_prop_fade()
	_update_boss_bar()
	if player.get("is_dead") == true:
		return
	if not endless_mode:
		if moving_on:
			return
		if in_hub:
			player.attack_blocked = _near_blacksmith()
			if player.attack_blocked and Input.is_action_just_pressed("attack"):
				player.cycle_forge_choice()
			if _near_blacksmith() and Input.is_action_just_pressed("interact"):
				player.forge_next()
			_update_blacksmith_label()
			for i in hub_gates.size():
				if i + 1 <= unlocked and player.position.distance_to(hub_gates[i].position) <= exit_radius:
					_move_on(i + 1)
					return
		elif stage_cleared and player.position.distance_to(exit_position) <= exit_radius:
			if area < _area_count():
				_move_on(stage, area + 1)
			elif ending_pending:
				_show_ending()
			else:
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


# Tweens each prop to prop_fade_alpha while it covers the Player or an enemy,
# back to opaque once they step out. The wanted state is kept as meta so a
# tween only starts when it changes (and replaces any still running).
func _update_prop_fade() -> void:
	var chars: Array[Node2D] = [player]
	for e in enemies.get_children():
		chars.append(e as Node2D)
	for sprite in fade_sprites:
		if not is_instance_valid(sprite) or not sprite.is_inside_tree():
			continue
		var rect := sprite.get_global_transform() * sprite.get_rect()
		var base_y := (sprite.get_parent() as Node2D).global_position.y
		var faded := false
		for c in chars:
			if (sprite.z_index > 0 or c.global_position.y < base_y) and rect.intersects(Rect2(c.global_position + CHAR_BODY_RECT.position, CHAR_BODY_RECT.size)):
				faded = true
				break
		if sprite.get_meta("faded", false) == faded:
			continue
		sprite.set_meta("faded", faded)
		var target: CanvasItem = sprite.get_meta("fade_node", sprite)
		if target.has_meta("fade_tween"):
			(target.get_meta("fade_tween") as Tween).kill()
		var tween := target.create_tween()
		target.set_meta("fade_tween", tween)
		tween.tween_property(target, "modulate:a", prop_fade_alpha if faded else 1.0, prop_fade_time)


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
	else:
		enemy.sprite_sheet = HUSK_CRAWLER_TEX
	enemies.add_child(enemy)


# Stage 1 camp leader: a bigger, tougher Husk Crawler that also leaps at the
# Player from mid range (enemy.gd leap_*). Same skin lineage drops.
@export var leader_hp: int = 70
@export var leader_damage: int = 12
@export var leader_leap_distance: float = 130.0
@export var leader_sprite_scale: float = 1.35
@export var leader_drop_chance: float = 0.6


# Stage 1 boss: Husk Matron, a huge clawed husk (art/stage1/enemies/
# s1_boss_husk_matron.png: 15 frames of 248x177, feet at 98,175, facing right;
# 0-3 idle, 4-7 walk, 8-11 claw raised, 12-13 slam, 14 recover). Its
# swings are bigger (size_scale) and can't be stopped (super_armor), it barely
# gets pushed, and it leaps from further away than the leader. Comes for the
# Player from the start. Its HP shows on the boss bar.
@export var boss_name: String = "Husk Matron"
@export var boss_hp: int = 320
@export var boss_damage: int = 15
@export var boss_size_scale: float = 1.9


func _make_boss(enemy: Node) -> void:
	enemy.name = "Boss"
	enemy.max_hp = boss_hp
	enemy.attack_damage = boss_damage
	enemy.sprite_sheet = BOSS_TEX
	enemy.sprite_frame_size = Vector2(248, 177)
	enemy.sprite_origin = Vector2(98, 175)
	enemy.idle_frames = PackedInt32Array([0, 1, 2, 3])
	enemy.idle_fps = 5.0
	enemy.walk_frames = PackedInt32Array([4, 5, 6, 7])
	enemy.walk_fps = 7.0
	enemy.startup_frames = PackedInt32Array([8, 9, 10, 11])
	enemy.active_frames = PackedInt32Array([12, 13])
	enemy.recovery_frames = PackedInt32Array([14])
	enemy.windup_lean = 0.0
	enemy.lunge_lean = 0.0
	enemy.size_scale = boss_size_scale
	enemy.super_armor = true
	enemy.knockback_distance = 6.0
	enemy.move_speed = 75.0
	enemy.detect_range = INF
	enemy.lose_range = INF
	enemy.stop_distance = 85.0
	enemy.attack_range = 100.0
	enemy.vertical_tolerance = 30.0
	enemy.attack_startup = 0.5
	enemy.attack_cooldown = 1.4
	enemy.leap_distance = 200.0
	enemy.leap_min = 140.0
	enemy.leap_range = 300.0
	enemy.leap_startup = 0.75
	enemy.leap_cooldown = 4.0
	enemy.drop_chance = 0.0
	enemy.get_node("HpLabel").visible = false


# Boss bar along the bottom of the screen: name, then HP as a red fill. Built
# in code under the Hud, shown only while a boss is alive.
const BOSS_BAR_RECT := Rect2(340, 664, 600, 16)
var boss_bar: Control
var boss_fill: ColorRect


func _build_boss_bar() -> void:
	boss_bar = Control.new()
	boss_bar.name = "BossBar"
	boss_bar.position = BOSS_BAR_RECT.position
	boss_bar.visible = false
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := ColorRect.new()
	back.size = BOSS_BAR_RECT.size
	back.color = Color(0, 0, 0, 0.6)
	boss_bar.add_child(back)
	boss_fill = ColorRect.new()
	boss_fill.position = Vector2(2, 2)
	boss_fill.size = BOSS_BAR_RECT.size - Vector2(4, 4)
	boss_fill.color = Color(0.85, 0.15, 0.15, 1)
	boss_bar.add_child(boss_fill)
	var label := Label.new()
	label.text = boss_name
	label.position = Vector2(0, -30)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	boss_bar.add_child(label)
	kill_label.get_parent().add_child(boss_bar)
	# Under the fade so it fades with the screen.
	kill_label.get_parent().move_child(boss_bar, fade.get_index())


func _update_boss_bar() -> void:
	var boss: Node = enemies.get_node_or_null("Boss")
	var show: bool = boss != null and not boss.is_queued_for_deletion() and boss.hp > 0
	boss_bar.visible = show
	if show:
		boss_fill.size.x = (BOSS_BAR_RECT.size.x - 4) * float(boss.hp) / boss.max_hp
		while brood_called < boss_brood_at.size() and boss.hp <= boss.max_hp * boss_brood_at[brood_called]:
			brood_called += 1
			_call_brood(boss)


# Boss kill finisher: once the killing blow's hitstop is over, the game runs
# at boss_kill_time_scale for boss_kill_slowmo s (real time) with a big screen
# shake, so the kill lands. Pausing holds the timer.
@export var boss_kill_time_scale: float = 0.3
@export var boss_kill_slowmo: float = 0.9
@export var boss_kill_shake: float = 6.0


func _boss_falls() -> void:
	while player.in_hitstop:
		await get_tree().process_frame
	Engine.time_scale = boss_kill_time_scale
	player._shake(boss_kill_shake)
	print("Boss falls: slow motion")
	await get_tree().create_timer(boss_kill_slowmo, false, false, true).timeout
	# A hitstop running now sets the scale back itself when it ends.
	if Engine.time_scale == boss_kill_time_scale:
		Engine.time_scale = 1.0


# Brood: each time the boss drops below one of boss_brood_at (fractions of its
# HP) it calls boss_brood_count Husk Crawlers out of the field edges, from the
# BROOD_SPOTS nearest to it (all clear of the Stage 1 rocks and props). They
# come straight for the Player; the stage clears once they are dead too.
@export var boss_brood_at: PackedFloat32Array = PackedFloat32Array([0.66, 0.33])
@export var boss_brood_count: int = 2
@export var brood_color: Color = Color(1, 0.75, 0.55, 1)
const BROOD_SPOTS := [Vector2(800, 120), Vector2(800, 820), Vector2(1500, 150), Vector2(1500, 780), Vector2(200, 150), Vector2(200, 800)]
var brood_called: int = 0


func _call_brood(boss: Node2D) -> void:
	var spots := BROOD_SPOTS.duplicate()
	spots.sort_custom(func(a, b): return a.distance_to(boss.position) < b.distance_to(boss.position))
	for i in mini(boss_brood_count, spots.size()):
		var enemy := enemy_scene.instantiate()
		enemy.position = spots[i]
		enemy.sprite_sheet = HUSK_CRAWLER_TEX
		enemy.detect_range = INF
		enemy.lose_range = INF
		enemies.add_child(enemy)
	print("%s calls %d brood" % [boss_name, boss_brood_count])
	_show_banner("%s calls her brood!" % boss_name, brood_color)
	_update_kill_label()


func _make_leader(enemy: Node) -> void:
	enemy.name = "Leader"
	enemy.max_hp = leader_hp
	enemy.attack_damage = leader_damage
	enemy.leap_distance = leader_leap_distance
	enemy.drop_chance = leader_drop_chance
	enemy.sprite_sheet = HUSK_CRAWLER_TEX
	enemy.sprite_scale = leader_sprite_scale


# Stage 1 ranged enemy, the Scab Flinger: a smaller, pale-yellow Husk Crawler
# that keeps its distance and flings scabs along the Player's line (the
# enemy.gd is_ranged shot, dodged by a roll or a step off the line, parried by
# a swing). Skin lineage, so it drops like a Husk Crawler. Placeholder look
# (recoloured crawler strip) until its own art.
@export var flinger_hp: int = 24
@export var flinger_move_speed: float = 80.0
@export var flinger_shot_damage: int = 7
@export var flinger_sprite_scale: float = 0.85
@export var flinger_sprite_color: Color = Color(1.0, 0.95, 0.55, 1)
@export var flinger_shot_color: Color = Color(0.9, 0.75, 0.35, 0.6)


func _make_flinger(enemy: Node) -> void:
	enemy.name = "Flinger"
	enemy.max_hp = flinger_hp
	enemy.move_speed = flinger_move_speed
	enemy.is_ranged = true
	enemy.shot_damage = flinger_shot_damage
	enemy.shot_color = flinger_shot_color
	enemy.sprite_sheet = HUSK_CRAWLER_TEX
	enemy.sprite_scale = flinger_sprite_scale
	enemy.sprite_color = flinger_sprite_color


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
	enemy.sprite_sheet = RIB_CRAWLER_TEX
	enemy.sprite_scale = tough_body_scale
	enemy.sprite_shard_color = tough_color


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
	enemy.sprite_sheet = VEIN_SPITTER_TEX
	enemy.sprite_scale = ranged_body_scale
	enemy.sprite_shard_color = Color(0.55, 0.12, 0.2, 1)
