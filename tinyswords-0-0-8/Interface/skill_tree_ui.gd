extends Control

@onready var close_button: TextureButton = $Overlay/Paper/CloseButton
@onready var sp_label: Label = $Overlay/Paper/SPLabel
@onready var tooltip_panel: PanelContainer = $Overlay/Paper/Tooltip
@onready var tooltip_name: Label = $Overlay/Paper/Tooltip/VBox/Name
@onready var tooltip_cost: Label = $Overlay/Paper/Tooltip/VBox/Cost
@onready var tooltip_desc: Label = $Overlay/Paper/Tooltip/VBox/Desc
@onready var title_label: Label = $Overlay/Paper/Title

# Updated Paths
@onready var tree_canvas: Control = $Overlay/Paper/Content/TreeCanvas
@onready var example_node: Control = $Overlay/Paper/Content/TreeCanvas/SkillNode_Example
@onready var paper: NinePatchRect = $Overlay/Paper

var _prev_paused: bool = false
var _skill_defs: Array[Dictionary] = []
var _skill_nodes: Dictionary = {}
var _skill_levels: Dictionary = {}
var _skill_points: int = 0
var _paper_origin_pos: Vector2 = Vector2.ZERO
var _paper_tween: Tween
var _connection_lines: Array[Line2D] = []
var _connection_defs: Array[Dictionary] = []
var _category_labels: Array[Label] = []

# Mock logic for icons
const DEFAULT_ICON = preload("res://Assets/UI/Icons/Icon_09.png")

const SKILL_WORKER_SPEED_MULTIPLIERS: Array[float] = [1.1, 1.2, 1.4, 1.6, 1.8, 2.0]
const SKILL_CARRY_CAPACITIES: Array[int] = [2, 3, 4, 5, 6]
const SKILL_CARRY_COSTS: Array[int] = [2, 4, 8, 16, 20]
const SKILL_CHANCE_STEP: float = 0.02
const SKILL_CHANCE_CAP: float = 0.20
const SKILL_BASE_SHEEP_MUTATION_CHANCE: float = 0.02
const SKILL_BASE_REDWOOD_SEED_CHANCE: float = 0.04
const SKILL_BASE_RAINBOW_GOLD_CHANCE: float = 0.04

const CATEGORIES = ["主角专精", "羊群物流", "基建能量", "基因变异"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_paper_origin_pos = paper.position
	close_button.pressed.connect(close_ui)
	_apply_shared_label_settings()
	_build_skill_defs()
	_build_layout() # New method to build the whole 4-column layout
	_hide_tooltip()

func _apply_shared_label_settings() -> void:
	var ref_label = get_node_or_null("../TopBar/SkillButton/Label")
	if ref_label == null or not (ref_label is Label):
		return
	var ref_settings = (ref_label as Label).label_settings
	if ref_settings == null:
		return
	title_label.label_settings = ref_settings
	sp_label.label_settings = ref_settings
	tooltip_name.label_settings = ref_settings
	tooltip_cost.label_settings = ref_settings
	tooltip_desc.label_settings = ref_settings
	var example_label = example_node.get_node_or_null("Label")
	if example_label != null and example_label is Label:
		(example_label as Label).label_settings = ref_settings

func toggle() -> void:
	if visible:
		close_ui()
	else:
		open_ui()

func open_ui() -> void:
	if visible:
		return
	_prev_paused = get_tree().paused
	get_tree().paused = true
	visible = true
	_refresh_from_level()
	_hide_tooltip()
	if _paper_tween != null and _paper_tween.is_running():
		_paper_tween.kill()
	paper.position = _paper_origin_pos + Vector2(0, 50)
	paper.modulate.a = 0.0
	_paper_tween = create_tween().set_parallel(true)
	_paper_tween.tween_property(paper, "position", _paper_origin_pos, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_paper_tween.tween_property(paper, "modulate:a", 1.0, 0.2)

func close_ui() -> void:
	if not visible:
		return
	_hide_tooltip()
	if _paper_tween != null and _paper_tween.is_running():
		_paper_tween.kill()
	_paper_tween = create_tween().set_parallel(true)
	_paper_tween.tween_property(paper, "position", _paper_origin_pos + Vector2(0, 50), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_paper_tween.tween_property(paper, "modulate:a", 0.0, 0.2)
	_paper_tween.chain().tween_callback(func():
		visible = false
		get_tree().paused = _prev_paused
	)

func set_skill_points(value: int) -> void:
	_skill_points = max(0, value)
	sp_label.text = "可用 SP: " + str(_skill_points)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_tech_tree") and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()
		return
	if visible and event.is_action_pressed("ui_cancel") and not event.is_echo():
		close_ui()
		get_viewport().set_input_as_handled()

func _build_skill_defs() -> void:
	# Define skills. tier = vertical depth (0 is top).
	_skill_defs = [
		# 1. 主角专精
		{"key": "hero_base", "name": "基础训练", "category": "主角专精", "tier": 0, "requires": []},
		{"key": "hero_adv", "name": "进阶战法", "category": "主角专精", "tier": 1, "requires": ["hero_base"]},
		
		# 2. 羊群物流
		{"key": "worker_speed", "name": "工人速度", "category": "羊群物流", "tier": 0, "requires": []},
		{"key": "carry", "name": "搬运容量", "category": "羊群物流", "tier": 1, "requires": ["worker_speed"]},
		
		# 3. 基建能量
		{"key": "base_eff", "name": "能源效率", "category": "基建能量", "tier": 0, "requires": []},
		
		# 4. 基因变异
		{"key": "sheep_mutation", "name": "羊基因变异", "category": "基因变异", "tier": 0, "requires": []},
		{"key": "redwood_seed", "name": "红木种子掉率", "category": "基因变异", "tier": 1, "requires": ["sheep_mutation"]},
		{"key": "rainbow_gold", "name": "彩色矿石掉率", "category": "基因变异", "tier": 2, "requires": ["redwood_seed"]}
	]

func _build_layout() -> void:
	if tree_canvas == null or example_node == null:
		return
	
	# Clean up
	for c in tree_canvas.get_children():
		if c != example_node:
			c.queue_free()
	
	_connection_lines.clear()
	_connection_defs.clear()
	_skill_nodes.clear()
	_category_labels.clear()
	
	# Layout Constants
	var canvas_width = 1024.0 # Approximate usable width
	var col_count = 4
	var col_width = canvas_width / col_count
	var start_y = 100.0 # Start below headers
	var row_height = 130.0
	var header_settings: LabelSettings = null
	if title_label != null and title_label.label_settings != null:
		header_settings = title_label.label_settings.duplicate()
		header_settings.font_size = 26
		header_settings.outline_size = 0
		header_settings.outline_color = Color(0, 0, 0, 0)
		header_settings.font_color = Color(0, 0, 0, 1)
	
	# 1. Create Column Headers
	for i in range(col_count):
		var cat_name = CATEGORIES[i]
		var lbl = Label.new()
		lbl.text = cat_name
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if header_settings != null:
			lbl.label_settings = header_settings
		else:
			lbl.add_theme_font_size_override("font_size", 24)
			lbl.add_theme_color_override("font_color", Color(0, 0, 0, 1))
		
		# Position: Top of column
		lbl.position = Vector2(i * col_width, 10)
		lbl.custom_minimum_size = Vector2(col_width, 40)
		
		tree_canvas.add_child(lbl)
		_category_labels.append(lbl)
	
	# 2. Create Skill Nodes
	for def in _skill_defs:
		var key = String(def.get("key", ""))
		if key.is_empty(): continue
		
		var cat = String(def.get("category", ""))
		var tier = int(def.get("tier", 0))
		
		var col_idx = CATEGORIES.find(cat)
		if col_idx == -1: col_idx = 0 # Default fallback
		
		var node = example_node.duplicate() as Control
		node.name = "SkillNode_" + key
		node.visible = true
		
		# Position
		# Center in column: (col_idx * col_width) + (col_width / 2)
		var center_x = (col_idx * col_width) + (col_width * 0.5)
		var pos_y = start_y + (tier * row_height)
		
		node.position = Vector2(center_x, pos_y)
		tree_canvas.add_child(node)
		
		var btn = node.get_node("Button") as TextureButton
		var icon = btn.get_node("Icon") as TextureRect
		var lbl = node.get_node("Label") as Label
		
		lbl.text = String(def.get("name", ""))
		icon.texture = DEFAULT_ICON
		
		if btn != null:
			btn.pressed.connect(func(): _try_buy(key))
			btn.mouse_entered.connect(func(): _show_skill_tooltip(btn, key))
			btn.mouse_exited.connect(_hide_tooltip)
			
		_skill_nodes[key] = {
			"root": node,
			"button": btn,
			"icon": icon,
			"label": lbl,
			"category": cat,
			"name": String(def.get("name", "")),
			"requires": def.get("requires", [])
		}
		
		var prereqs = def.get("requires", [])
		if typeof(prereqs) == TYPE_ARRAY and not (prereqs as Array).is_empty():
			for p in prereqs:
				_connection_defs.append({"from": String(p), "to": key})
				
	example_node.visible = false
	
	# 3. Create Connections (Vertical Lines)
	_rebuild_connections()

func _rebuild_connections() -> void:
	for line in _connection_lines:
		if is_instance_valid(line):
			line.queue_free()
	_connection_lines.clear()
	
	for conn in _connection_defs:
		var from_key = conn["from"]
		var to_key = conn["to"]
		
		var node_from = _skill_nodes.get(from_key)
		var node_to = _skill_nodes.get(to_key)
		
		if node_from and node_to:
			var root_from = node_from["root"]
			var root_to = node_to["root"]
			
			var line = Line2D.new()
			line.width = 4.0
			line.default_color = Color(0.4, 0.4, 0.4, 0.5) # Default dim
			
			line.add_point(root_from.position)
			line.add_point(root_to.position)
			
			tree_canvas.add_child(line)
			tree_canvas.move_child(line, 0) # Back
			_connection_lines.append(line)
			
			line.set_meta("from_key", from_key)
			line.set_meta("to_key", to_key)

func _get_level_node() -> Node:
	return get_tree().get_first_node_in_group(&"level")

func _refresh_from_level() -> void:
	var level = _get_level_node()
	if level == null:
		return
	
	if level.has_method("get_skill_points"):
		set_skill_points(int(level.call("get_skill_points")))
		
	if level.has_method("get_skill_levels"):
		var d = level.call("get_skill_levels")
		if typeof(d) == TYPE_DICTIONARY:
			_skill_levels = d as Dictionary
			
	# Update Nodes
	for k in _skill_nodes.keys():
		var info := _skill_nodes[k] as Dictionary
		var root = info.get("root")
		if root == null or not is_instance_valid(root):
			continue
			
		var skill_key = String(k)
		var current_level = max(0, int(_skill_levels.get(skill_key, 0)))
		var cost = _get_next_cost(skill_key, current_level)
		
		var unlocked = true
		var prereqs = info.get("requires", [])
		if typeof(prereqs) == TYPE_ARRAY:
			for p in prereqs:
				var pk = String(p)
				if max(0, int(_skill_levels.get(pk, 0))) <= 0:
					unlocked = false
					break
		
		var btn = info.get("button") as TextureButton
		var icon = info.get("icon") as TextureRect
		var lbl = info.get("label") as Label
		
		if btn != null:
			btn.disabled = (not unlocked) or cost <= 0 or _skill_points < cost
			
			if not unlocked:
				btn.modulate = Color(0.3, 0.3, 0.3, 1.0)
				icon.modulate = Color(0.2, 0.2, 0.2, 1.0)
				lbl.modulate = Color(0.5, 0.5, 0.5, 1.0)
			elif current_level > 0:
				btn.modulate = Color(1, 1, 1, 1)
				icon.modulate = Color(1, 1, 1, 1)
				lbl.modulate = Color(1, 0.9, 0.6, 1)
			else:
				btn.modulate = Color(0.8, 0.8, 0.8, 1)
				icon.modulate = Color(0.7, 0.7, 0.7, 1)
				lbl.modulate = Color(1, 1, 1, 1)

	# Update Connections
	for line in _connection_lines:
		if not is_instance_valid(line):
			continue
		var from_key = line.get_meta("from_key")
		var from_lvl = max(0, int(_skill_levels.get(from_key, 0)))
		
		if from_lvl > 0:
			line.default_color = Color(0.8, 0.8, 0.6, 0.8)
		else:
			line.default_color = Color(0.2, 0.2, 0.2, 0.5)

func _get_next_cost(key: String, current_lvl: int) -> int:
	if key == "carry":
		if current_lvl >= SKILL_CARRY_CAPACITIES.size(): return -1
		return SKILL_CARRY_COSTS[current_lvl]
	if current_lvl >= 5: return -1
	return 1 + current_lvl

func _try_buy(key: String) -> void:
	var level = _get_level_node()
	if level == null: return
	if level.has_method("try_buy_skill"):
		level.call("try_buy_skill", key)
		_refresh_from_level()

func _show_skill_tooltip(node: Control, key: String) -> void:
	if tooltip_panel == null: return
	var info = _skill_nodes.get(key)
	if info == null: return
	
	var lvl = int(_skill_levels.get(key, 0))
	var cost = _get_next_cost(key, lvl)
	var skill_name = info.get("name", "")
	
	tooltip_name.text = skill_name + " (Lv." + str(lvl) + ")"
	if cost < 0:
		tooltip_cost.text = "已满级"
	else:
		tooltip_cost.text = "消耗 SP: " + str(cost)
		
	var desc = "暂无描述"
	if key == "worker_speed": desc = "提升工人移动速度"
	elif key == "carry": desc = "提升工人最大搬运量"
	elif key == "sheep_mutation": desc = "解锁基因变异功能"
	
	tooltip_desc.text = desc
	
	# Adjust tooltip position to keep it on screen
	var global_pos = node.global_position
	# Default to right side
	tooltip_panel.global_position = global_pos + Vector2(70, 0)
	
	# If too far right, flip to left
	if tooltip_panel.global_position.x + tooltip_panel.size.x > get_viewport_rect().size.x:
		tooltip_panel.global_position = global_pos - Vector2(tooltip_panel.size.x + 10, 0)
		
	tooltip_panel.visible = true

func _hide_tooltip() -> void:
	if tooltip_panel != null:
		tooltip_panel.visible = false
