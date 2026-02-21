extends Control

@onready var close_button: TextureButton = $Overlay/Paper/CloseButton
@onready var sp_label: Label = $Overlay/Paper/SPLabel
@onready var tooltip_panel: PanelContainer = $Overlay/Paper/Tooltip
@onready var tooltip_name: Label = $Overlay/Paper/Tooltip/VBox/Name
@onready var tooltip_cost: Label = $Overlay/Paper/Tooltip/VBox/Cost
@onready var tooltip_desc: Label = $Overlay/Paper/Tooltip/VBox/Desc
@onready var tree_canvas: Control = $Overlay/Paper/Content/Right/Scroll/TreeCanvas
@onready var example_node: Control = $Overlay/Paper/Content/Right/Scroll/TreeCanvas/SkillNode_Example

@onready var tab_hero: Button = $Overlay/Paper/Content/Left/Tabs/TabHero
@onready var tab_sheep: Button = $Overlay/Paper/Content/Left/Tabs/TabSheep
@onready var tab_base: Button = $Overlay/Paper/Content/Left/Tabs/TabBase
@onready var tab_gene: Button = $Overlay/Paper/Content/Left/Tabs/TabGene

var _prev_paused: bool = false
var _current_category: String = ""
var _skill_defs: Array[Dictionary] = []
var _skill_nodes: Dictionary = {}
var _skill_levels: Dictionary = {}
var _skill_points: int = 0

const SKILL_WORKER_SPEED_MULTIPLIERS: Array[float] = [1.1, 1.2, 1.4, 1.6, 1.8, 2.0]
const SKILL_CARRY_CAPACITIES: Array[int] = [2, 3, 4, 5, 6]
const SKILL_CARRY_COSTS: Array[int] = [2, 4, 8, 16, 20]
const SKILL_CHANCE_STEP: float = 0.02
const SKILL_CHANCE_CAP: float = 0.20
const SKILL_BASE_SHEEP_MUTATION_CHANCE: float = 0.02
const SKILL_BASE_REDWOOD_SEED_CHANCE: float = 0.04
const SKILL_BASE_RAINBOW_GOLD_CHANCE: float = 0.04

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_button.pressed.connect(close_ui)
	tab_hero.pressed.connect(func(): _select_category("1. 主角专精"))
	tab_sheep.pressed.connect(func(): _select_category("2. 羊群物流"))
	tab_base.pressed.connect(func(): _select_category("3. 基建能量"))
	tab_gene.pressed.connect(func(): _select_category("4. 基因变异"))
	_build_skill_defs()
	_build_skill_nodes()
	_select_category("2. 羊群物流")
	_hide_tooltip()

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

func close_ui() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _prev_paused
	_hide_tooltip()

func set_skill_points(value: int) -> void:
	_skill_points = max(0, value)
	sp_label.text = "可用 SP: " + str(_skill_points)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_tech_tree") and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()

func _build_skill_defs() -> void:
	_skill_defs = [
		{"key": "worker_speed", "name": "工人速度", "category": "2. 羊群物流"},
		{"key": "carry", "name": "搬运容量", "category": "2. 羊群物流"},
		{"key": "sheep_mutation", "name": "羊基因变异", "category": "4. 基因变异"},
		{"key": "redwood_seed", "name": "红木种子掉率", "category": "4. 基因变异"},
		{"key": "rainbow_gold", "name": "彩色矿石掉率", "category": "4. 基因变异"}
	]

func _build_skill_nodes() -> void:
	if tree_canvas == null or example_node == null:
		return
	for k in _skill_nodes.keys():
		var n = _skill_nodes[k].get("root")
		if n != null and is_instance_valid(n):
			n.queue_free()
	_skill_nodes.clear()
	var idx = 0
	for def in _skill_defs:
		var key = String(def.get("key", ""))
		if key.is_empty():
			continue
		var node = example_node.duplicate() as Control
		node.name = "SkillNode_" + key
		node.position = Vector2(40.0, 40.0 + float(idx) * 140.0)
		tree_canvas.add_child(node)
		var btn = node.get_node_or_null("Button") as TextureButton
		var lbl = node.get_node_or_null("Label") as Label
		if btn != null:
			btn.pressed.connect(func(): _try_buy(key))
			btn.mouse_entered.connect(func(): _show_skill_tooltip(btn, key))
			btn.mouse_exited.connect(_hide_tooltip)
		_skill_nodes[key] = {
			"root": node,
			"button": btn,
			"label": lbl,
			"category": String(def.get("category", "")),
			"name": String(def.get("name", ""))
		}
		idx += 1
	example_node.visible = false

func _select_category(category: String) -> void:
	_current_category = category
	for k in _skill_nodes.keys():
		var info := _skill_nodes[k] as Dictionary
		var root = info.get("root")
		if root != null and is_instance_valid(root):
			root.visible = String(info.get("category", "")) == category
	_refresh_from_level()

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
	for k in _skill_nodes.keys():
		var info := _skill_nodes[k] as Dictionary
		var root = info.get("root")
		if root == null or not is_instance_valid(root):
			continue
		var current_level = max(0, int(_skill_levels.get(String(k), 0)))
		var cost = _get_next_cost(String(k), current_level)
		var btn = info.get("button") as TextureButton
		if btn != null:
			btn.disabled = cost <= 0 or _skill_points < cost
			btn.modulate = Color(0.6, 0.6, 0.6, 0.9) if btn.disabled else Color(1, 1, 1, 1)
		if not root.visible:
			continue
		var lbl = info.get("label") as Label
		if lbl == null:
			continue
		lbl.text = _get_skill_label_text(String(k), String(info.get("name", "")))

func _get_skill_label_text(key: String, display_name: String) -> String:
	var level = max(0, int(_skill_levels.get(key, 0)))
	if key == "worker_speed":
		return display_name + " Lv." + str(level) + "/" + str(SKILL_WORKER_SPEED_MULTIPLIERS.size())
	if key == "carry":
		var cap = 1
		if level > 0:
			cap = int(SKILL_CARRY_CAPACITIES[clamp(level - 1, 0, SKILL_CARRY_CAPACITIES.size() - 1)])
		return display_name + " " + str(cap)
	var chance = _get_skill_chance(key, level)
	return display_name + " " + str(int(round(chance * 100.0))) + "%"

func _get_skill_chance(key: String, level: int) -> float:
	if key == "sheep_mutation":
		return min(SKILL_CHANCE_CAP, SKILL_BASE_SHEEP_MUTATION_CHANCE + float(level) * SKILL_CHANCE_STEP)
	if key == "redwood_seed":
		return min(SKILL_CHANCE_CAP, SKILL_BASE_REDWOOD_SEED_CHANCE + float(level) * SKILL_CHANCE_STEP)
	if key == "rainbow_gold":
		return min(SKILL_CHANCE_CAP, SKILL_BASE_RAINBOW_GOLD_CHANCE + float(level) * SKILL_CHANCE_STEP)
	return 0.0

func _get_next_cost(key: String, current_level: int) -> int:
	if key == "worker_speed":
		return 1 if current_level < SKILL_WORKER_SPEED_MULTIPLIERS.size() else 0
	if key == "carry":
		if current_level >= SKILL_CARRY_CAPACITIES.size():
			return 0
		return int(SKILL_CARRY_COSTS[clamp(current_level, 0, SKILL_CARRY_COSTS.size() - 1)])
	if key == "sheep_mutation":
		return 1 if _get_skill_chance(key, current_level) < SKILL_CHANCE_CAP else 0
	if key == "redwood_seed":
		return 1 if _get_skill_chance(key, current_level) < SKILL_CHANCE_CAP else 0
	if key == "rainbow_gold":
		return 1 if _get_skill_chance(key, current_level) < SKILL_CHANCE_CAP else 0
	return 0

func _get_skill_desc(key: String, current_level: int) -> String:
	if key == "worker_speed":
		var next_mult = 1.0
		if current_level < SKILL_WORKER_SPEED_MULTIPLIERS.size():
			next_mult = float(SKILL_WORKER_SPEED_MULTIPLIERS[current_level])
		return "提升工人移动速度倍率，最高 x2.0。下一次目标: x" + str(snapped(next_mult, 0.01))
	if key == "carry":
		var next_cap = 1
		if current_level < SKILL_CARRY_CAPACITIES.size():
			next_cap = int(SKILL_CARRY_CAPACITIES[current_level])
		return "提升工人单次携带数量，最高 6。下一次目标: " + str(next_cap)
	if key == "sheep_mutation":
		return "释放羊羔的变异概率，每级 +2%，上限 20%。"
	if key == "redwood_seed":
		return "树木额外掉落红木种子概率，每级 +2%，上限 20%。"
	if key == "rainbow_gold":
		return "金矿石变为彩色矿石概率，每级 +2%，上限 20%。"
	return ""

func _try_buy(skill_key: String) -> void:
	var level = _get_level_node()
	if level == null:
		return
	if level.has_method("try_buy_skill"):
		var ok = bool(level.call("try_buy_skill", skill_key))
		if ok:
			_refresh_from_level()

func _show_skill_tooltip(for_button: Control, skill_key: String) -> void:
	var info := _skill_nodes.get(skill_key, {}) as Dictionary
	var display_name = String(info.get("name", skill_key))
	var current_level = max(0, int(_skill_levels.get(skill_key, 0)))
	var cost = _get_next_cost(skill_key, current_level)
	var desc = _get_skill_desc(skill_key, current_level)
	tooltip_name.text = display_name
	tooltip_cost.text = "已满级" if cost <= 0 else ("消耗 SP: " + str(max(0, cost)) + "  (当前: " + str(_skill_points) + ")")
	tooltip_desc.text = desc
	tooltip_panel.visible = true
	var rect = for_button.get_global_rect()
	tooltip_panel.global_position = rect.position + Vector2(rect.size.x + 10.0, 0.0)

func _hide_tooltip() -> void:
	tooltip_panel.visible = false
