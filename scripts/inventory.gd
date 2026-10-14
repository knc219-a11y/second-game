extends CanvasLayer

# I opens the inventory over a paused game: the three worn gear slots (rarity
# colored, with value and forge level), the pet, the set and the Skin Crystal
# count, then rows of bag slots (player.gd bag: drops no better than what's
# worn). Left/Right pick a bag item, X wears it (the worn one goes into the bag)
# and C salvages it into Skin Crystal. Up/Down switches the active pet among the
# kept ones (player.gd owned_pets). I or Esc closes it. Better drops still
# auto-equip on pickup. Built in code; it keeps running while the tree is
# paused (process_mode always in test_map.tscn).

const CALLUS_BLADE_ICON := preload("res://art/stage1/drops/s1_drop_callus_blade.png")
const NERVE_RING_ICON := preload("res://art/stage1/drops/s1_drop_nerve_ring.png")
const ARMOR_ICON := preload("res://art/stage1/drops/s1_drop_husk_shard.png")
const SCAB_PUP_ICON := preload("res://art/stage1/drops/s1_drop_regen_core.png")
const CRYSTAL_ICON := preload("res://art/stage1/drops/s1_drop_skin_crystal.png")

@export var empty_color: Color = Color(0.55, 0.55, 0.55, 1)
@export var icon_size: float = 40.0
@export var bag_cell_size: float = 56.0
@export var bag_cell_gap: float = 10.0
# Bag slots per row; slots bought at the blacksmith fill a second row.
@export var bag_row_cells: int = 12
@export var bag_cell_color: Color = Color(0.2, 0.17, 0.15, 1)
@export var cursor_color: Color = Color(1, 1, 1, 0.9)

# Slot name -> [icon TextureRect, placeholder ColorRect, Label].
var rows: Dictionary = {}
# One per bag slot: [icon TextureRect, placeholder ColorRect, rarity bar ColorRect].
var cells: Array = []
var selected: int = 0
var bag_heading: Label
var detail: Label
var cursor: ColorRect

@onready var map: Node = get_parent()


func _ready() -> void:
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var panel := ColorRect.new()
	panel.color = Color(0.1, 0.08, 0.07, 0.92)
	panel.position = Vector2(140, 30)
	panel.size = Vector2(1000, 680)
	add_child(panel)
	var heading := _make_label(30)
	heading.text = "Inventory"
	heading.position = Vector2(0, 14)
	heading.size = Vector2(1000, 40)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(heading)
	var y := 72.0
	for slot in ["weapon", "armor", "ring", "pet", "set", "material"]:
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.position = Vector2(28, y)
		icon.size = Vector2(icon_size, icon_size)
		panel.add_child(icon)
		var swatch := ColorRect.new()
		swatch.position = Vector2(36, y + 8)
		swatch.size = Vector2(icon_size - 16, icon_size - 16)
		panel.add_child(swatch)
		var label := _make_label(20)
		label.position = Vector2(84, y)
		label.size = Vector2(900, icon_size + 16)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER if slot != "pet" else VERTICAL_ALIGNMENT_TOP
		panel.add_child(label)
		rows[slot] = [icon, swatch, label]
		y += 48.0 if slot != "pet" else 88.0
	bag_heading = _make_label(20)
	bag_heading.position = Vector2(28, y + 4)
	panel.add_child(bag_heading)
	var cell_y := y + 40.0
	cursor = ColorRect.new()
	cursor.color = cursor_color
	cursor.size = Vector2(bag_cell_size + 8, bag_cell_size + 8)
	panel.add_child(cursor)
	# map.player is still unset here (the map's @onready runs after its children).
	# A cell for every slot the bag can grow to; refresh hides the unbought ones.
	var p: Node = map.get_node("World/Player")
	var most: int = p.bag_size + (p.bag_grow_costs.size() - p.bag_grows) * p.bag_grow_slots
	for i in most:
		var cell := ColorRect.new()
		cell.color = bag_cell_color
		cell.position = Vector2(28, cell_y) + _cell_offset(i)
		cell.size = Vector2(bag_cell_size, bag_cell_size)
		panel.add_child(cell)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.position = Vector2(8, 4)
		icon.size = Vector2(bag_cell_size - 16, bag_cell_size - 16)
		cell.add_child(icon)
		var swatch := ColorRect.new()
		swatch.position = Vector2(18, 14)
		swatch.size = Vector2(bag_cell_size - 36, bag_cell_size - 36)
		cell.add_child(swatch)
		var bar := ColorRect.new()
		bar.position = Vector2(0, bag_cell_size - 8)
		bar.size = Vector2(bag_cell_size, 8)
		cell.add_child(bar)
		cells.append([icon, swatch, bar])
	detail = _make_label(18)
	detail.position = Vector2(28, cell_y + 2 * bag_cell_size + bag_cell_gap + 8)
	detail.size = Vector2(944, 60)
	panel.add_child(detail)
	var hint := _make_label(16)
	hint.text = "Worse drops go to the bag; a full bag breaks them into Skin Crystal.\nLeft / Right: pick   X: wear   C: salvage   Up / Down: switch pet   I / Esc: close"
	hint.modulate = empty_color
	hint.position = Vector2(0, 630)
	hint.size = Vector2(1000, 48)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(hint)


func _process(_delta: float) -> void:
	if visible:
		if Input.is_action_just_pressed("inventory") or Input.is_action_just_pressed("pause"):
			close()
			return
		var p: Node = map.player
		if Input.is_action_just_pressed("move_left"):
			selected = maxi(0, selected - 1)
			refresh()
		elif Input.is_action_just_pressed("move_right"):
			selected = mini(p.bag_size - 1, selected + 1)
			refresh()
		elif Input.is_action_just_pressed("attack") and selected < p.bag.size():
			p.wear_from_bag(selected)
			refresh()
		elif Input.is_action_just_pressed("interact") and selected < p.bag.size():
			p.salvage_from_bag(selected)
			refresh()
		elif Input.is_action_just_pressed("move_up"):
			_switch_pet(-1)
		elif Input.is_action_just_pressed("move_down"):
			_switch_pet(1)
	elif Input.is_action_just_pressed("inventory") and _can_open():
		open()


# Not while dead, mid-fade or already paused (the pause menu is up).
func _can_open() -> bool:
	return not map.player.is_dead and not map.moving_on and not get_tree().paused


func open() -> void:
	refresh()
	visible = true
	get_tree().paused = true
	print("Inventory opened")


func close() -> void:
	visible = false
	get_tree().paused = false
	print("Inventory closed")


func refresh() -> void:
	var p: Node = map.player
	if p.weapon_tier > 0:
		var text: String = "Weapon   " + p.weapon_text(p.weapon_tier, p.weapon_rarity, p.weapon_bonus)
		if p.weapon_forge > 0:
			text += "  Forge +%d" % p.weapon_forge
		text += "  (+%d damage)" % (p.weapon_bonus + p.weapon_forge)
		_set_row("weapon", text, p.rarity_colors[p.weapon_rarity],
			CALLUS_BLADE_ICON if p.weapon_tier == 1 else null, p.weapon_arc_color[p.weapon_tier - 1])
	else:
		_set_row("weapon", "Weapon   none", empty_color, null, empty_color)
	if p.has_armor:
		_set_row("armor", "Armor    %s%s  (-%d damage taken)" % [p.armor_text(p.armor_rarity, p.armor_value),
			"  Forge +%d" % p.armor_forge if p.armor_forge > 0 else "", p.armor_value + p.armor_forge],
			p.rarity_colors[p.armor_rarity], ARMOR_ICON, empty_color)
	else:
		_set_row("armor", "Armor    none", empty_color, null, empty_color)
	if p.has_ring:
		_set_row("ring", "Ring     %s%s  (%d roll graze damage)" % [p.ring_text(p.ring_rarity, p.ring_value),
			"  Forge +%d" % p.ring_forge if p.ring_forge > 0 else "", p.ring_value + p.ring_forge],
			p.rarity_colors[p.ring_rarity], NERVE_RING_ICON, empty_color)
	else:
		_set_row("ring", "Ring     none", empty_color, null, empty_color)
	if p.pet_kind > 0:
		var i: int = p.pet_kind - 1
		_set_row("pet", "Pet      %s\n         %s, %s %d every %.1fs" % [p.pet_names[i], p.pet_passive_text[i],
			"spits" if p.pet_kind == 3 else "bites", p.pet_bite_damage[i], p.pet_bite_cooldown[i]]
			+ "\n         Kept: " + _kept_pets_text(),
			p.pet_colors[i], SCAB_PUP_ICON if p.pet_kind == 2 else null, p.pet_colors[i])
	else:
		_set_row("pet", "Pet      none", empty_color, null, empty_color)
	# The HUD's set line (player.gd _update_set_label).
	var set_text: String = p.set_label.text.trim_prefix("Set: ")
	_set_row("set", "Set      " + set_text, Color(1, 0.95, 0.6, 1) if p.has_set() else empty_color, null, Color(0, 0, 0, 0))
	_set_row("material", "%s   %d" % [p.material_name, p.materials], Color(1, 1, 1, 1), CRYSTAL_ICON, empty_color)
	_refresh_bag()


# The kept pets with the active one in brackets, e.g. "[Scab Pup]  Clot Imp".
func _kept_pets_text() -> String:
	var p: Node = map.player
	var names: Array[String] = []
	for k in p.owned_pets:
		names.append("[%s]" % p.pet_names[k - 1] if k == p.pet_kind else p.pet_names[k - 1])
	var text := "  ".join(names)
	if p.owned_pets.size() > 1:
		text += "   (Up / Down to switch)"
	return text


func _switch_pet(step: int) -> void:
	var p: Node = map.player
	if p.owned_pets.size() < 2:
		return
	var i: int = p.owned_pets.find(p.pet_kind)
	p.equip_pet(p.owned_pets[posmod(i + step, p.owned_pets.size())])
	refresh()


func _refresh_bag() -> void:
	var p: Node = map.player
	bag_heading.text = "Bag   %d / %d" % [p.bag.size(), p.bag_size]
	for i in cells.size():
		var cell: Array = cells[i]
		cell[0].get_parent().visible = i < p.bag_size
		if i < p.bag.size():
			var item: Dictionary = p.bag[i]
			var icon := _item_icon(item)
			cell[0].texture = icon
			cell[0].visible = icon != null
			cell[1].color = p.weapon_arc_color[item.tier - 1]
			cell[1].visible = icon == null
			cell[2].color = p.rarity_colors[item.rarity]
			cell[2].visible = true
		else:
			cell[0].visible = false
			cell[1].visible = false
			cell[2].visible = false
	var first: Control = cells[0][0].get_parent()
	cursor.position = first.position + _cell_offset(selected) - Vector2(4, 4)
	if selected >= p.bag.size():
		detail.text = "Empty slot" if p.bag.size() > 0 else "Bag is empty"
		detail.add_theme_color_override("font_color", empty_color)
		return
	var item: Dictionary = p.bag[selected]
	var text: String = p.gear_text(item.kind, item.tier, item.rarity, item.value)
	if item.forge > 0:
		text += "  Forge +%d" % item.forge
	var worn: Dictionary = p.worn_item(item.kind)
	if worn.is_empty():
		text += "   (nothing worn)"
	else:
		text += "   (worn: %s%s)" % [p.gear_text(worn.kind, worn.tier, worn.rarity, worn.value),
			"  Forge +%d" % worn.forge if worn.forge > 0 else ""]
	text += "\nX: wear   C: salvage for %d %s" % [p.salvage_amounts[item.rarity], p.material_name]
	detail.text = text
	detail.add_theme_color_override("font_color", p.rarity_colors[item.rarity])


# Bag slot i's position from the first slot's (rows of bag_row_cells).
func _cell_offset(i: int) -> Vector2:
	return Vector2(i % bag_row_cells, i / bag_row_cells) * (bag_cell_size + bag_cell_gap)


func _item_icon(item: Dictionary) -> Texture2D:
	match item.kind:
		"armor":
			return ARMOR_ICON
		"ring":
			return NERVE_RING_ICON
	return CALLUS_BLADE_ICON if item.tier == 1 else null


# icon null shows a colored square in its place (gear without painted art yet).
func _set_row(slot: String, text: String, color: Color, icon: Texture2D, swatch_color: Color) -> void:
	var row: Array = rows[slot]
	row[0].texture = icon
	row[0].visible = icon != null
	row[1].color = swatch_color
	row[1].visible = icon == null
	row[2].text = text
	row[2].add_theme_color_override("font_color", color)


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	return label
