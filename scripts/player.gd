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
# Ichor drop (heal) pickup (enemy.heal_drop_chance): restores heal_amount HP, capped at
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
# Sword (any enemy), tier 2 Bone Blade (tough enemies only). Walking over a drop
# equips it for the rest of the run if it beats the current one: every combo hit
# deals that tier's bonus more and the swing arc takes its color. Bonuses stay
# small so one item is never a big jump (each tier shaves about one hit):
# enemy 30 HP takes 3 hits unarmed / Iron / Steel; tough 100 HP: 9 / 8 / 7.
# R restart reloads the scene, so it starts unarmed again.
@export var weapon_names: Array[String] = ["Callus Blade", "Bone Blade"]
@export var weapon_damage_bonus: Array[int] = [2, 4]
@export var weapon_arc_color: Array[Color] = [Color(0.55, 0.95, 1, 1), Color(0.8, 0.5, 1, 1)]
# Weapon rarity (Dungeon Quest style): every weapon drop rolls a rarity, and the
# bonus rolls in that rarity's small range around the tier's weapon_damage_bonus
# (base + rarity_bonus_min..max, at least 1): Callus Blade Common +1~2, Magic
# +2~3, Rare +3~4, Legendary +4; Bone Blade +3~4 / +4~5 / +5~6 / +6. A drop is
# worn only if its bonus beats the current one, so a good Callus Blade can beat
# a poor Bone Blade. Rarity shows as the drop's glow, name and the HUD color.
const RARITY_NAMES: Array[String] = ["Common", "Magic", "Rare", "Legendary"]
@export var rarity_colors: Array[Color] = [Color(0.92, 0.92, 0.92, 1), Color(0.4, 0.65, 1, 1), Color(1, 0.88, 0.25, 1), Color(1, 0.55, 0.15, 1)]
@export var rarity_weights: Array[int] = [55, 30, 12, 3]
# Repeat-farming luck (set by test_map.gd for each stage run): every level moves
# luck_weight_shift from Common to the higher rarities, so drops, chests and
# caches all roll a bit better. Weights 55/30/12/3 at 0, 47/34/15/4 at 1,
# 39/38/18/5 at 2, 31/42/21/6 at 3 (max_drop_luck).
@export var luck_weight_shift: Array[int] = [-8, 4, 3, 1]
@export var max_drop_luck: int = 3
var drop_luck: int = 0
@export var rarity_bonus_min: Array[int] = [-1, 0, 1, 2]
@export var rarity_bonus_max: Array[int] = [0, 1, 2, 2]
# Second slot: armor any enemy can rarely drop (see enemy.armor_drop_chance).
# Once worn, every enemy hit deals armor_value less (10 -> 8 at the base 2),
# about as small a step as one weapon tier. Kept across R (SAVE_PATH).
# Armor rolls a rarity too, in a tighter range so it never gets big: base
# armor_damage_reduction + armor_bonus_min..max = Common 1~2, Magic 2, Rare
# 2~3, Legendary 3~4. Worn only if its value beats the current one.
@export var armor_name: String = "Godhide Armor"
@export var armor_damage_reduction: int = 2
@export var armor_bonus_min: Array[int] = [-1, 0, 0, 1]
@export var armor_bonus_max: Array[int] = [0, 0, 1, 2]
# Third slot: a ring any enemy can rarely drop (see enemy.ring_drop_chance).
# Once worn, rolling through an enemy grazes it for ring_value (once per
# enemy per roll, no push, so it doesn't set off a normal enemy's counter).
# Small on its own; it mostly turns a dodge into a little damage. Kept across R (SAVE_PATH).
# Rolls like a weapon around ring_roll_damage (rarity_bonus_min..max):
# Common 2~3, Magic 3~4, Rare 4~5, Legendary 5.
@export var ring_name: String = "Nerve Ring"
@export var ring_roll_damage: int = 3
# Auto-salvage (Dungeon Quest style): a weapon, armor or ring drop no better than
# what's worn breaks down into Skin Crystal on pickup, salvage_amounts[rarity]
# of it (Common 1, Magic 2, Rare 4, Legendary 8). A "+N Skin Crystal" popup
# rises above the Player in the drop's rarity color, and the HUD keeps the
# count. Saved in SAVE_PATH [materials]; the town blacksmith spends it (forge_costs).
@export var material_name: String = "Skin Crystal"
@export var salvage_amounts: Array[int] = [1, 2, 4, 8]
@export var salvage_popup_time: float = 0.9
@export var salvage_popup_rise: float = 36.0
# Town blacksmith (test_map.gd): forging a worn piece costs forge_costs[level]
# Skin Crystal for its next level, up to forge_costs.size() (+3). Each level adds
# 1 to that piece's value: weapon +1 basic-attack damage, armor 1 less damage
# taken, ring +1 graze damage. Armor stops at armor_forge_max (+2) so it stays
# small. One press forges the worn piece with the lowest level (ties: weapon,
# armor, ring; see forge_target), unless X at the anvil picked another piece
# (cycle_forge_choice). The level belongs to that piece: a drop only
# replaces it if its value beats value + forge, and the new piece starts at 0.
# Saved in SAVE_PATH [gear] weapon_forge / armor_forge / ring_forge (older saves load 0).
@export var forge_costs: Array[int] = [5, 10, 20]
@export var armor_forge_max: int = 2
# Bag (I opens it, inventory.gd): a weapon, armor or ring drop no better than
# what's worn goes into the bag instead of breaking down, so it can be worn or
# salvaged by hand later. Only once bag_size items are in it do such drops
# auto-salvage as above. Saved in SAVE_PATH [bag] items (older saves load empty).
# A bag item can be locked (inventory L, toggle_bag_lock): salvage_from_bag and
# salvage_worse_from_bag skip it. Saved as the item's "locked" (older saves: unlocked).
@export var bag_size: int = 12
# Once nothing worn can be forged, the blacksmith's C buys bag_grow_slots more
# bag slots for bag_grow_costs[bag_grows] Skin Crystal, once per cost (12 -> 24).
# bag_grows is saved in SAVE_PATH [bag] grows (older saves load 0).
@export var bag_grow_slots: int = 4
@export var bag_grow_costs: Array[int] = [20, 30, 40]
# A gear drop shows how it compares to what's worn (compare_text: "+2 better",
# "-1 worse", "Same", "New") above its name on the ground and in the pickup
# popup, in these colors.
@export var compare_better_color: Color = Color(0.45, 1, 0.45, 1)
@export var compare_worse_color: Color = Color(1, 0.45, 0.4, 1)
@export var compare_same_color: Color = Color(0.75, 0.75, 0.75, 1)
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
# (loot.gd calls it; the ichor drop plays it higher).
# Enemy wind-ups ping a short warning (enemy.gd calls play_warn_sound as the
# telegraph starts): a rising beep for a normal swing, a sharp high chirp for
# a magenta counter, a low growl for the tough variant, a falling whistle for
# the ranged variant's shot. One shared player, so
# several enemies winding up together restart one sound instead of stacking.
# Volumes live on the *Sound nodes in player.tscn.
@export var combo_hit_pitch: Array[float] = [1.0, 1.12, 0.8]
# A basic attack swing that overlaps an enemy shot destroys it (projectile.gd
# parry) and plays the hit sound pitched up, with no hitstop or shake.
@export var parry_pitch: float = 1.6
# Set effect, on only while any weapon AND the armor are worn: the 3rd combo hit
# also releases a shockwave ring around the Player's feet. Every enemy inside
# takes shockwave_damage and is pushed away (left/right) with
# shockwave_knockback_scale. The ring is an ellipse (y squashed by
# shockwave_y_scale) to match the top-down 2.5D floor; hit test uses the same shape.
# With the ring worn too (full set, 3 pieces) the shockwave grows to the
# full_set_* values: wider, harder and a hotter color.
@export var gear_set_name: String = "Hunter's Set"
@export var shockwave_radius: float = 120.0
@export var shockwave_y_scale: float = 0.5
@export var shockwave_damage: int = 5
@export var shockwave_knockback_scale: float = 1.5
@export var shockwave_duration: float = 0.25
@export var shockwave_color: Color = Color(1, 0.95, 0.6, 1)
@export var full_set_radius: float = 170.0
@export var full_set_damage: int = 10
@export var full_set_color: Color = Color(1, 0.55, 0.2, 1)
# Legendary weapon effect: with a Legendary weapon worn, the 3rd combo hit also
# sends a small slash wave (projectile.tscn, pierce on) straight ahead along the
# facing. It cuts every enemy on its line once for slash_wave_damage (weapon
# bonus doesn't apply, no push) and stops at walls and rocks after
# slash_wave_travel px. A small reach extension, not a second finisher.
@export var slash_wave_damage: int = 6
@export var slash_wave_speed: float = 420.0
@export var slash_wave_travel: float = 240.0
@export var slash_wave_color: Color = Color(1, 0.8, 0.25, 0.75)
@export var slash_wave_core_color: Color = Color(1, 0.97, 0.8, 1)
@export var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")
# Pets, one entry per kind (pet_kind 1, 2, 3). Each follows the Player, bites
# nearby enemies for a little damage (see pet.gd) and lends a small form of its
# monster's passive:
# 1 Marrow Cub (tough enemies, rarely, test_map tough_pet_drop_chance): while the
#   Player is attacking, enemy hits don't push the Player back (damage and the
#   hit freeze still apply).
# 2 Scab Pup (normal enemies, rarely, enemy.pet_drop_chance): bites back - when
#   an enemy hits the Player, the pup bites right away (its bite cooldown is
#   skipped), like the normal enemy's counter.
# 3 Clot Imp (ranged enemies, rarely, test_map ranged_pet_drop_chance): keeps
#   its distance like its monster - instead of dashing in to bite, it spits a
#   small shot (projectile.tscn) at the nearest enemy within a longer range.
# The two bite differently so they read apart: the Cub chomps rarely but harder
# with a big pop, the Pup nibbles often for less, the Imp spits from afar (all
# about 2 damage a second).
# The Pup is rose, not the normal enemy's red, so it doesn't read as an enemy.
# One pet at a time: walking over a different pet swaps to it, and every pet
# obtained is kept in owned_pets (switch in the I inventory). Kept across R (SAVE_PATH).
@export var pet_names: Array[String] = ["Marrow Cub", "Scab Pup", "Clot Imp"]
@export var pet_colors: Array[Color] = [Color(0.96, 0.8, 0.62, 1), Color(1, 0.6, 0.72, 1), Color(0.75, 0.62, 1, 1)]
@export var pet_bite_damage: Array[int] = [5, 2, 4]
@export var pet_bite_cooldown: Array[float] = [2.5, 0.9, 2.0]
# Size the pet swells to on a bite (pet.gd bite_pop).
@export var pet_bite_pop: Array[float] = [1.6, 1.15, 1.3]
@export var pet_passive_text: Array[String] = ["no push while attacking", "bites back when you're hit", "keeps its distance"]
# Painted look per pet (pet.gd sprite_sheet); null keeps the placeholder shape.
# Only the Scab Pup (Stage 1 skin lineage) has one so far.
@export var pet_sprite_sheets: Array[Texture2D] = [null, preload("res://art/stage1/pets/s1_scab_pup.png"), null]
# Player art: a strip of right-facing frames sprite_frame_size each, origin
# at the feet centre (sprite_origin). Frames 0-1 idle, 2-5 walk, 6-8 basic
# attack startup / active / recovery (one pose per AttackPhase). It replaces the
# placeholder Body, which stays hidden but keeps holding the flash colour that
# tints the sprite. Left is the existing Visual.scale.x flip. Dash, whirl
# and hurt show idle frame 0 (no art for them yet). null keeps the box.
@export var sprite_sheet: Texture2D = preload("res://art/player/player.png")
@export var sprite_frame_size: Vector2 = Vector2(96, 72)
@export var sprite_origin: Vector2 = Vector2(48, 68)
@export var idle_fps: float = 2.0
@export var walk_fps: float = 10.0
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
# W skill, Whirl Slash: the Player plants its feet and spins for whirl_duration,
# cutting every enemy around it (once each per spin) for whirl_damage and
# pushing each one away left/right. Where Q cuts a line ahead, W clears the
# ring around you when surrounded. No movement, roll or attack while spinning,
# not invincible, own cooldown. Hit area is an ellipse (y squashed by
# shockwave_y_scale, like the set shockwave) of whirl_radius at the feet.
# Placeholder look: the Player flips left/right every whirl_flip_interval s
# (left/right art only) inside a fading ring. Weapon bonus doesn't apply.
@export var whirl_duration: float = 0.3
@export var whirl_radius: float = 90.0
@export var whirl_damage: int = 8
@export var whirl_knockback_scale: float = 1.5
@export var whirl_cooldown: float = 4.0
@export var whirl_hitstop: float = 0.05
@export var whirl_hit_pitch: float = 1.15
@export var whirl_flip_interval: float = 0.05
@export var whirl_color: Color = Color(0.6, 1, 0.8, 1)
@export var shake_whirl: float = 2.5
# E skill, Sinew Hook: the Player stands still for hook_duration and lashes a
# hook straight out along the facing (left/right only). Every enemy whose
# hurtbox is inside the hook_range x hook_height box takes hook_damage and is
# yanked toward the Player, landing hook_stop px in front (its own knockback,
# reversed, so walls and rocks still stop it). Enemies mid-swing with super
# armor (counters, leaps, tough ones) take the damage but stay put. It fills
# the gap Q and W leave: reaching enemies at range and gathering a pack for W.
# Placeholder look: a sinew-colored line that shoots out and snaps back.
@export var hook_range: float = 260.0
@export var hook_height: float = 56.0
@export var hook_damage: int = 5
@export var hook_stop: float = 50.0
@export var hook_duration: float = 0.25
@export var hook_cooldown: float = 6.0
@export var hook_hitstop: float = 0.04
@export var hook_hit_pitch: float = 0.75
@export var hook_color: Color = Color(0.95, 0.55, 0.5, 1)
@export var shake_hook: float = 2.0
# Parry (Z): optional. Facing an enemy, a press opens parry_window s of guard;
# a melee swing or leap that would land on the Player in that time does no
# damage and the enemy is staggered (enemy.gd parried(), stagger_duration),
# an opening for a free combo. The guard is rooted: no moving, attacking or
# rolling. A whiff stays rooted parry_recovery s more and parry_cooldown runs
# from the press; a parry frees the Player at once and resets the cooldown.
# Ranged shots aren't Z's job: an X swing already swats them (parry_pitch).
# Placeholder look: a pale blue tint and a guard bar in front while open,
# grey during the whiff recovery.
@export var parry_window: float = 0.2
@export var parry_recovery: float = 0.25
@export var parry_cooldown: float = 0.8
@export var parry_hitstop: float = 0.12
@export var parry_color: Color = Color(0.6, 0.85, 1, 1)
@export var parry_whiff_color: Color = Color(0.6, 0.6, 0.6, 1)
@export var shake_parry: float = 5.0
# A roll passes through enemy bodies (physics layer "enemy_body"); walls still
# block it. Both ways are turned off: the Player ignores enemies, and its body
# leaves "world" so chasing enemies don't get shoved ahead of the roll. If the
# roll ends inside an enemy, this lasts until the Player has walked out, so it
# never gets stuck in or shoved out of one.
const WORLD_LAYER := 1
# Gear and pet are permanent farming progress: written here on every pickup and
# read back on _ready, so dying + R (scene reload) keeps them. One ConfigFile,
# one section per kind of progress ("gear" now; stage grades can get their own
# section later). Delete the file to start fresh.
const SAVE_PATH := "user://save.cfg"
# Hits that got through (rolls and other i-frames don't count) since test_map.gd last reset it.
var hits_taken: int = 0
const ENEMY_BODY_LAYER := 4

enum AttackPhase { NONE, STARTUP, ACTIVE, RECOVERY }

# 1 = right, -1 = left. Art faces right by default; left is a horizontal flip.
var facing: int = 1
var sprite: Sprite2D
var sprite_anim_time: float = 0.0

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
# Rarity (RARITY_NAMES index) and rolled damage bonus of the equipped weapon.
var weapon_rarity: int = 0
var weapon_bonus: int = 0
# Blacksmith level of the equipped weapon (0..forge_costs.size()), +1 damage each.
var weapon_forge: int = 0
var has_armor: bool = false
var has_ring: bool = false
# Rarity and rolled value of the worn armor (damage taken less) and ring (graze damage).
var armor_rarity: int = 0
var armor_value: int = 0
var ring_rarity: int = 0
var ring_value: int = 0
# Blacksmith levels of the worn armor and ring (see forge_costs).
var armor_forge: int = 0
var ring_forge: int = 0
# Piece picked at the blacksmith with X (cycle_forge_choice); "" = lowest level
# first. Ignored once that piece is gone or maxed. Not saved.
var forge_choice: String = ""
# Set by test_map.gd each frame while standing at the blacksmith, where X picks
# the piece to forge instead of attacking.
var attack_blocked: bool = false
# Skin Crystal from auto-salvage (see salvage_amounts).
var materials: int = 0
# Bag slots bought at the blacksmith (see bag_grow_costs).
var bag_grows: int = 0
# Bag items, oldest first: {"kind": "weapon"/"armor"/"ring", "tier", "rarity", "value", "forge"}.
var bag: Array[Dictionary] = []
# Enemies already grazed by the current roll (Nerve Ring).
var roll_hit_targets: Array[Node] = []
var shockwave_time_left: float = 0.0
var pet: Node2D = null
# 0 = no pet, otherwise the index+1 of the pet above.
var pet_kind: int = 0
# Every pet kind obtained so far, in pickup order (one of each kind).
var owned_pets: Array[int] = []
var shake_strength: float = 0.0
var shake_left: float = 0.0
var dash_time_left: float = 0.0
var dash_cooldown_left: float = 0.0
var dash_dir: int = 1
# Enemies already cut by the current dash.
var dash_hit_targets: Array[Node] = []
var dash_shape := RectangleShape2D.new()
var whirl_time_left: float = 0.0
var whirl_cooldown_left: float = 0.0
# Facing when the spin started, restored when it ends.
var whirl_facing: int = 1
var whirl_hit_targets: Array[Node] = []
var hook_time_left: float = 0.0
var hook_cooldown_left: float = 0.0
var hook_dir: int = 1
var hook_shape := RectangleShape2D.new()
var hook_line: Line2D
# Window + whiff recovery left (rooted while > 0); the guard is open while > parry_recovery.
var parry_time_left: float = 0.0
var parry_cooldown_left: float = 0.0
var parry_bar: Polygon2D
var parries: int = 0

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
# Gear/pet/skill text lines, hidden: the inventory (I) shows the details.
# Still kept up to date because the inventory and tests read them.
@onready var weapon_label: Label = $Hud/WeaponLabel
@onready var armor_label: Label = $Hud/ArmorLabel
@onready var ring_label: Label = $Hud/RingLabel
@onready var set_label: Label = $Hud/SetLabel
@onready var pet_label: Label = $Hud/PetLabel
@onready var skill_label: Label = $Hud/SkillLabel
@onready var material_label: Label = $Hud/MaterialLabel
# Top-left status HUD, built in _build_status_hud: HP bar, Q/W/E cooldown boxes, active pet.
const HUD_HP_RECT := Rect2(16, 14, 300, 24)
const HUD_ROW_Y := 46.0
const HUD_SKILL_BOX := 34.0
const HUD_PET_X := 700.0
var hp_fill: ColorRect
var hp_text: Label
# White strip behind hp_fill showing the HP just lost: holds for
# hp_trail_delay, then shrinks to the fill at hp_trail_speed px/s.
@export var hp_trail_delay: float = 0.4
@export var hp_trail_speed: float = 240.0
var hp_trail: ColorRect
var hp_trail_wait: float = 0.0
# At or below hp_low_ratio of max HP the fill blinks to hp_low_color.
@export var hp_low_ratio: float = 0.3
@export var hp_blink_period: float = 0.5
const HP_FILL_COLOR := Color(0.82, 0.18, 0.18, 1)
@export var hp_low_color: Color = Color(1, 0.6, 0.55, 1)
var hp_blink_time: float = 0.0
# [shade, key label] per skill, Q, W then E.
var skill_boxes: Array = []
var hud_pet_swatch: ColorRect
var hud_pet_name: Label
# Worn weapon box right of the Q/W/E boxes: rarity-colored frame, weapon icon
# (a colored square for tiers without art), then "Rare +3" in the rarity color.
const HUD_WEAPON_X := 142.0
const CALLUS_BLADE_ICON := preload("res://art/stage1/drops/s1_drop_callus_blade.png")
var hud_weapon_box: ColorRect
var hud_weapon_icon: TextureRect
var hud_weapon_swatch: ColorRect
var hud_weapon_text: Label
# Armor and ring boxes after the weapon text, same frame and rarity colors; the
# text is only the total value ("-3" damage taken, "+4" roll graze).
const HUD_ARMOR_X := 332.0
const HUD_RING_X := 406.0
const ARMOR_ICON := preload("res://art/stage1/drops/s1_drop_husk_shard.png")
const NERVE_RING_ICON := preload("res://art/stage1/drops/s1_drop_nerve_ring.png")
var hud_armor_box: ColorRect
var hud_armor_text: Label
var hud_ring_box: ColorRect
var hud_ring_text: Label
# "Bag full" warning right of the HP bar while the bag holds bag_size items;
# it flashes each time a passed-on drop auto-salvages because of it.
const HUD_BAG_FULL_POS := Vector2(330, 12)
@export var bag_full_color: Color = Color(1, 0.55, 0.2, 1)
@export var bag_full_flash_time: float = 0.5
var hud_bag_full: Label
# Placeholder streak behind the Player while dashing (fades after).
@onready var dash_trail: Polygon2D = $DashTrail
# Placeholder ring for the set shockwave, grows and fades over shockwave_duration.
@onready var shockwave_ring: Line2D = $ShockwaveRing
# Placeholder ring around the feet while whirling.
@onready var whirl_ring: Line2D = $WhirlRing
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
	if sprite_sheet:
		_setup_sprite()
	hp = max_hp
	hp_label.text = str(hp)
	_build_status_hud()
	_update_hp_bar()
	_build_shockwave_ring()
	_build_whirl_ring()
	dash_shape.size = dash_hit_size
	hook_shape.size = Vector2(hook_range, hook_height)
	_build_hook_line()
	_build_parry_bar()
	_update_skill_label()
	_update_material_label()
	# Deferred: equip_pet adds the pet to the map, which is still adding its children now.
	_load_gear.call_deferred()
	hit_sound.stream = _synth_sound(0.07, 220.0, 90.0, 0.6)
	hurt_sound.stream = _synth_sound(0.14, 330.0, 140.0, 0.15)
	roll_sound.stream = _synth_sound(0.18, 600.0, 250.0, 0.85)
	kill_sound.stream = _synth_sound(0.24, 160.0, 45.0, 0.45)
	pickup_sound.stream = _synth_sound(0.12, 660.0, 1320.0, 0.0)
	warn_streams = [
		_synth_sound(0.12, 520.0, 780.0, 0.0),
		_synth_sound(0.10, 1100.0, 1600.0, 0.1),
		_synth_sound(0.22, 140.0, 220.0, 0.3),
		_synth_sound(0.18, 1300.0, 650.0, 0.05),
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


func _build_whirl_ring() -> void:
	var points := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		points.append(Vector2(cos(a), sin(a) * shockwave_y_scale) * whirl_radius)
	whirl_ring.points = points
	whirl_ring.default_color = whirl_color


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

	if whirl_cooldown_left > 0.0:
		whirl_cooldown_left -= delta
		_update_skill_label()

	if hook_cooldown_left > 0.0:
		hook_cooldown_left -= delta
		_update_skill_label()

	if parry_cooldown_left > 0.0:
		parry_cooldown_left -= delta

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

	if whirl_time_left > 0.0:
		# Whirling: rooted, no roll, attack or dash until it ends.
		_update_whirl(delta)
		return

	if hook_time_left > 0.0:
		# Hooking: rooted, no roll, attack or other skill until it ends.
		_update_hook(delta)
		return

	if parry_time_left > 0.0:
		# Guarding or whiffed: rooted, no roll, attack or skill until it ends.
		_update_parry(delta)
		return

	if roll_time_left <= 0.0 and parry_cooldown_left <= 0.0 and hurt_knockback_left <= 0.0 and Input.is_action_just_pressed("parry"):
		_start_parry()
		return

	if roll_time_left <= 0.0 and roll_cooldown_left <= 0.0 and Input.is_action_just_pressed("roll"):
		_start_roll(input)

	if roll_time_left <= 0.0 and dash_cooldown_left <= 0.0 and Input.is_action_just_pressed("skill_q"):
		_start_dash()
		_update_dash(delta)
		return

	if roll_time_left <= 0.0 and whirl_cooldown_left <= 0.0 and Input.is_action_just_pressed("skill_w"):
		_start_whirl()
		_update_whirl(delta)
		return

	if roll_time_left <= 0.0 and hook_cooldown_left <= 0.0 and Input.is_action_just_pressed("skill_e"):
		_start_hook()
		_update_hook(delta)
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
	elif Input.is_action_pressed("attack") and not attack_blocked:
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
		target.take_damage(dash_damage, dash_dir, 1.0, 1)
		landed = true
	# One hitstop per frame, like the combo.
	if landed:
		_start_hitstop(dash_hitstop)
		hit_sound.pitch_scale = dash_hit_pitch
		hit_sound.play()
		_shake(shake_dash)


func _start_whirl() -> void:
	# Like the dash, the whirl cancels any attack in progress.
	if attack_phase != AttackPhase.NONE:
		_cancel_attack()
	whirl_facing = facing
	whirl_time_left = whirl_duration
	whirl_cooldown_left = whirl_cooldown
	hurt_knockback_left = 0.0
	velocity = Vector2.ZERO
	whirl_hit_targets.clear()
	whirl_ring.visible = true
	roll_sound.pitch_scale = 1.8
	roll_sound.play()
	_update_skill_label()


func _update_whirl(delta: float) -> void:
	_whirl_hits()
	whirl_time_left -= delta
	# 0 at start -> 1 at the end: the ring snaps out from 70% and fades.
	var t := clampf(1.0 - whirl_time_left / whirl_duration, 0.0, 1.0)
	whirl_ring.scale = Vector2.ONE * lerpf(0.7, 1.0, minf(t * 3.0, 1.0))
	whirl_ring.modulate.a = 1.0 - t * 0.7
	# Spin read as fast left/right flips (no new art).
	var flips := int((whirl_duration - whirl_time_left) / whirl_flip_interval)
	visual.scale.x = whirl_facing * (1 if flips % 2 == 0 else -1)
	if whirl_time_left <= 0.0:
		_end_whirl()


func _end_whirl() -> void:
	if not whirl_ring.visible:
		return
	whirl_time_left = 0.0
	whirl_ring.visible = false
	facing = whirl_facing
	visual.scale.x = facing


# Every enemy whose feet are inside the ellipse takes whirl_damage once this spin.
func _whirl_hits() -> void:
	var landed := false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy in whirl_hit_targets or enemy.is_queued_for_deletion():
			continue
		var offset: Vector2 = enemy.global_position - global_position
		offset.y /= shockwave_y_scale
		if offset.length() > whirl_radius:
			continue
		whirl_hit_targets.append(enemy)
		print("Whirl Slash hit %s" % enemy.name)
		var dir := whirl_facing if is_zero_approx(offset.x) else int(signf(offset.x))
		enemy.take_damage(whirl_damage, dir, whirl_knockback_scale, 1)
		landed = true
	# One hitstop per frame, like the combo.
	if landed:
		_start_hitstop(whirl_hitstop)
		hit_sound.pitch_scale = whirl_hit_pitch
		hit_sound.play()
		_shake(shake_whirl)


func _build_hook_line() -> void:
	hook_line = Line2D.new()
	hook_line.name = "HookLine"
	hook_line.width = 4.0
	hook_line.default_color = hook_color
	hook_line.points = PackedVector2Array([Vector2(0, -32), Vector2(0, -32)])
	hook_line.visible = false
	add_child(hook_line)


func _start_hook() -> void:
	# Like the dash, the hook cancels any attack in progress.
	if attack_phase != AttackPhase.NONE:
		_cancel_attack()
	hook_dir = facing
	hook_time_left = hook_duration
	hook_cooldown_left = hook_cooldown
	hurt_knockback_left = 0.0
	velocity = Vector2.ZERO
	hook_line.visible = true
	roll_sound.pitch_scale = 0.8
	roll_sound.play()
	_hook_hits()
	_update_skill_label()


func _update_hook(delta: float) -> void:
	hook_time_left -= delta
	# 0 at start -> 1 at the end: the line shoots out in the first 30%, then snaps back.
	var t := clampf(1.0 - hook_time_left / hook_duration, 0.0, 1.0)
	var reach := minf(t / 0.3, 1.0) if t < 0.3 else 1.0 - (t - 0.3) / 0.7
	hook_line.points = PackedVector2Array([Vector2(hook_dir * 14, -32), Vector2(hook_dir * (14 + (hook_range - 14) * reach), -32)])
	if hook_time_left <= 0.0:
		_end_hook()


func _build_parry_bar() -> void:
	parry_bar = Polygon2D.new()
	parry_bar.name = "ParryBar"
	parry_bar.polygon = PackedVector2Array([Vector2(16, -58), Vector2(22, -58), Vector2(22, -6), Vector2(16, -6)])
	parry_bar.color = parry_color
	parry_bar.visible = false
	visual.add_child(parry_bar)


func _start_parry() -> void:
	# Like the skills, the parry cancels any attack in progress.
	if attack_phase != AttackPhase.NONE:
		_cancel_attack()
	parry_time_left = parry_window + parry_recovery
	parry_cooldown_left = parry_cooldown
	velocity = Vector2.ZERO
	visual.modulate = parry_color
	parry_bar.visible = true


func _update_parry(delta: float) -> void:
	parry_time_left -= delta
	if parry_time_left <= 0.0:
		_end_parry()
	elif parry_time_left <= parry_recovery and parry_bar.visible:
		# Window closed with nothing parried: the whiff recovery.
		parry_bar.visible = false
		visual.modulate = parry_whiff_color


func _end_parry() -> void:
	parry_time_left = 0.0
	visual.modulate = Color(1, 1, 1, 1)
	if parry_bar:
		parry_bar.visible = false


func is_parrying() -> bool:
	return parry_time_left > parry_recovery


# Called by an enemy whose melee hit is about to land (enemy.gd _apply_hit).
# True = parried: no damage, and the enemy staggers itself.
func try_parry(attacker: Node2D) -> bool:
	if is_dead or not is_parrying():
		return false
	# Left/right only: the guard covers the side the Player faces.
	var side := 1 if attacker.global_position.x >= global_position.x else -1
	if side != facing:
		return false
	parries += 1
	print("Parry!")
	_end_parry()
	parry_cooldown_left = 0.0
	hit_sound.pitch_scale = 1.8
	hit_sound.play()
	_spawn_graze_spark(global_position + Vector2(facing * 22, -32))
	_spawn_salvage_popup("PARRY!", parry_color)
	_shake(shake_parry)
	_start_hitstop(parry_hitstop)
	return true


func _end_hook() -> void:
	hook_time_left = 0.0
	if hook_line:
		hook_line.visible = false


# Every enemy hurtbox inside the hook box takes hook_damage and is pulled in,
# all on the first frame (the line is only the look).
func _hook_hits() -> void:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = hook_shape
	query.transform = Transform2D(0.0, global_position + Vector2(hook_dir * hook_range / 2.0, -29.0))
	query.collision_mask = 2
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit_targets: Array[Node] = []
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var target: Node = hit.collider.get_parent()
		if target in hit_targets or not target.has_method("take_damage") or target.is_queued_for_deletion():
			continue
		hit_targets.append(target)
		print("Sinew Hook hit %s" % target.name)
		# Its knockback, reversed, carries it to hook_stop px in front.
		var gap: float = (target.global_position.x - global_position.x) * hook_dir - hook_stop
		var base: float = target.get("knockback_distance") if target.get("knockback_distance") else 0.0
		if gap > 0.0 and base > 0.0:
			target.take_damage(hook_damage, -hook_dir, gap / base, 1)
		else:
			target.take_damage(hook_damage, 0, 1.0, 1)
	if not hit_targets.is_empty():
		_start_hitstop(hook_hitstop)
		hit_sound.pitch_scale = hook_hit_pitch
		hit_sound.play()
		_shake(shake_hook)


func _update_skill_label() -> void:
	var q := "%.1fs" % dash_cooldown_left if dash_cooldown_left > 0.0 else "ready"
	var w := "%.1fs" % whirl_cooldown_left if whirl_cooldown_left > 0.0 else "ready"
	var e := "%.1fs" % hook_cooldown_left if hook_cooldown_left > 0.0 else "ready"
	skill_label.text = "Q Dash Slash: %s   W Whirl Slash: %s   E Sinew Hook: %s" % [q, w, e]
	if skill_boxes.is_empty():
		return
	_update_skill_box(0, "Q", dash_cooldown_left, dash_cooldown)
	_update_skill_box(1, "W", whirl_cooldown_left, whirl_cooldown)
	_update_skill_box(2, "E", hook_cooldown_left, hook_cooldown)


# The dark shade covers the box by the share of cooldown left; the key letter turns into seconds left.
func _update_skill_box(i: int, key: String, left: float, total: float) -> void:
	var shade: ColorRect = skill_boxes[i][0]
	var letter: Label = skill_boxes[i][1]
	var frac: float = clampf(left / total, 0.0, 1.0) if total > 0.0 else 0.0
	shade.size.y = (HUD_SKILL_BOX - 4) * frac
	shade.visible = frac > 0.0
	letter.text = key if frac <= 0.0 else str(ceili(left))
	letter.add_theme_color_override("font_color", Color(1, 1, 1, 1) if frac <= 0.0 else Color(0.7, 0.7, 0.7, 1))


func _build_status_hud() -> void:
	var hud: CanvasLayer = $Hud
	var back := ColorRect.new()
	back.position = HUD_HP_RECT.position
	back.size = HUD_HP_RECT.size
	back.color = Color(0, 0, 0, 0.6)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(back)
	hp_trail = ColorRect.new()
	hp_trail.position = Vector2(2, 2)
	hp_trail.size = HUD_HP_RECT.size - Vector2(4, 4)
	hp_trail.color = Color(1, 1, 1, 0.85)
	back.add_child(hp_trail)
	hp_fill = ColorRect.new()
	hp_fill.position = Vector2(2, 2)
	hp_fill.size = HUD_HP_RECT.size - Vector2(4, 4)
	hp_fill.color = HP_FILL_COLOR
	back.add_child(hp_fill)
	hp_text = _hud_label(18)
	hp_text.size = HUD_HP_RECT.size
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	back.add_child(hp_text)
	for i in 3:
		var box := ColorRect.new()
		box.position = Vector2(16 + i * (HUD_SKILL_BOX + 8), HUD_ROW_Y)
		box.size = Vector2(HUD_SKILL_BOX, HUD_SKILL_BOX)
		box.color = Color(0.25, 0.22, 0.2, 0.9)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(box)
		var shade := ColorRect.new()
		shade.position = Vector2(2, 2)
		shade.size = Vector2(HUD_SKILL_BOX - 4, 0)
		shade.color = Color(0, 0, 0, 0.7)
		box.add_child(shade)
		var letter := _hud_label(20)
		letter.size = box.size
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(letter)
		skill_boxes.append([shade, letter])
	var weapon := _add_hud_gear_box(hud, HUD_WEAPON_X, CALLUS_BLADE_ICON)
	hud_weapon_box = weapon[0]
	hud_weapon_icon = weapon[1]
	hud_weapon_text = weapon[2]
	hud_weapon_swatch = ColorRect.new()
	hud_weapon_swatch.position = Vector2(9, 9)
	hud_weapon_swatch.size = Vector2(HUD_SKILL_BOX - 18, HUD_SKILL_BOX - 18)
	hud_weapon_box.add_child(hud_weapon_swatch)
	var armor := _add_hud_gear_box(hud, HUD_ARMOR_X, ARMOR_ICON)
	hud_armor_box = armor[0]
	hud_armor_text = armor[2]
	var ring := _add_hud_gear_box(hud, HUD_RING_X, NERVE_RING_ICON)
	hud_ring_box = ring[0]
	hud_ring_text = ring[2]
	hud_pet_swatch = ColorRect.new()
	hud_pet_swatch.position = Vector2(HUD_PET_X, HUD_ROW_Y + 7)
	hud_pet_swatch.size = Vector2(20, 20)
	hud_pet_swatch.visible = false
	hud.add_child(hud_pet_swatch)
	hud_pet_name = _hud_label(20)
	hud_pet_name.position = Vector2(HUD_PET_X + 28, HUD_ROW_Y + 3)
	hud_pet_name.visible = false
	hud.add_child(hud_pet_name)
	hud_bag_full = _hud_label(20)
	hud_bag_full.position = HUD_BAG_FULL_POS
	hud_bag_full.add_theme_color_override("font_color", bag_full_color)
	hud_bag_full.visible = false
	hud.add_child(hud_bag_full)


func _hud_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	return label


func _update_hp_bar() -> void:
	hp_fill.size.x = (HUD_HP_RECT.size.x - 4) * float(hp) / max_hp
	hp_text.text = "HP %d / %d" % [hp, max_hp]
	# A heal (or the first build) pulls the trail up to the fill; a hit leaves it
	# behind and restarts the hold.
	if hp_trail.size.x <= hp_fill.size.x:
		hp_trail.size.x = hp_fill.size.x
	else:
		hp_trail_wait = hp_trail_delay


# Each frame: shrink the lost-HP trail after its hold, blink the fill at low HP.
func _tick_hp_bar(delta: float) -> void:
	if hp_trail.size.x > hp_fill.size.x:
		if hp_trail_wait > 0.0:
			hp_trail_wait -= delta
		else:
			hp_trail.size.x = maxf(hp_trail.size.x - hp_trail_speed * delta, hp_fill.size.x)
	if hp > 0 and hp <= max_hp * hp_low_ratio:
		hp_blink_time = fmod(hp_blink_time + delta, hp_blink_period)
		hp_fill.color = hp_low_color if hp_blink_time >= hp_blink_period * 0.5 else HP_FILL_COLOR
	else:
		hp_blink_time = 0.0
		hp_fill.color = HP_FILL_COLOR


func _set_passing_enemies(on: bool) -> void:
	passing_enemies = on
	set_collision_mask_value(ENEMY_BODY_LAYER, not on)
	set_collision_layer_value(WORLD_LAYER, not on)


# Nerve Ring: every enemy hurtbox the Player's hurtbox touches mid-roll takes
# ring_value once this roll, with no knockback.
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
		print("Nerve Ring grazed %s" % target.name)
		# Spark between the two hurtbox centers, i.e. where they rub.
		var enemy_center: Vector2 = hit.collider.get_node("CollisionShape2D").global_position
		_spawn_graze_spark((hurt_shape.global_position + enemy_center) / 2.0)
		target.take_damage(ring_value + ring_forge, 0, 1.0, 2)


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
		if attack_phase != AttackPhase.ACTIVE and combo_index == combo_damage.size() - 1 and has_legendary_weapon():
			_release_slash_wave()
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
	var parried := false
	for area in hitbox.get_overlapping_areas():
		# An enemy shot (enemy_shot layer) is swatted away instead of hit.
		if area.has_method("parry"):
			if not area.is_queued_for_deletion():
				area.parry()
				parried = true
			continue
		var target := area.get_parent()
		# is_queued_for_deletion: already killed this frame (e.g. by the set shockwave).
		if target in hit_targets or not target.has_method("take_damage") or target.is_queued_for_deletion():
			continue
		hit_targets.append(target)
		# Knock back along the facing locked at attack start, not the current facing.
		var finisher := combo_index == combo_damage.size() - 1
		target.take_damage(_hit_damage(), int(attack_pivot.scale.x), combo_knockback_scale[combo_index], 1 if finisher else 0)
		landed = true
	# One hitstop per frame no matter how many enemies were hit together.
	if landed:
		_start_hitstop(combo_hitstop[combo_index])
		hit_sound.pitch_scale = combo_hit_pitch[combo_index]
		hit_sound.play()
		if combo_index == combo_damage.size() - 1:
			_shake(shake_finisher)
	elif parried:
		# Light tick only: no hitstop or shake for swatting a shot.
		hit_sound.pitch_scale = parry_pitch
		hit_sound.play()


func _hit_damage() -> int:
	return combo_damage[combo_index] + weapon_bonus + weapon_forge


func has_legendary_weapon() -> bool:
	return weapon_tier > 0 and weapon_rarity == RARITY_NAMES.size() - 1


func _release_slash_wave() -> void:
	var wave := projectile_scene.instantiate()
	wave.hits_enemies = true
	wave.pierce = true
	wave.position = global_position + Vector2(facing * 30, 0)
	wave.aim = Vector2(facing, 0)
	wave.speed = slash_wave_speed
	wave.damage = slash_wave_damage
	wave.lifetime = slash_wave_travel / slash_wave_speed
	wave.splash_color = slash_wave_color
	wave.splash_size = 2.0
	wave.get_node("Glow").color = slash_wave_color
	wave.get_node("Core").color = slash_wave_core_color
	# A tall thin sliver reads as a cut, not a ball; the hit box matches it.
	for part in ["Glow", "Core"]:
		wave.get_node(part).scale = Vector2(0.5, 2.2)
	wave.get_node("Shadow").scale = Vector2(0.6, 1.0)
	wave.get_node("CollisionShape2D").scale = Vector2(1.2, 3.5)
	get_parent().add_child(wave)


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
		enemy.take_damage(full_set_damage if has_full_set() else shockwave_damage, dir, shockwave_knockback_scale, 1)
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
		set_label.text = "Set: %s 3/3 (big 3rd hit shockwave)" % gear_set_name
		print("Full set active: %s" % gear_set_name)
	elif has_set():
		set_label.text = "Set: %s 2/3 (3rd hit shockwave, ring for more)" % gear_set_name
		print("Set active: %s" % gear_set_name)
	else:
		set_label.text = "Set: none (weapon + armor)"


# rarity_weights shifted by the current drop_luck (see luck_weight_shift).
func luck_weights() -> Array[int]:
	var level := clampi(drop_luck, 0, max_drop_luck)
	var weights: Array[int] = []
	for i in rarity_weights.size():
		weights.append(maxi(0, rarity_weights[i] + level * luck_weight_shift[i]))
	return weights


# Picks a rarity by luck_weights (shared by weapon, armor and ring drops).
func roll_rarity() -> int:
	var weights := luck_weights()
	var total := 0
	for w in weights:
		total += w
	var pick := randi() % total
	var rarity := 0
	while pick >= weights[rarity]:
		pick -= weights[rarity]
		rarity += 1
	return rarity


# Rolls a weapon drop of this tier: [rarity, bonus] (see rarity_weights).
func roll_weapon(tier: int) -> Array:
	var rarity := roll_rarity()
	var base := weapon_damage_bonus[tier - 1]
	var bonus := maxi(1, base + randi_range(rarity_bonus_min[rarity], rarity_bonus_max[rarity]))
	return [rarity, bonus]


func roll_armor() -> Array:
	var rarity := roll_rarity()
	return [rarity, maxi(1, armor_damage_reduction + randi_range(armor_bonus_min[rarity], armor_bonus_max[rarity]))]


func roll_ring() -> Array:
	var rarity := roll_rarity()
	return [rarity, maxi(1, ring_roll_damage + randi_range(rarity_bonus_min[rarity], rarity_bonus_max[rarity]))]


# A drop of this kind ("weapon", "armor" or "ring"): [rarity, value].
func roll_gear(kind: String, tier: int = 1) -> Array:
	match kind:
		"armor":
			return roll_armor()
		"ring":
			return roll_ring()
	return roll_weapon(tier)


func weapon_text(tier: int, rarity: int, bonus: int) -> String:
	return "%s %s +%d" % [RARITY_NAMES[rarity], weapon_names[tier - 1], bonus]


func armor_text(rarity: int, value: int) -> String:
	return "%s %s -%d" % [RARITY_NAMES[rarity], armor_name, value]


func ring_text(rarity: int, value: int) -> String:
	return "%s %s %d" % [RARITY_NAMES[rarity], ring_name, value]


func gear_text(kind: String, tier: int, rarity: int, value: int) -> String:
	match kind:
		"armor":
			return armor_text(rarity, value)
		"ring":
			return ring_text(rarity, value)
	return weapon_text(tier, rarity, value)


# bonus < 0 means the tier's plain bonus (a Common of weapon_damage_bonus).
func equip_weapon(tier: int, rarity: int = 0, bonus: int = -1) -> void:
	if bonus < 0:
		bonus = weapon_damage_bonus[tier - 1]
	# A drop no better than the current weapon goes to the bag (or Skin Crystal).
	if is_dead:
		return
	# The forge levels count, so a forged weapon is never swapped for a weaker one.
	if weapon_tier > 0 and bonus <= weapon_bonus + weapon_forge:
		print("Passed on %s (wearing +%d)" % [weapon_text(tier, rarity, bonus), weapon_bonus + weapon_forge])
		_bag_or_salvage("weapon", tier, rarity, bonus)
		return
	weapon_tier = tier
	weapon_rarity = rarity
	weapon_bonus = bonus
	if weapon_forge > 0:
		print("Forge +%d lost with the old weapon" % weapon_forge)
	weapon_forge = 0
	var i := tier - 1
	print("Picked up %s" % weapon_text(tier, rarity, bonus))
	weapon_label.add_theme_color_override("font_color", rarity_colors[rarity])
	_update_weapon_label()
	attack_arc.color = weapon_arc_color[i]
	_update_set_label()
	_save_gear()


func _update_weapon_label() -> void:
	var text := weapon_text(weapon_tier, weapon_rarity, weapon_bonus)
	if weapon_forge > 0:
		text += ", Forge +%d (+%d)" % [weapon_forge, weapon_bonus + weapon_forge]
	weapon_label.text = "Weapon: %s damage" % text
	_update_hud_weapon()


# [frame, icon, text]: a rarity-colored frame with the gear icon inside and a
# label to its right; both hidden until something is worn there.
func _add_hud_gear_box(hud: CanvasLayer, x: float, icon_texture: Texture2D) -> Array:
	var box := ColorRect.new()
	box.position = Vector2(x, HUD_ROW_Y)
	box.size = Vector2(HUD_SKILL_BOX, HUD_SKILL_BOX)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.visible = false
	hud.add_child(box)
	var inner := ColorRect.new()
	inner.position = Vector2(3, 3)
	inner.size = Vector2(HUD_SKILL_BOX - 6, HUD_SKILL_BOX - 6)
	inner.color = Color(0.12, 0.1, 0.1, 0.95)
	box.add_child(inner)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = icon_texture
	icon.position = Vector2(3, 3)
	icon.size = inner.size
	box.add_child(icon)
	var text := _hud_label(20)
	text.position = Vector2(x + HUD_SKILL_BOX + 6, HUD_ROW_Y + 3)
	text.visible = false
	hud.add_child(text)
	return [box, icon, text]


# Shows or hides one HUD gear box and colors frame and text by rarity.
func _set_hud_gear(box: ColorRect, text: Label, worn: bool, rarity: int, value_text: String) -> void:
	box.visible = worn
	text.visible = worn
	if not worn:
		return
	box.color = rarity_colors[rarity]
	text.text = value_text
	text.add_theme_color_override("font_color", rarity_colors[rarity])


func _update_hud_armor() -> void:
	if hud_armor_box != null:
		_set_hud_gear(hud_armor_box, hud_armor_text, has_armor, armor_rarity, "-%d" % (armor_value + armor_forge))


func _update_hud_ring() -> void:
	if hud_ring_box != null:
		_set_hud_gear(hud_ring_box, hud_ring_text, has_ring, ring_rarity, "+%d" % (ring_value + ring_forge))


# HUD weapon box: hidden with no weapon; the frame and text take the rarity color,
# the number is the total damage bonus (rolled + forge).
func _update_hud_weapon() -> void:
	if hud_weapon_box == null:
		return
	var worn := weapon_tier > 0
	_set_hud_gear(hud_weapon_box, hud_weapon_text, worn, weapon_rarity, "%s +%d" % [RARITY_NAMES[weapon_rarity], weapon_bonus + weapon_forge])
	if not worn:
		return
	hud_weapon_icon.visible = weapon_tier == 1
	hud_weapon_swatch.visible = weapon_tier != 1
	hud_weapon_swatch.color = weapon_arc_color[weapon_tier - 1]


# This kind's forge level (0 when nothing is worn there).
func forge_level(kind: String) -> int:
	match kind:
		"armor":
			return armor_forge
		"ring":
			return ring_forge
	return weapon_forge


# This kind's highest forge level.
func forge_max(kind: String) -> int:
	return mini(armor_forge_max, forge_costs.size()) if kind == "armor" else forge_costs.size()


# True if this kind is worn and below its forge cap.
func can_forge(kind: String) -> bool:
	return not worn_item(kind).is_empty() and forge_level(kind) < forge_max(kind)


# The worn piece the blacksmith forges next: forge_choice if it can still be
# forged, else the one with the lowest forge level that isn't maxed (ties:
# weapon, armor, ring). "" when nothing worn can be forged.
func forge_target() -> String:
	if forge_choice != "" and can_forge(forge_choice):
		return forge_choice
	var best := ""
	for kind in ["weapon", "armor", "ring"]:
		if not can_forge(kind):
			continue
		if best == "" or forge_level(kind) < forge_level(best):
			best = kind
	return best


# Blacksmith X: picks the next forgeable piece after the current target
# (weapon -> armor -> ring -> weapon). Returns the new target.
func cycle_forge_choice() -> String:
	var kinds := ["weapon", "armor", "ring"]
	var start := kinds.find(forge_target())
	for step in range(1, kinds.size() + 1):
		var kind: String = kinds[(start + step) % kinds.size()]
		if can_forge(kind):
			forge_choice = kind
			break
	return forge_target()


# The next forge level's cost in Skin Crystal, or -1 when nothing can be forged.
func forge_cost() -> int:
	var kind := forge_target()
	if kind == "":
		return -1
	return forge_costs[forge_level(kind)]


# Blacksmith: spends Skin Crystal for +1 forge on forge_target(). Pops up the
# result above the Player either way; returns true if it forged.
func forge_next() -> bool:
	if is_dead:
		return false
	var kind := forge_target()
	if kind == "":
		# Nothing to forge (all maxed, or nothing worn): grow the bag instead.
		return grow_bag()
	var cost := forge_cost()
	if materials < cost:
		_spawn_salvage_popup("Need %d %s" % [cost, material_name], Color(1, 0.4, 0.35, 1))
		return false
	materials -= cost
	var worn := worn_item(kind)
	match kind:
		"armor":
			armor_forge += 1
			_update_armor_label()
		"ring":
			ring_forge += 1
			_update_ring_label()
		_:
			weapon_forge += 1
			_update_weapon_label()
	var level := forge_level(kind)
	print("Forged %s to +%d for %d %s (now %d)" % [gear_text(kind, worn.tier, worn.rarity, worn.value), level, cost, material_name, materials])
	_update_material_label()
	_save_gear()
	play_pickup_sound(0.8)
	_spawn_salvage_popup("%s Forge +%d!" % [kind.capitalize(), level], rarity_colors[worn.rarity])
	return true


func _update_armor_label() -> void:
	var text := armor_text(armor_rarity, armor_value)
	if armor_forge > 0:
		text += ", Forge +%d (-%d)" % [armor_forge, armor_value + armor_forge]
	armor_label.text = "Armor: %s damage taken" % text
	_update_hud_armor()


func _update_ring_label() -> void:
	var text := ring_text(ring_rarity, ring_value)
	if ring_forge > 0:
		text += ", Forge +%d (%d)" % [ring_forge, ring_value + ring_forge]
	ring_label.text = "Ring: %s roll graze" % text
	_update_hud_ring()


# value < 0 means the plain base (a Common of armor_damage_reduction).
func equip_armor(rarity: int = 0, value: int = -1) -> void:
	if value < 0:
		value = armor_damage_reduction
	# A drop no better than the worn armor goes to the bag (or Skin Crystal).
	if is_dead:
		return
	if has_armor and value <= armor_value + armor_forge:
		print("Passed on %s (wearing -%d)" % [armor_text(rarity, value), armor_value + armor_forge])
		_bag_or_salvage("armor", 1, rarity, value)
		return
	has_armor = true
	armor_rarity = rarity
	armor_value = value
	armor_forge = 0
	print("Picked up %s" % armor_text(rarity, value))
	_update_armor_label()
	armor_label.add_theme_color_override("font_color", rarity_colors[rarity])
	_update_set_label()
	_save_gear()


# value < 0 means the plain base (a Common of ring_roll_damage).
func equip_ring(rarity: int = 0, value: int = -1) -> void:
	if value < 0:
		value = ring_roll_damage
	if is_dead:
		return
	if has_ring and value <= ring_value + ring_forge:
		print("Passed on %s (wearing %d)" % [ring_text(rarity, value), ring_value + ring_forge])
		_bag_or_salvage("ring", 1, rarity, value)
		return
	has_ring = true
	ring_rarity = rarity
	ring_value = value
	ring_forge = 0
	print("Picked up %s" % ring_text(rarity, value))
	_update_ring_label()
	ring_label.add_theme_color_override("font_color", rarity_colors[rarity])
	_update_set_label()
	_save_gear()


# A passed-on drop goes into the bag, or breaks down when the bag is full.
func _bag_or_salvage(kind: String, tier: int, rarity: int, value: int) -> void:
	if bag.size() >= bag_size:
		salvage(rarity, "Bag full! ")
		_flash_bag_full()
		return
	bag.append({"kind": kind, "tier": tier, "rarity": rarity, "value": value, "forge": 0, "locked": false})
	print("Bagged %s (%d/%d)" % [gear_text(kind, tier, rarity, value), bag.size(), bag_size])
	_save_gear()
	_spawn_salvage_popup("Bag: %s (%s)" % [gear_text(kind, tier, rarity, value), compare_text(kind, value)],
		compare_color(kind, value))


# What's worn in this kind's slot, as a bag item ({} when the slot is empty).
func worn_item(kind: String) -> Dictionary:
	match kind:
		"armor":
			return {"kind": kind, "tier": 1, "rarity": armor_rarity, "value": armor_value, "forge": armor_forge} if has_armor else {}
		"ring":
			return {"kind": kind, "tier": 1, "rarity": ring_rarity, "value": ring_value, "forge": ring_forge} if has_ring else {}
	if weapon_tier == 0:
		return {}
	return {"kind": kind, "tier": weapon_tier, "rarity": weapon_rarity, "value": weapon_bonus, "forge": weapon_forge}


# How much a drop of this kind and value beats what's worn (a weapon counts the
# worn forge levels, like equip_weapon does); an empty slot counts as 0.
func gear_diff(kind: String, value: int) -> int:
	var worn := worn_item(kind)
	if worn.is_empty():
		return value
	return value - worn.value - worn.forge


# The comparison shown over a gear drop and in its pickup popup.
func compare_text(kind: String, value: int) -> String:
	if worn_item(kind).is_empty():
		return "New"
	var diff := gear_diff(kind, value)
	if diff > 0:
		return "+%d better" % diff
	if diff < 0:
		return "%d worse" % diff
	return "Same"


func compare_color(kind: String, value: int) -> Color:
	var diff := gear_diff(kind, value)
	if diff > 0:
		return compare_better_color
	return compare_worse_color if diff < 0 else compare_same_color


# Wears bag item index even if it's worse; whatever was worn takes its bag slot.
# Each piece keeps its forge level both ways.
func wear_from_bag(index: int) -> void:
	if is_dead or index < 0 or index >= bag.size():
		return
	var item: Dictionary = bag[index]
	var old := worn_item(item.kind)
	bag.remove_at(index)
	if not old.is_empty():
		# The worn piece takes the slot's lock, so a swap doesn't drop it.
		old.locked = item.get("locked", false)
		bag.insert(index, old)
	# Empty the slot so the equip below always takes the item.
	match item.kind:
		"armor":
			has_armor = false
			equip_armor(item.rarity, item.value)
			armor_forge = item.forge
			_update_armor_label()
			_save_gear()
		"ring":
			has_ring = false
			equip_ring(item.rarity, item.value)
			ring_forge = item.forge
			_update_ring_label()
			_save_gear()
		_:
			weapon_tier = 0
			weapon_forge = 0
			equip_weapon(item.tier, item.rarity, item.value)
			weapon_forge = item.forge
			_update_weapon_label()
			_save_gear()
	play_pickup_sound()


# Skin Crystal for the next bag_grow_slots bag slots, or -1 once all are bought.
func bag_grow_cost() -> int:
	return bag_grow_costs[bag_grows] if bag_grows < bag_grow_costs.size() else -1


# Blacksmith, once nothing can be forged: spends Skin Crystal for
# bag_grow_slots more bag slots. Pops up the result; returns true if it grew.
func grow_bag() -> bool:
	var cost := bag_grow_cost()
	if cost < 0:
		_spawn_salvage_popup("Forge and bag maxed", rarity_colors[0])
		return false
	if materials < cost:
		_spawn_salvage_popup("Need %d %s" % [cost, material_name], Color(1, 0.4, 0.35, 1))
		return false
	materials -= cost
	bag_size += bag_grow_slots
	bag_grows += 1
	print("Bag grown to %d for %d %s (now %d)" % [bag_size, cost, material_name, materials])
	_update_material_label()
	_save_gear()
	play_pickup_sound(0.8)
	_spawn_salvage_popup("Bag +%d! (%d slots)" % [bag_grow_slots, bag_size], rarity_colors[2])
	return true


# Inventory L: locks bag item index against salvage, or unlocks it. Saved.
func toggle_bag_lock(index: int) -> void:
	if is_dead or index < 0 or index >= bag.size():
		return
	bag[index].locked = not bag[index].get("locked", false)
	print("%s %s" % ["Locked" if bag[index].locked else "Unlocked",
		gear_text(bag[index].kind, bag[index].tier, bag[index].rarity, bag[index].value)])
	_save_gear()


# Breaks bag item index down into Skin Crystal (a forged piece's levels are lost).
# A locked item stays.
func salvage_from_bag(index: int) -> void:
	if is_dead or index < 0 or index >= bag.size():
		return
	var item: Dictionary = bag[index]
	if item.get("locked", false):
		_spawn_salvage_popup("Locked (L to unlock)", rarity_colors[0])
		return
	bag.remove_at(index)
	print("Salvaged %s from the bag" % gear_text(item.kind, item.tier, item.rarity, item.value))
	salvage(item.rarity)


# Bag items no better than what's worn in their slot (their own forge counts);
# items for an empty slot and locked items are kept. What salvage_worse_from_bag
# would break down.
func worse_bag_indices() -> Array[int]:
	var found: Array[int] = []
	for i in bag.size():
		var item: Dictionary = bag[i]
		if not item.get("locked", false) and not worn_item(item.kind).is_empty() \
				and gear_diff(item.kind, item.value + item.forge) <= 0:
			found.append(i)
	return found


# Inventory Space: breaks down every worse bag item at once (one popup for all).
# Returns how many were salvaged.
func salvage_worse_from_bag() -> int:
	if is_dead:
		return 0
	var found := worse_bag_indices()
	if found.is_empty():
		_spawn_salvage_popup("Nothing worse in the bag", rarity_colors[0])
		return 0
	var amount := 0
	var best := 0
	found.reverse()
	for i in found:
		var item: Dictionary = bag[i]
		amount += salvage_amounts[item.rarity]
		best = maxi(best, item.rarity)
		bag.remove_at(i)
	materials += amount
	print("Salvaged %d worse bag items into %d %s (now %d)" % [found.size(), amount, material_name, materials])
	_update_material_label()
	_save_gear()
	_spawn_salvage_popup("Salvaged %d: +%d %s" % [found.size(), amount, material_name], rarity_colors[best])
	return found.size()


# Breaks a drop of this rarity down into Skin Crystal (popup_prefix leads the popup).
func salvage(rarity: int, popup_prefix: String = "") -> void:
	var amount := salvage_amounts[rarity]
	materials += amount
	print("Salvaged into %d %s (now %d)" % [amount, material_name, materials])
	_update_material_label()
	_save_gear()
	_spawn_salvage_popup("%s+%d %s" % [popup_prefix, amount, material_name], rarity_colors[rarity])


func _update_bag_full() -> void:
	if hud_bag_full == null:
		return
	hud_bag_full.visible = bag.size() >= bag_size
	hud_bag_full.text = "Bag full %d/%d" % [bag.size(), bag_size]


# Pops the warning big and white, then back, so an auto-salvage gets noticed.
func _flash_bag_full() -> void:
	_update_bag_full()
	hud_bag_full.pivot_offset = hud_bag_full.size / 2
	hud_bag_full.scale = Vector2(1.4, 1.4)
	hud_bag_full.modulate = Color(2, 2, 2, 1)
	var tween := hud_bag_full.create_tween()
	tween.tween_property(hud_bag_full, "scale", Vector2.ONE, bag_full_flash_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(hud_bag_full, "modulate", Color(1, 1, 1, 1), bag_full_flash_time)


func _update_material_label() -> void:
	material_label.text = "%s: %d" % [material_name, materials]


# A one-off Label in the world above the Player (like enemy damage numbers).
# While the inventory is open it would sit frozen behind the dark panel, so the
# inventory shows it as its own message line instead.
func _spawn_salvage_popup(text: String, color: Color) -> void:
	var inventory := get_node_or_null("../../Inventory")
	if inventory != null and inventory.visible:
		inventory.show_message(text, color)
		return
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(400, 30)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.z_index = 20
	label.position = global_position + Vector2(-200, -130)
	get_parent().add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - salvage_popup_rise, salvage_popup_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, salvage_popup_time * 0.4) \
		.set_delay(salvage_popup_time * 0.6)
	tween.tween_callback(label.queue_free)


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
	if not kind in owned_pets:
		owned_pets.append(kind)
	# Before add_child so pet.gd's base_color picks it up.
	pet.get_node("Visual/Body").color = pet_colors[kind - 1]
	pet.bite_damage = pet_bite_damage[kind - 1]
	pet.bite_cooldown = pet_bite_cooldown[kind - 1]
	pet.bite_pop = pet_bite_pop[kind - 1]
	pet.spits = kind == 3
	pet.sprite_sheet = pet_sprite_sheets[kind - 1]
	# Beside the Player in the y-sorted World, so it draws by its y like the rest.
	get_parent().add_child(pet)
	print("Pet now %s (owned %s)" % [pet_names[kind - 1], owned_pets])
	pet_label.text = "Pet: %s (%s, %s %d every %.1fs)" % [pet_names[kind - 1], pet_passive_text[kind - 1], "spits" if pet.spits else "bites", pet.bite_damage, pet.bite_cooldown]
	hud_pet_swatch.color = pet_colors[kind - 1]
	hud_pet_name.text = pet_names[kind - 1]
	hud_pet_name.add_theme_color_override("font_color", pet_colors[kind - 1])
	hud_pet_swatch.visible = true
	hud_pet_name.visible = true
	_save_gear()


func _save_gear() -> void:
	var cfg := ConfigFile.new()
	# Load first so sections other than "gear" (later progress) are kept.
	cfg.load(SAVE_PATH)
	cfg.set_value("gear", "weapon_tier", weapon_tier)
	cfg.set_value("gear", "weapon_rarity", weapon_rarity)
	cfg.set_value("gear", "weapon_bonus", weapon_bonus)
	cfg.set_value("gear", "weapon_forge", weapon_forge)
	cfg.set_value("gear", "armor", has_armor)
	cfg.set_value("gear", "armor_rarity", armor_rarity)
	cfg.set_value("gear", "armor_value", armor_value)
	cfg.set_value("gear", "armor_forge", armor_forge)
	cfg.set_value("gear", "ring", has_ring)
	cfg.set_value("gear", "ring_rarity", ring_rarity)
	cfg.set_value("gear", "ring_value", ring_value)
	cfg.set_value("gear", "ring_forge", ring_forge)
	cfg.set_value("gear", "pet_kind", pet_kind)
	cfg.set_value("gear", "owned_pets", owned_pets)
	cfg.set_value("materials", "skin_crystal", materials)
	cfg.set_value("bag", "items", bag)
	cfg.set_value("bag", "grows", bag_grows)
	cfg.save(SAVE_PATH)


func _load_gear() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	# Before the equips below: they save, so the count must be read first.
	# Saves from before salvage load with 0.
	materials = maxi(0, cfg.get_value("materials", "skin_crystal", 0))
	_update_material_label()
	var grows: int = clampi(cfg.get_value("bag", "grows", 0), 0, bag_grow_costs.size())
	bag_size += (grows - bag_grows) * bag_grow_slots
	bag_grows = grows
	_load_bag(cfg.get_value("bag", "items", []))
	var tier: int = clampi(cfg.get_value("gear", "weapon_tier", 0), 0, weapon_names.size())
	var kind: int = clampi(cfg.get_value("gear", "pet_kind", 0), 0, pet_names.size())
	if tier > 0:
		# Saves from before rarity load as a Common with the tier's plain bonus.
		var rarity: int = clampi(cfg.get_value("gear", "weapon_rarity", 0), 0, RARITY_NAMES.size() - 1)
		# Read before equip_weapon, which resets and saves it.
		var forge: int = clampi(cfg.get_value("gear", "weapon_forge", 0), 0, forge_costs.size())
		equip_weapon(tier, rarity, cfg.get_value("gear", "weapon_bonus", weapon_damage_bonus[tier - 1]))
		weapon_forge = forge
		_update_weapon_label()
		_save_gear()
	# Armor and ring from before rarity load as Common with the base value.
	var last := RARITY_NAMES.size() - 1
	# Forge levels are read before the equips, which reset and save them.
	var a_forge: int = clampi(cfg.get_value("gear", "armor_forge", 0), 0, forge_max("armor"))
	var r_forge: int = clampi(cfg.get_value("gear", "ring_forge", 0), 0, forge_max("ring"))
	if cfg.get_value("gear", "armor", false):
		equip_armor(clampi(cfg.get_value("gear", "armor_rarity", 0), 0, last), cfg.get_value("gear", "armor_value", armor_damage_reduction))
		armor_forge = a_forge
		_update_armor_label()
	if cfg.get_value("gear", "ring", false):
		equip_ring(clampi(cfg.get_value("gear", "ring_rarity", 0), 0, last), cfg.get_value("gear", "ring_value", ring_roll_damage))
		ring_forge = r_forge
		_update_ring_label()
	if a_forge > 0 or r_forge > 0:
		_save_gear()
	# Saves from before pet storage keep just the active pet.
	var owned: Variant = cfg.get_value("gear", "owned_pets", [])
	if owned is Array:
		for k in owned:
			if k is int and k >= 1 and k <= pet_names.size() and not k in owned_pets:
				owned_pets.append(k)
	if kind > 0:
		equip_pet(kind)
	print("Loaded save: weapon %d +%d forge %d, armor %s -%d, ring %s %d, pet %d, %d %s" % [weapon_tier, weapon_bonus, weapon_forge, has_armor, armor_value, has_ring, ring_value, pet_kind, materials, material_name])


# Saved bag items, skipping any that don't look like gear.
func _load_bag(items: Variant) -> void:
	bag.clear()
	if not items is Array:
		return
	for item in items:
		if bag.size() >= bag_size:
			break
		if not item is Dictionary or not item.get("kind", "") in ["weapon", "armor", "ring"]:
			continue
		bag.append({"kind": item.kind,
			"tier": clampi(item.get("tier", 1), 1, weapon_names.size()),
			"rarity": clampi(item.get("rarity", 0), 0, RARITY_NAMES.size() - 1),
			"value": maxi(1, item.get("value", 1)),
			"forge": clampi(item.get("forge", 0), 0, forge_max(item.kind)),
			"locked": item.get("locked", false) == true})


# Returns false at full HP (or dead) so the drop stays on the ground.
func heal(amount: int) -> bool:
	if is_dead or hp >= max_hp:
		return false
	hp = mini(hp + amount, max_hp)
	hp_label.text = str(hp)
	_update_hp_bar()
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


# kind: 0 normal, 1 counter, 2 tough, 3 ranged shot (see warn_streams).
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
	# Counted for the stage grade (test_map.gd resets it each stage); dodged hits don't count.
	hits_taken += 1
	if has_armor:
		# Never below 1 so armor can't make a hit free.
		amount = maxi(amount - armor_value - armor_forge, 1)
	hp = maxi(hp - amount, 0)
	hp_label.text = str(hp)
	_update_hp_bar()
	print("Player HP: %d" % hp)
	hurt_sound.play()
	# A hit during the guard or whiff ends it so the push can apply.
	if parry_time_left > 0.0:
		_end_parry()
	if hp <= 0:
		_die()
		return
	body.color = hurt_flash_color
	hurt_flash_left = hurt_flash_duration
	# Rolling, dashing or whirling already decides where the Player goes, so the push only applies outside them.
	if direction != 0 and hurt_knockback_duration > 0.0 and roll_time_left <= 0.0 and dash_time_left <= 0.0 and whirl_time_left <= 0.0:
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
	_end_whirl()
	_end_hook()
	_end_parry()
	hurt_knockback_left = 0.0
	shockwave_time_left = 0.0
	shockwave_ring.visible = false
	_stop_shake()
	$Hurtbox.set_deferred("monitorable", false)
	hurt_flash_left = 0.0
	body.color = dead_color
	game_over.visible = true


func _setup_sprite() -> void:
	sprite = Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = sprite_sheet
	sprite.hframes = int(sprite_sheet.get_width() / sprite_frame_size.x)
	sprite.centered = false
	sprite.offset = -sprite_origin
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/sprite_tint.gdshader")
	sprite.material = mat
	visual.add_child(sprite)
	visual.move_child(sprite, body.get_index())
	body.visible = false
	$Visual/FacingMarker.visible = false


# Idle (2 frames) when standing, walk (4 frames) when moving, the basic attack
# pose for the current AttackPhase, idle frame 0 while a skill runs or the
# Player is pushed back. Body colour (hurt/heal flash, dead) is laid over it.
func _update_sprite(delta: float) -> void:
	sprite_anim_time += delta
	var frame := 0
	var busy := dash_time_left > 0.0 or whirl_time_left > 0.0 or hook_time_left > 0.0 or hurt_knockback_left > 0.0 or is_dead
	# Facing can turn mid-swing, but the hitbox keeps the facing locked at the
	# hit's start (attack_pivot), so the swing pose is drawn that way too.
	sprite.flip_h = not busy and attack_phase != AttackPhase.NONE and int(attack_pivot.scale.x) != facing
	if busy:
		frame = 0
	elif attack_phase != AttackPhase.NONE:
		frame = 5 + int(attack_phase)
	elif roll_time_left <= 0.0 and velocity.length() > 10.0:
		frame = 2 + int(sprite_anim_time * walk_fps) % 4
	else:
		frame = int(sprite_anim_time * idle_fps) % 2
	sprite.frame = frame
	var tint := Color(body.color, 0.0)
	if body.color != base_color:
		tint.a = 0.6
	sprite.material.set_shader_parameter("tint", tint)


func _process(delta: float) -> void:
	if sprite:
		_update_sprite(delta)
	# The bag changes from pickups, the inventory and loading; checked every frame.
	_update_bag_full()
	_tick_hp_bar(delta)
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
