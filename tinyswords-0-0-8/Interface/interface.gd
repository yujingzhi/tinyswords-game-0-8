extends CanvasLayer
class_name Interface # 注册大管家
# UI 总控：背包、快捷栏、血量/体力条的更新

# --- 🔗 引用区域 ---
@onready var slots_container: HBoxContainer = $Avatar/HBoxContainer
@onready var inventory_panel: TileMapLayer = $TileMapLayer
@onready var grid_container: GridContainer = $TileMapLayer/InventoryGrid
@onready var player_health_bar: TextureProgressBar = $PlayerHealthBar/Fill
@onready var player_exp_bar_root: TextureProgressBar = $PlayerStaminaBar
@onready var player_exp_bar: TextureProgressBar = $PlayerStaminaBar/Fill
@onready var quickbar_container: HBoxContainer = $QuickBar
@onready var wood_label: Label = $ResourceHUD/WoodLabel
@onready var gold_label: Label = $ResourceHUD/GoldLabel
@onready var meat_label: Label = $ResourceHUD/MeatLabel
@onready var save_button: TextureButton = $TopBar/SaveButton
@onready var tech_ui: Control = $SkillTreeUI

var meta_hud_panel: PanelContainer
var meta_hud_container: VBoxContainer
var wave_meta_label: Label
var energy_meta_label: Label
var cpu_meta_label: Label
var logistics_meta_label: Label
var exp_meta_label: Label
var warehouse_meta_label: Label
var objective_meta_label: Label
var hint_meta_label: Label
var meta_hud_toggle_button: Button
var meta_hud_expanded: bool = false
var meta_hud_anim_tween: Tween
var exp_level_label: Label
var exp_name_label: Label
var exp_need_label: Label
var build_buttons_container: HBoxContainer
var build_warehouse_button: TextureButton
var camera_recenter_tween: Tween

var end_overlay: ColorRect
var end_title_label: Label
var end_stats_label: Label
var restart_button: Button
var quit_button: Button
var save_slot_select: OptionButton
var save_slot_edit: LineEdit
var save_status_label: Label
var save_overwrite_button: Button
var save_as_button: Button
var save_load_button: Button
var save_rename_button: Button
var save_popup_overlay: ColorRect
var save_popup_panel: PanelContainer
var save_popup_tween: Tween
var save_overwrite_tween: Tween
var save_load_tween: Tween
# 这些节点分别对应 UI 中的背包、格子和血条等元素

# --- 🔥 配置区域 ---
# 【检查！】必须在编辑器里把 InventorySlot.tscn 拖给它
@export var slot_scene: PackedScene 
# slot_scene 是背包格子实例的预制体

# 字典：教 UI 如何将 "wood" 映射成对应的图片
@onready var lamb_icon: Texture2D = _build_lamb_icon()
@onready var item_icons: Dictionary = {
	"wood": preload("res://Base_Object/Wood_Resource.png"), 
	"gold": preload("res://Base_Object/Gold_Resource.png"),
	"meat": preload("res://Base_Object/Resources/Meat/Meat_Resource.png"),
	"lamb": lamb_icon
}
# 用物品类型字符串映射到图标贴图
var consume_fx_defs: Array[Dictionary] = [
	{"texture": preload("res://Assets/FX/Particles/Fire_01.png"), "frames": 8},
	{"texture": preload("res://Assets/FX/Particles/Fire_02.png"), "frames": 10},
	{"texture": preload("res://Assets/FX/Particles/Fire_03.png"), "frames": 12},
	{"texture": preload("res://Assets/FX/Particles/Water Splash.png"), "frames": 9}
]
# 消耗物品时的特效集合

# --- 🌟 数据中枢 ---
var origin_pos: Vector2
var total_slots: int = 21 # 背包总共有多少格子
const SLOT_SIZE = Vector2(96, 96)
const QUICKBAR_SIZE = Vector2(72, 72)
const META_HUD_MARGIN = 12.0
const META_HUD_SIZE_EXPANDED = Vector2(520, 210)
const META_HUD_SIZE_COLLAPSED = Vector2(320, 56)
const META_HUD_SCALE_EXPANDED = Vector2(1.0, 1.0)
const META_HUD_SCALE_COLLAPSED = Vector2(0.97, 0.97)
# SLOT_SIZE/QUICKBAR_SIZE 控制格子的最小显示尺寸

# 💡【核心数据】这是你真正的背包，所有加减全在这发生
var inventory_data: Dictionary = {} 
var quickbar_items: Array[String] = ["", "", "", "", ""]
# inventory_data 保存“物品类型 -> 数量”

# --- 🚀 初始化 ---
func _ready() -> void:
	# 注册到 interface 分组，方便其他脚本调用 UI 更新
	add_to_group("interface")
	process_mode = Node.PROCESS_MODE_ALWAYS
	var avatar = get_node_or_null("Avatar") as Control
	if avatar:
		avatar.mouse_filter = Control.MOUSE_FILTER_STOP
		avatar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if not avatar.gui_input.is_connected(_on_avatar_gui_input):
			avatar.gui_input.connect(_on_avatar_gui_input)
	
	# 💡 引擎哲学：游戏一开始，默认不拿任何武器 (-1 代表空手)
	update_weapon_indicator(-1) 
	
	if inventory_panel:
		origin_pos = inventory_panel.position
		inventory_panel.visible = false
		inventory_panel.modulate.a = 0
		# 游戏开始时刷新一次空背包
		refresh_inventory_ui()
	_refresh_quickbar_ui()
	_update_resource_hud()
	_build_meta_hud()
	_build_exp_progress()
	_build_build_buttons()
	_build_end_overlay()
	if save_button:
		save_button.visible = false
		save_button.disabled = true
	call_deferred("_sync_player_health")

func _build_lamb_icon() -> Texture2D:
	var texture: Texture2D = preload("res://Base_Object/Animals/Sheep/Sheep_Idle.png")
	var frame_count = 6
	var frame_width = texture.get_width() / float(frame_count)
	var atlas = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(0, 0, frame_width, texture.get_height())
	return atlas

func _unhandled_input(event: InputEvent) -> void:
	if end_overlay and end_overlay.visible:
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.pressed and not key_event.echo:
				if key_event.keycode == KEY_R:
					_restart_run()
				elif key_event.keycode == KEY_Q or key_event.keycode == KEY_ESCAPE:
					_quit_run()
		return
	if event is InputEventKey:
		var key_event_save := event as InputEventKey
		if key_event_save.pressed and not key_event_save.echo and key_event_save.keycode == KEY_F11:
			var mode = DisplayServer.window_get_mode()
			var next_mode = DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(next_mode)
			get_viewport().set_input_as_handled()
			return
	# 处理背包开关与快捷栏按键
	if event.is_action_pressed("ui_cancel"):
		if inventory_panel and inventory_panel.visible and inventory_panel.modulate.a > 0.1:
			_close_inventory_animation()
		return
	if event.is_action_pressed("toggle_inventory"):
		_on_bag_button_pressed()
	elif event.is_action_pressed("quickbar_1"):
		use_quick_slot(0)
	elif event.is_action_pressed("quickbar_2"):
		use_quick_slot(1)
	elif event.is_action_pressed("quickbar_3"):
		use_quick_slot(2)
	elif event.is_action_pressed("quickbar_4"):
		use_quick_slot(3)
	elif event.is_action_pressed("quickbar_5"):
		use_quick_slot(4)

func _on_avatar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_recenter_camera_on_player()

# --- 📥 数据更新与接收 ---
# 这个方法会被外界（如 PhysicItem）呼叫
func add_item(item_type: String, amount: int) -> void:
	# 增加某种物品数量
	if item_type == "redwood":
		item_type = "wood"
		amount *= 5
	elif item_type == "red_meat":
		item_type = "meat"
		amount *= 5
	elif item_type == "rainbow_gold":
		item_type = "gold"
		amount *= 5
	# 1. 如果是第一次捡到这玩意，给字典开个户
	if not inventory_data.has(item_type):
		inventory_data[item_type] = 0
		
	# 2. 数字累加！
	inventory_data[item_type] += amount
	print("🎒 背包数据更新 | 类型: ", item_type, " | 总数: ", inventory_data[item_type])
	
	# 3. 数据算完了，通知下游去刷新显示
	refresh_inventory_ui()

# --- 🔄 UI 刷新器 ---
func refresh_inventory_ui() -> void:
	# 重建背包格子并填充数据
	# 1. 暴力美学：清空网格里所有的老格子
	for child in grid_container.get_children():
		child.queue_free()
	
	# 2. 拿到现在有的物品种类名单，比如 ["wood", "gold"]
	var item_keys = inventory_data.keys()
	
	# 3. 循环 21 次铺满格子
	for i in range(total_slots):
		var slot = slot_scene.instantiate() as InventorySlot
		slot.custom_minimum_size = SLOT_SIZE 
		slot.slot_role = "inventory"
		slot.slot_index = i
		grid_container.add_child(slot)
		
		# 4. 判断逻辑
		if i < item_keys.size():
			# 只要种类名单还没循环完，就把对应的数据填进去
			var key = item_keys[i]
			var icon = item_icons.get(key, null)
			var count = inventory_data[key]
			slot.update_slot(icon, count, key)
		else:
			# 种类发完了，剩下的全是空格子
			slot.update_slot(null, 0, "")
	_auto_fill_quickbar_from_inventory()
	_refresh_quickbar_ui()
	_update_resource_hud()

func _update_resource_hud() -> void:
	if wood_label:
		wood_label.text = "木材 " + str(inventory_data.get("wood", 0))
	if gold_label:
		gold_label.text = "矿石 " + str(inventory_data.get("gold", 0))
	if meat_label:
		meat_label.text = "肉 " + str(inventory_data.get("meat", 0))

func update_meta_hud(waves_survived: int, next_wave_in: float, enemies_alive: int, _next_wave_size: int, energy_points: float, energy_decay_per_sec: float, _energy_consumes_wood: bool, worker_speed_multiplier: float, logistics_enabled: bool, _map_seed: int, objective_text: String, hint_text: String, player_level: int, player_exp: int, exp_to_next: int, skill_points: int, warehouse_count: int, workers_current: int, workers_cap: int, next_warehouse_wood: int, next_warehouse_gold: int, next_warehouse_meat: int, next_warehouse_sp: int, placing_warehouse: bool) -> void:
	if meta_hud_container == null:
		return
	if wave_meta_label:
		wave_meta_label.text = "第" + str(waves_survived) + "波  ·  下波 " + str(int(ceil(next_wave_in))) + "s  ·  敌人 " + str(enemies_alive)
	if energy_meta_label:
		energy_meta_label.text = "能量 " + str(int(round(energy_points))) + "  (-" + str(snapped(energy_decay_per_sec, 0.1)) + "/s)"
	if cpu_meta_label:
		cpu_meta_label.text = "物流 " + ("在线" if logistics_enabled else "离线") + "  ·  工人速度 x" + str(snapped(worker_speed_multiplier, 0.01))
	if logistics_meta_label:
		var place_text = "  ·  摆放中" if placing_warehouse else ""
		logistics_meta_label.text = "仓库 " + str(warehouse_count) + "  ·  工人 " + str(workers_current) + "/" + str(workers_cap) + place_text
	if exp_meta_label:
		exp_meta_label.text = "Lv." + str(player_level) + "  ·  经验 " + str(player_exp) + "/" + str(exp_to_next) + "  ·  SP " + str(max(0, skill_points))
	if warehouse_meta_label:
		warehouse_meta_label.text = "建造仓库: 木" + str(next_warehouse_wood) + "  矿" + str(next_warehouse_gold) + "  肉" + str(next_warehouse_meat) + "  SP " + str(max(0, next_warehouse_sp))
	if tech_ui != null and is_instance_valid(tech_ui) and tech_ui.has_method("set_skill_points"):
		tech_ui.call("set_skill_points", max(0, skill_points))
	if objective_meta_label:
		var t = _strip_hud_prefix(objective_text, "目标:")
		t = _strip_hud_prefix(t, "目标：")
		objective_meta_label.text = "任务 " + t.strip_edges()
	if hint_meta_label:
		var h = _strip_hud_prefix(hint_text, "建议:")
		h = _strip_hud_prefix(h, "建议：")
		h = _strip_hud_prefix(h, "提示:")
		h = _strip_hud_prefix(h, "提示：")
		hint_meta_label.text = "提示 " + h.strip_edges()

func show_end_screen(won: bool, stats: Dictionary) -> void:
	if end_overlay == null:
		return
	var title = "胜利" if won else "失败"
	if end_title_label:
		end_title_label.text = title
	if end_stats_label:
		var time_sec = float(stats.get("time_sec", 0.0))
		var waves = int(stats.get("waves_survived", 0))
		var kills = int(stats.get("enemy_kills", 0))
		var sp = int(stats.get("skill_points", 0))
		var worker_speed = float(stats.get("worker_speed_multiplier", 1.0))
		var map_seed = int(stats.get("seed", 0))
		var resources = stats.get("resources", {})
		var wood = 0
		var gold = 0
		var meat = 0
		if resources is Dictionary:
			wood = int(resources.get("wood", 0))
			gold = int(resources.get("gold", 0))
			meat = int(resources.get("meat", 0))
		end_stats_label.text = "坚持波数: " + str(waves) + "\n击杀敌人: " + str(kills) + "\nSP: " + str(sp) + "  |  工人速度 x" + str(snapped(worker_speed, 0.01)) + "\n用时: " + _format_time(time_sec) + "\n地图种子: " + str(map_seed) + "\n资源: 木 " + str(wood) + " | 矿 " + str(gold) + " | 肉 " + str(meat) + "\n\nR 重开 | Q/ESC 退出"
	end_overlay.visible = true

func _build_meta_hud() -> void:
	meta_hud_panel = PanelContainer.new()
	meta_hud_panel.name = "MetaHUDPanel"
	meta_hud_panel.anchor_left = 1.0
	meta_hud_panel.anchor_top = 1.0
	meta_hud_panel.anchor_right = 1.0
	meta_hud_panel.anchor_bottom = 1.0
	_set_meta_hud_panel_size(META_HUD_SIZE_EXPANDED)
	meta_hud_panel.scale = META_HUD_SCALE_EXPANDED
	meta_hud_panel.modulate = Color(1, 1, 1, 0.88)
	meta_hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_hud_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(meta_hud_panel)
	meta_hud_container = VBoxContainer.new()
	meta_hud_container.name = "MetaHUD"
	meta_hud_container.anchor_left = 0.0
	meta_hud_container.anchor_top = 0.0
	meta_hud_container.anchor_right = 1.0
	meta_hud_container.anchor_bottom = 1.0
	meta_hud_container.offset_left = 10.0
	meta_hud_container.offset_top = 10.0
	meta_hud_container.offset_right = -10.0
	meta_hud_container.offset_bottom = -10.0
	meta_hud_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_hud_container.process_mode = Node.PROCESS_MODE_ALWAYS
	meta_hud_panel.add_child(meta_hud_container)
	var hud_settings = LabelSettings.new()
	hud_settings.font = preload("res://Fonts/ark-pixel-10px-monospaced-zh_cn.ttf")
	hud_settings.font_size = 18
	hud_settings.outline_size = 5
	hud_settings.outline_color = Color(0.08627451, 0.10980392, 0.18039216, 1)
	wave_meta_label = Label.new()
	energy_meta_label = Label.new()
	cpu_meta_label = Label.new()
	logistics_meta_label = Label.new()
	exp_meta_label = Label.new()
	warehouse_meta_label = Label.new()
	objective_meta_label = Label.new()
	hint_meta_label = Label.new()
	wave_meta_label.text = "第0波  ·  下波 0s  ·  敌人 0"
	energy_meta_label.text = "能量 0  (-0/s)"
	cpu_meta_label.text = "物流 离线  ·  工人速度 x1"
	logistics_meta_label.text = "仓库 0  ·  工人 0/0"
	exp_meta_label.text = "Lv.1  ·  经验 0/0  ·  SP 0"
	warehouse_meta_label.text = "建造仓库: 木0  矿0  肉0  SP 0"
	objective_meta_label.text = "任务 "
	hint_meta_label.text = "提示 "
	wave_meta_label.label_settings = hud_settings
	energy_meta_label.label_settings = hud_settings
	cpu_meta_label.label_settings = hud_settings
	logistics_meta_label.label_settings = hud_settings
	exp_meta_label.label_settings = hud_settings
	warehouse_meta_label.label_settings = hud_settings
	objective_meta_label.label_settings = hud_settings
	hint_meta_label.label_settings = hud_settings
	meta_hud_container.add_child(wave_meta_label)
	meta_hud_container.add_child(energy_meta_label)
	meta_hud_container.add_child(cpu_meta_label)
	meta_hud_container.add_child(logistics_meta_label)
	meta_hud_container.add_child(exp_meta_label)
	meta_hud_container.add_child(warehouse_meta_label)
	meta_hud_container.add_child(objective_meta_label)
	meta_hud_container.add_child(hint_meta_label)
	meta_hud_toggle_button = Button.new()
	meta_hud_toggle_button.text = "收起"
	meta_hud_toggle_button.focus_mode = Control.FOCUS_NONE
	meta_hud_toggle_button.anchor_left = 1.0
	meta_hud_toggle_button.anchor_top = 0.0
	meta_hud_toggle_button.anchor_right = 1.0
	meta_hud_toggle_button.anchor_bottom = 0.0
	meta_hud_toggle_button.offset_left = -74.0
	meta_hud_toggle_button.offset_top = 8.0
	meta_hud_toggle_button.offset_right = -10.0
	meta_hud_toggle_button.offset_bottom = 34.0
	meta_hud_toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	meta_hud_toggle_button.add_theme_font_override("font", hud_settings.font)
	meta_hud_toggle_button.add_theme_font_size_override("font_size", 16)
	meta_hud_panel.add_child(meta_hud_toggle_button)
	meta_hud_toggle_button.pressed.connect(_toggle_meta_hud)
	_apply_meta_hud_state(false)

func _toggle_meta_hud() -> void:
	meta_hud_expanded = not meta_hud_expanded
	_apply_meta_hud_state(true)

func _apply_meta_hud_state(animated: bool) -> void:
	if meta_hud_panel == null:
		return
	var target_size = META_HUD_SIZE_EXPANDED if meta_hud_expanded else META_HUD_SIZE_COLLAPSED
	var target_scale = META_HUD_SCALE_EXPANDED if meta_hud_expanded else META_HUD_SCALE_COLLAPSED
	var target_modulate = Color(1, 1, 1, 0.88) if meta_hud_expanded else Color(1, 1, 1, 0.45)
	if meta_hud_toggle_button:
		meta_hud_toggle_button.text = "收起" if meta_hud_expanded else "展开"
	if wave_meta_label:
		wave_meta_label.visible = true
	if energy_meta_label:
		energy_meta_label.visible = meta_hud_expanded
	if cpu_meta_label:
		cpu_meta_label.visible = meta_hud_expanded
	if logistics_meta_label:
		logistics_meta_label.visible = meta_hud_expanded
	if exp_meta_label:
		exp_meta_label.visible = meta_hud_expanded
	if warehouse_meta_label:
		warehouse_meta_label.visible = meta_hud_expanded
	if objective_meta_label:
		objective_meta_label.visible = meta_hud_expanded
	if hint_meta_label:
		hint_meta_label.visible = meta_hud_expanded
	if meta_hud_anim_tween != null and meta_hud_anim_tween.is_running():
		meta_hud_anim_tween.kill()
	if not animated:
		_set_meta_hud_panel_size(target_size)
		meta_hud_panel.scale = target_scale
		meta_hud_panel.modulate = target_modulate
		call_deferred("_update_meta_hud_pivot")
		return
	meta_hud_anim_tween = create_tween().set_parallel(true)
	var left = -(target_size.x + META_HUD_MARGIN)
	var top = -(target_size.y + META_HUD_MARGIN)
	var right = -META_HUD_MARGIN
	var bottom = -META_HUD_MARGIN
	meta_hud_anim_tween.tween_property(meta_hud_panel, "offset_left", left, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	meta_hud_anim_tween.tween_property(meta_hud_panel, "offset_top", top, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	meta_hud_anim_tween.tween_property(meta_hud_panel, "offset_right", right, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	meta_hud_anim_tween.tween_property(meta_hud_panel, "offset_bottom", bottom, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	meta_hud_anim_tween.tween_property(meta_hud_panel, "scale", target_scale, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	meta_hud_anim_tween.tween_property(meta_hud_panel, "modulate", target_modulate, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	meta_hud_anim_tween.chain().tween_callback(func(): _update_meta_hud_pivot())

func _set_meta_hud_panel_size(size: Vector2) -> void:
	if meta_hud_panel == null:
		return
	meta_hud_panel.offset_left = -(size.x + META_HUD_MARGIN)
	meta_hud_panel.offset_top = -(size.y + META_HUD_MARGIN)
	meta_hud_panel.offset_right = -META_HUD_MARGIN
	meta_hud_panel.offset_bottom = -META_HUD_MARGIN

func _update_meta_hud_pivot() -> void:
	if meta_hud_panel == null:
		return
	meta_hud_panel.pivot_offset = meta_hud_panel.size

func _strip_hud_prefix(text: String, prefix: String) -> String:
	if text.begins_with(prefix):
		return text.substr(prefix.length()).strip_edges()
	return text

func _is_save_popup_visible() -> bool:
	return save_popup_overlay != null and is_instance_valid(save_popup_overlay) and save_popup_overlay.visible

func _toggle_save_popup() -> void:
	if _is_save_popup_visible():
		_hide_save_popup()
	else:
		_show_save_popup()

func _ensure_save_popup() -> void:
	if save_popup_overlay != null and is_instance_valid(save_popup_overlay):
		return
	save_popup_overlay = ColorRect.new()
	save_popup_overlay.name = "SavePopupOverlay"
	save_popup_overlay.color = Color(0, 0, 0, 0.45)
	save_popup_overlay.anchor_left = 0.0
	save_popup_overlay.anchor_top = 0.0
	save_popup_overlay.anchor_right = 1.0
	save_popup_overlay.anchor_bottom = 1.0
	save_popup_overlay.offset_left = 0.0
	save_popup_overlay.offset_top = 0.0
	save_popup_overlay.offset_right = 0.0
	save_popup_overlay.offset_bottom = 0.0
	save_popup_overlay.visible = false
	save_popup_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	save_popup_overlay.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_hide_save_popup()
	)
	add_child(save_popup_overlay)

	save_popup_panel = PanelContainer.new()
	save_popup_panel.name = "SavePopup"
	save_popup_panel.anchor_left = 0.0
	save_popup_panel.anchor_top = 0.0
	save_popup_panel.anchor_right = 0.0
	save_popup_panel.anchor_bottom = 0.0
	save_popup_panel.offset_left = 12.0
	save_popup_panel.offset_top = 72.0
	save_popup_panel.offset_right = 430.0
	save_popup_panel.offset_bottom = 210.0
	save_popup_panel.visible = false
	save_popup_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	save_popup_overlay.add_child(save_popup_panel)

	var save_vbox = VBoxContainer.new()
	save_popup_panel.add_child(save_vbox)
	var row1 = HBoxContainer.new()
	save_vbox.add_child(row1)
	var save_label = Label.new()
	save_label.text = "存档"
	row1.add_child(save_label)
	save_slot_select = OptionButton.new()
	save_slot_select.custom_minimum_size = Vector2(260, 0)
	save_slot_select.item_selected.connect(_on_save_slot_selected)
	row1.add_child(save_slot_select)
	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.pressed.connect(_hide_save_popup)
	row1.add_child(close_btn)

	save_slot_edit = LineEdit.new()
	save_slot_edit.placeholder_text = "输入名称用于另存/重命名"
	save_vbox.add_child(save_slot_edit)

	var row2 = HBoxContainer.new()
	save_vbox.add_child(row2)
	save_overwrite_button = Button.new()
	save_overwrite_button.text = "存档"
	save_overwrite_button.pressed.connect(_on_save_overwrite_pressed)
	row2.add_child(save_overwrite_button)
	save_as_button = Button.new()
	save_as_button.text = "另存"
	save_as_button.pressed.connect(_on_save_as_pressed)
	row2.add_child(save_as_button)
	save_load_button = Button.new()
	save_load_button.text = "读档"
	save_load_button.pressed.connect(_on_save_load_pressed)
	row2.add_child(save_load_button)
	save_rename_button = Button.new()
	save_rename_button.text = "重命名"
	save_rename_button.pressed.connect(_on_save_rename_pressed)
	row2.add_child(save_rename_button)
	var new_run_button = Button.new()
	new_run_button.text = "新开局"
	new_run_button.pressed.connect(_on_new_run_pressed)
	row2.add_child(new_run_button)

	save_status_label = Label.new()
	save_status_label.text = ""
	save_vbox.add_child(save_status_label)

func _show_save_popup() -> void:
	_ensure_save_popup()
	_refresh_save_ui()
	if save_popup_tween != null and save_popup_tween.is_running():
		save_popup_tween.kill()
	save_popup_overlay.visible = true
	save_popup_overlay.modulate.a = 0.0
	save_popup_panel.visible = true
	save_popup_panel.modulate.a = 0.0
	save_popup_tween = create_tween().set_parallel(true)
	save_popup_tween.tween_property(save_popup_overlay, "modulate:a", 1.0, 0.12)
	save_popup_tween.tween_property(save_popup_panel, "modulate:a", 1.0, 0.12)

func _hide_save_popup() -> void:
	if not _is_save_popup_visible():
		return
	if save_popup_tween != null and save_popup_tween.is_running():
		save_popup_tween.kill()
	save_popup_tween = create_tween().set_parallel(true)
	save_popup_tween.tween_property(save_popup_overlay, "modulate:a", 0.0, 0.1)
	save_popup_tween.tween_property(save_popup_panel, "modulate:a", 0.0, 0.1)
	save_popup_tween.chain().tween_callback(func():
		if save_popup_overlay and is_instance_valid(save_popup_overlay):
			save_popup_overlay.visible = false
		if save_popup_panel and is_instance_valid(save_popup_panel):
			save_popup_panel.visible = false
	)

func _get_level_node() -> Node:
	return get_tree().get_first_node_in_group("level")

func _refresh_save_ui() -> void:
	var level = _get_level_node()
	if level == null or save_slot_select == null:
		return
	var slots: Array = []
	if level.has_method("list_save_slots"):
		slots = level.call("list_save_slots")
	var preferred = "默认存档"
	save_slot_select.clear()
	for s in slots:
		save_slot_select.add_item(str(s))
	if save_slot_select.item_count == 0:
		save_slot_select.add_item(preferred)
	var target_index = 0
	for i in range(save_slot_select.item_count):
		if save_slot_select.get_item_text(i) == preferred:
			target_index = i
			break
	save_slot_select.select(target_index)
	_on_save_slot_selected(target_index)

func _on_save_slot_selected(index: int) -> void:
	if save_slot_select == null or save_slot_edit == null:
		return
	save_slot_edit.text = save_slot_select.get_item_text(index)

func _get_current_save_slot() -> String:
	var level = _get_level_node()
	if level != null and level.has_method("get_save_slot"):
		return str(level.call("get_save_slot"))
	return "默认存档"

func _get_selected_save_slot() -> String:
	if save_slot_select == null or save_slot_select.item_count == 0:
		return _get_current_save_slot()
	return save_slot_select.get_item_text(save_slot_select.selected)

func _set_save_status(text: String) -> void:
	if save_status_label:
		save_status_label.text = text

func _on_save_overwrite_pressed() -> void:
	var level = _get_level_node()
	if level == null:
		return
	var slot = _get_selected_save_slot()
	var ok = true
	if level.has_method("request_manual_save"):
		ok = bool(level.call("request_manual_save", slot))
	if ok:
		_set_save_status("已存档: " + slot)
		_refresh_save_ui()
	else:
		_set_save_status("存档失败: " + slot)
	if save_overwrite_button == null:
		return
	if save_overwrite_tween != null and save_overwrite_tween.is_running():
		save_overwrite_tween.kill()
	save_overwrite_button.disabled = true
	var original = save_overwrite_button.text
	save_overwrite_button.text = "已存"
	save_overwrite_tween = create_tween()
	save_overwrite_tween.tween_interval(0.7)
	save_overwrite_tween.tween_callback(func():
		if save_overwrite_button:
			save_overwrite_button.text = original
			save_overwrite_button.disabled = false
	)

func _on_save_as_pressed() -> void:
	var level = _get_level_node()
	if level == null or save_slot_edit == null:
		return
	var slot = save_slot_edit.text
	var ok = true
	if level.has_method("request_manual_save"):
		ok = bool(level.call("request_manual_save", slot))
	if ok:
		_set_save_status("已另存为: " + slot.strip_edges())
		_refresh_save_ui()
	else:
		_set_save_status("另存失败: " + slot.strip_edges())

func _on_save_load_pressed() -> void:
	var level = _get_level_node()
	if level == null:
		return
	var slot = _get_selected_save_slot()
	var ok = false
	if level.has_method("request_manual_load"):
		ok = bool(level.call("request_manual_load", slot))
	if ok:
		_set_save_status("正在读档(重开本局): " + slot)
	else:
		_set_save_status("读档失败(不存在): " + slot)
	if save_load_button == null:
		return
	if save_load_tween != null and save_load_tween.is_running():
		save_load_tween.kill()
	save_load_button.disabled = true
	var original = save_load_button.text
	save_load_button.text = "已读"
	save_load_tween = create_tween()
	save_load_tween.tween_interval(0.7)
	save_load_tween.tween_callback(func():
		if save_load_button:
			save_load_button.text = original
			save_load_button.disabled = false
	)

func _on_save_rename_pressed() -> void:
	var level = _get_level_node()
	if level == null or save_slot_edit == null:
		return
	var from_slot = _get_selected_save_slot()
	var to_slot = save_slot_edit.text
	var ok = false
	if level.has_method("rename_save_slot"):
		ok = bool(level.call("rename_save_slot", from_slot, to_slot))
	if ok:
		_set_save_status("已重命名: " + from_slot + " -> " + to_slot.strip_edges())
		_refresh_save_ui()
	else:
		_set_save_status("重命名失败")

func _on_new_run_pressed() -> void:
	_hide_save_popup()
	var level = _get_level_node()
	if level != null and level.has_method("request_new_run"):
		level.call("request_new_run")
	else:
		_restart_run()

func _build_end_overlay() -> void:
	end_overlay = ColorRect.new()
	end_overlay.name = "EndOverlay"
	end_overlay.color = Color(0, 0, 0, 0.72)
	end_overlay.anchor_left = 0.0
	end_overlay.anchor_top = 0.0
	end_overlay.anchor_right = 1.0
	end_overlay.anchor_bottom = 1.0
	end_overlay.offset_left = 0.0
	end_overlay.offset_top = 0.0
	end_overlay.offset_right = 0.0
	end_overlay.offset_bottom = 0.0
	end_overlay.visible = false
	end_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	end_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(end_overlay)
	var panel = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -260.0
	panel.offset_top = -200.0
	panel.offset_right = 260.0
	panel.offset_bottom = 200.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	end_overlay.add_child(panel)
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(vbox)
	end_title_label = Label.new()
	end_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_title_label.text = "结束"
	vbox.add_child(end_title_label)
	end_stats_label = Label.new()
	end_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	end_stats_label.text = ""
	vbox.add_child(end_stats_label)
	var buttons = HBoxContainer.new()
	vbox.add_child(buttons)
	restart_button = Button.new()
	restart_button.text = "重开"
	restart_button.pressed.connect(_restart_run)
	buttons.add_child(restart_button)
	quit_button = Button.new()
	quit_button.text = "退出"
	quit_button.pressed.connect(_quit_run)
	buttons.add_child(quit_button)

func _restart_run() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _quit_run() -> void:
	get_tree().paused = false
	get_tree().quit()

func _format_time(seconds: float) -> String:
	var s = int(floor(max(0.0, seconds)))
	var m = int(floor(float(s) / 60.0))
	var r = s - m * 60
	var mm = str(m).pad_zeros(2)
	var ss = str(r).pad_zeros(2)
	return mm + ":" + ss

# --- ⚔️ 武器栏逻辑 ---
# --- ⚔️ 武器栏高级视觉交互 ---
func update_weapon_indicator(weapon_index: int) -> void:
	# 高亮当前武器图标
	if not slots_container: return
	var slots = slots_container.get_children()
	
	# 💡 遍历所有武器图标
	for i in range(slots.size()):
		var slot = slots[i]
		
		# ✨ 关键防错：动态设置中心锚点，保证动画从图片正中心缩放/旋转
		slot.pivot_offset = slot.size / 2 
		
		var tween = create_tween().set_parallel(true)
		
		if i == weapon_index:
			# 🟢 【选中状态】：拔出武器！瞬间明亮、放大并带弹簧回弹、轻微翘起展示
			tween.tween_property(slot, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1) # 纯白，无透明
			tween.tween_property(slot, "rotation", deg_to_rad(-12), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) # 往左翘起12度
			
			# 利用链式动画做弹簧回弹：先迅速变大到 1.3，再回落到 1.15
			var bounce_tween = create_tween()
			bounce_tween.tween_property(slot, "scale", Vector2(1.3, 1.3), 0.1)
			bounce_tween.tween_property(slot, "scale", Vector2(1.15, 1.15), 0.2).set_trans(Tween.TRANS_SPRING)
		else:
			# 🔴 【未选中 / 取消状态】：收起武器！变灰暗、缩小、放平
			tween.tween_property(slot, "modulate", Color(0.3, 0.3, 0.3, 0.6), 0.2) # 变暗并半透明
			tween.tween_property(slot, "rotation", 0.0, 0.2).set_trans(Tween.TRANS_SINE) # 角度回归水平
			tween.tween_property(slot, "scale", Vector2(0.8, 0.8), 0.2).set_trans(Tween.TRANS_SINE) # 缩回到0.8
	# 你的武器轮换逻辑写在这里...

func update_player_health(current: int, max_value: int) -> void:
	# 更新血条显示
	if player_health_bar:
		player_health_bar.max_value = max_value
		player_health_bar.value = current

func update_player_experience(current: int, to_next: int, level: int) -> void:
	if player_exp_bar:
		player_exp_bar.max_value = max(1, to_next)
		player_exp_bar.value = clamp(current, 0, player_exp_bar.max_value)
	if exp_level_label:
		exp_level_label.text = "Lv." + str(level)
	if exp_need_label:
		exp_need_label.text = str(clamp(current, 0, max(0, to_next))) + "/" + str(max(0, to_next))

func _sync_player_health() -> void:
	var player = get_tree().get_first_node_in_group("peao")
	if player == null:
		return
	var max_health = player.get("max_health")
	var current_health = player.get("current_health")
	if max_health != null and current_health != null:
		update_player_health(current_health, max_health)

func _build_exp_progress() -> void:
	if player_exp_bar_root == null:
		return
	var scale_factor = max(0.05, float(player_exp_bar_root.scale.x))
	var exp_settings = LabelSettings.new()
	exp_settings.font = preload("res://Fonts/ark-pixel-10px-monospaced-zh_cn.ttf")
	exp_settings.font_size = int(round(18.0 / scale_factor))
	exp_settings.outline_size = int(round(5.0 / scale_factor))
	exp_settings.outline_color = Color(0.08627451, 0.10980392, 0.18039216, 1)
	exp_level_label = Label.new()
	exp_level_label.anchor_left = 0.0
	exp_level_label.anchor_top = 0.0
	exp_level_label.anchor_right = 0.0
	exp_level_label.anchor_bottom = 1.0
	exp_level_label.offset_left = 18.0
	exp_level_label.offset_top = 0.0
	exp_level_label.offset_right = 86.0
	exp_level_label.offset_bottom = 0.0
	exp_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	exp_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	exp_level_label.text = "Lv.1"
	exp_level_label.label_settings = exp_settings
	player_exp_bar_root.add_child(exp_level_label)
	exp_name_label = Label.new()
	exp_name_label.anchor_left = 0.0
	exp_name_label.anchor_top = 0.0
	exp_name_label.anchor_right = 0.0
	exp_name_label.anchor_bottom = 1.0
	exp_name_label.offset_left = 98.0
	exp_name_label.offset_top = 0.0
	exp_name_label.offset_right = 162.0
	exp_name_label.offset_bottom = 0.0
	exp_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	exp_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	exp_name_label.text = "经验"
	exp_name_label.label_settings = exp_settings
	player_exp_bar_root.add_child(exp_name_label)
	exp_need_label = Label.new()
	exp_need_label.anchor_left = 1.0
	exp_need_label.anchor_top = 0.0
	exp_need_label.anchor_right = 1.0
	exp_need_label.anchor_bottom = 1.0
	exp_need_label.offset_left = -172.0
	exp_need_label.offset_top = 0.0
	exp_need_label.offset_right = -18.0
	exp_need_label.offset_bottom = 0.0
	exp_need_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	exp_need_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	exp_need_label.text = "0/0"
	exp_need_label.label_settings = exp_settings
	player_exp_bar_root.add_child(exp_need_label)

func _build_build_buttons() -> void:
	build_buttons_container = HBoxContainer.new()
	build_buttons_container.name = "BuildButtons"
	build_buttons_container.anchor_left = 0.5
	build_buttons_container.anchor_top = 1.0
	build_buttons_container.anchor_right = 0.5
	build_buttons_container.anchor_bottom = 1.0
	build_buttons_container.offset_left = -180.0
	build_buttons_container.offset_right = 180.0
	build_buttons_container.offset_top = -130.0
	build_buttons_container.offset_bottom = -8.0
	build_buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(build_buttons_container)
	build_warehouse_button = TextureButton.new()
	build_warehouse_button.custom_minimum_size = Vector2(64, 64)
	build_warehouse_button.size = Vector2(64, 64)
	build_warehouse_button.ignore_texture_size = true
	build_warehouse_button.stretch_mode = TextureButton.STRETCH_SCALE
	build_warehouse_button.tooltip_text = "需要: 木0 矿0 肉0"
	build_warehouse_button.pressed.connect(_on_build_warehouse_pressed)
	build_warehouse_button.texture_normal = preload("res://Assets/Buildings/Barracks.png")
	build_warehouse_button.set_script(preload("res://Interface/ScaleButton.gd"))
	build_buttons_container.add_child(build_warehouse_button)
	var click_audio = AudioStreamPlayer.new()
	click_audio.name = "AudioStreamPlayer"
	click_audio.stream = preload("res://Audio/click_003.ogg")
	click_audio.volume_db = -5.0
	build_warehouse_button.add_child(click_audio)
	var warehouse_label = Label.new()
	warehouse_label.name = "Label"
	warehouse_label.anchor_top = 1.0
	warehouse_label.anchor_bottom = 1.0
	warehouse_label.offset_top = -66.0
	warehouse_label.offset_right = 65.0
	warehouse_label.theme_type_variation = &"GraphFrameTitleLabel"
	warehouse_label.text = "仓库"
	warehouse_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warehouse_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var warehouse_label_settings = LabelSettings.new()
	warehouse_label_settings.font = preload("res://Fonts/ark-pixel-10px-monospaced-zh_cn.ttf")
	warehouse_label_settings.font_size = 18
	warehouse_label_settings.outline_size = 5
	warehouse_label_settings.outline_color = Color(0.08627451, 0.10980392, 0.18039216, 1)
	warehouse_label.label_settings = warehouse_label_settings
	build_warehouse_button.add_child(warehouse_label)

	var build_castle_button := TextureButton.new()
	build_castle_button.custom_minimum_size = Vector2(64, 64)
	build_castle_button.size = Vector2(64, 64)
	build_castle_button.ignore_texture_size = true
	build_castle_button.stretch_mode = TextureButton.STRETCH_SCALE
	build_castle_button.tooltip_text = "主城 · 消耗SP放置"
	build_castle_button.pressed.connect(_on_build_castle_pressed)
	build_castle_button.texture_normal = preload("res://Assets/Buildings/Castle/Castle.png")
	build_castle_button.set_script(preload("res://Interface/ScaleButton.gd"))
	build_buttons_container.add_child(build_castle_button)

	var castle_label := Label.new()
	castle_label.name = "Label"
	castle_label.anchor_top = 1.0
	castle_label.anchor_bottom = 1.0
	castle_label.offset_top = -66.0
	castle_label.offset_right = 65.0
	castle_label.theme_type_variation = &"GraphFrameTitleLabel"
	castle_label.text = "主城"
	castle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	castle_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var castle_label_settings := LabelSettings.new()
	castle_label_settings.font = preload("res://Fonts/ark-pixel-10px-monospaced-zh_cn.ttf")
	castle_label_settings.font_size = 18
	castle_label_settings.outline_size = 5
	castle_label_settings.outline_color = Color(0.08627451, 0.10980392, 0.18039216, 1)
	castle_label.label_settings = castle_label_settings
	build_castle_button.add_child(castle_label)

	var build_barracks_button := TextureButton.new()
	build_barracks_button.custom_minimum_size = Vector2(64, 64)
	build_barracks_button.size = Vector2(64, 64)
	build_barracks_button.ignore_texture_size = true
	build_barracks_button.stretch_mode = TextureButton.STRETCH_SCALE
	build_barracks_button.tooltip_text = "兵营 · 消耗SP解锁兵力"
	build_barracks_button.pressed.connect(_on_build_barracks_pressed)
	build_barracks_button.texture_normal = preload("res://Tiny Swords/Tiny Swords (Free Pack)/Buildings/Blue Buildings/Barracks.png")
	build_barracks_button.set_script(preload("res://Interface/ScaleButton.gd"))
	build_buttons_container.add_child(build_barracks_button)

	var barracks_label := Label.new()
	barracks_label.name = "Label"
	barracks_label.anchor_top = 1.0
	barracks_label.anchor_bottom = 1.0
	barracks_label.offset_top = -66.0
	barracks_label.offset_right = 65.0
	barracks_label.theme_type_variation = &"GraphFrameTitleLabel"
	barracks_label.text = "兵营"
	barracks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	barracks_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var barracks_label_settings := LabelSettings.new()
	barracks_label_settings.font = preload("res://Fonts/ark-pixel-10px-monospaced-zh_cn.ttf")
	barracks_label_settings.font_size = 18
	barracks_label_settings.outline_size = 5
	barracks_label_settings.outline_color = Color(0.08627451, 0.10980392, 0.18039216, 1)
	barracks_label.label_settings = barracks_label_settings
	build_barracks_button.add_child(barracks_label)

	var build_tower_button := TextureButton.new()
	build_tower_button.custom_minimum_size = Vector2(64, 64)
	build_tower_button.size = Vector2(64, 64)
	build_tower_button.ignore_texture_size = true
	build_tower_button.stretch_mode = TextureButton.STRETCH_SCALE
	build_tower_button.tooltip_text = "箭塔 · 消耗资源放置"
	build_tower_button.pressed.connect(_on_build_tower_pressed)
	build_tower_button.texture_normal = preload("res://Assets/Buildings/Tower/Tower.png")
	build_tower_button.set_script(preload("res://Interface/ScaleButton.gd"))
	build_buttons_container.add_child(build_tower_button)

	var tower_label := Label.new()
	tower_label.name = "Label"
	tower_label.anchor_top = 1.0
	tower_label.anchor_bottom = 1.0
	tower_label.offset_top = -66.0
	tower_label.offset_right = 65.0
	tower_label.theme_type_variation = &"GraphFrameTitleLabel"
	tower_label.text = "箭塔"
	tower_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tower_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var tower_label_settings := LabelSettings.new()
	tower_label_settings.font = preload("res://Fonts/ark-pixel-10px-monospaced-zh_cn.ttf")
	tower_label_settings.font_size = 18
	tower_label_settings.outline_size = 5
	tower_label_settings.outline_color = Color(0.08627451, 0.10980392, 0.18039216, 1)
	tower_label.label_settings = tower_label_settings
	build_tower_button.add_child(tower_label)

func _on_build_warehouse_pressed() -> void:
	get_tree().call_group("level", "request_build_warehouse")

func _on_build_castle_pressed() -> void:
	get_tree().call_group("level", "request_build_castle")

func _on_build_barracks_pressed() -> void:
	get_tree().call_group("level", "request_build_barracks")

func _on_build_tower_pressed() -> void:
	get_tree().call_group("level", "request_build_tower")

func update_warehouse_build_button_state(can_build: bool, cost_wood: int, cost_gold: int, cost_meat: int, cost_sp: int, missing_wood: int, missing_gold: int, missing_meat: int, missing_sp: int, placing: bool) -> void:
	if build_warehouse_button == null:
		return
	var missing_text = "缺少: 木" + str(missing_wood) + " 矿" + str(missing_gold) + " 肉" + str(missing_meat) + " SP" + str(missing_sp)
	var cost_text = "成本: 木" + str(cost_wood) + " 矿" + str(cost_gold) + " 肉" + str(cost_meat) + " SP" + str(cost_sp)
	if placing:
		build_warehouse_button.tooltip_text = "左键放置，右键取消\n" + cost_text
	else:
		build_warehouse_button.tooltip_text = cost_text + "\n" + missing_text
	build_warehouse_button.disabled = (not placing) and (not can_build)
	if placing:
		build_warehouse_button.modulate = Color(0.9, 1.0, 0.9, 1.0)
	elif can_build:
		build_warehouse_button.modulate = Color(1, 1, 1, 1)
	else:
		build_warehouse_button.modulate = Color(0.55, 0.55, 0.55, 0.9)

func _auto_fill_quickbar_from_inventory() -> void:
	var available: Array[String] = []
	for key in inventory_data.keys():
		var count = int(inventory_data.get(key, 0))
		if count > 0:
			available.append(String(key))
	var preferred: Array[String] = ["wood", "gold", "meat"]
	var ordered: Array[String] = []
	for p in preferred:
		if p in available:
			ordered.append(p)
			available.erase(p)
	available.sort()
	for k in available:
		ordered.append(k)
	var remaining: Array[String] = ordered.duplicate()
	for i in range(quickbar_items.size()):
		var t = quickbar_items[i]
		if t != "" and t in remaining:
			remaining.erase(t)
		else:
			quickbar_items[i] = ""
	for i in range(quickbar_items.size()):
		if quickbar_items[i] == "" and not remaining.is_empty():
			quickbar_items[i] = remaining.pop_front()

func _refresh_quickbar_ui() -> void:
	# 刷新快捷栏显示
	if not quickbar_container:
		return
	var slots = quickbar_container.get_children()
	for i in range(slots.size()):
		var slot = slots[i] as InventorySlot
		if slot == null:
			continue
		slot.custom_minimum_size = QUICKBAR_SIZE
		slot.slot_role = "quick"
		slot.slot_index = i
		var item_type = quickbar_items[i]
		if item_type != "":
			var icon = item_icons.get(item_type, null)
			var count = inventory_data.get(item_type, 0)
			slot.update_slot(icon, count, item_type)
		else:
			slot.update_slot(null, 0, "")

func assign_quick_slot(index: int, item_type: String) -> void:
	# 将某种物品绑定到快捷栏
	if index < 0 or index >= quickbar_items.size():
		return
	quickbar_items[index] = item_type
	_refresh_quickbar_ui()
	print("快捷栏设置 | 格子=", index + 1, " | 类型=", item_type)

func use_quick_slot(index: int) -> void:
	# 使用快捷栏物品
	if index < 0 or index >= quickbar_items.size():
		return
	var item_type = quickbar_items[index]
	if item_type == "redwood_seed":
		get_tree().call_group("level", "request_plant_redwood_seed")
		return
	if item_type == "lamb":
		get_tree().call_group("level", "request_release_lamb")
		return
	if item_type == "meat":
		var ok = _consume_meat("quick_slot")
		if ok:
			print("快捷栏消耗成功 | 格子=", index + 1, " | 类型=meat")
	else:
		if item_type != "":
			print("快捷栏未实现消耗 | 格子=", index + 1, " | 类型=", item_type)

func _get_player() -> Node:
	# 获取玩家节点（使用分组查询）
	return get_tree().get_first_node_in_group("peao")

func _recenter_camera_on_player() -> void:
	var player = _get_player() as Node2D
	if player == null:
		return
	var camera = player.get_node_or_null("GameCamera") as Camera2D
	if camera == null:
		return
	if camera_recenter_tween != null and camera_recenter_tween.is_running():
		camera_recenter_tween.kill()
	if camera.has_method("reset_smoothing"):
		camera.reset_smoothing()
	var target = Vector2.ZERO
	var start = camera.position
	var duration = clamp(start.distance_to(target) / 900.0, 0.22, 0.55)
	camera_recenter_tween = create_tween()
	camera_recenter_tween.tween_property(camera, "position", target, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _consume_meat(source: String) -> bool:
	# 吃肉回血，并更新 UI 与库存
	if not inventory_data.has("meat") or inventory_data["meat"] <= 0:
		print("肉消耗失败 | 原因=无库存 | 来源=", source)
		return false
	var player = _get_player()
	if player == null:
		print("肉消耗失败 | 原因=无主角 | 来源=", source)
		return false
	var max_health = player.get("max_health")
	var current_health = player.get("current_health")
	if max_health == null or current_health == null:
		print("肉消耗失败 | 原因=缺少血量数据 | 来源=", source)
		return false
	if current_health >= max_health:
		print("肉消耗失败 | 原因=已满血 | 来源=", source)
		return false
	inventory_data["meat"] -= 1
	var heal_amount = max_health * 0.5
	var new_health = min(float(current_health) + heal_amount, float(max_health))
	player.set("current_health", int(round(new_health)))
	update_player_health(int(round(new_health)), max_health)
	_play_consume_animation()
	var fx = _pick_consume_fx()
	if not fx.is_empty():
		_spawn_world_fx(fx["texture"], int(fx["frames"]), player.global_position + Vector2(0, -12), Vector2(1.0, 1.0))
	refresh_inventory_ui()
	get_tree().call_group("sheep", "apply_speed_boost", 2.0, 8.0)
	print("肉消耗成功 | 来源=", source, " | 治疗=", heal_amount, " | HP=", int(round(new_health)), "/", max_health, " | MeatLeft=", inventory_data["meat"])
	return true

func _pick_consume_fx() -> Dictionary:
	# 随机选择消耗特效
	if consume_fx_defs.is_empty():
		return {}
	return consume_fx_defs.pick_random()

func _spawn_world_fx(texture: Texture2D, frame_count: int, fx_position: Vector2, fx_scale: Vector2) -> void:
	# 在世界中播放一次性特效
	if texture == null or frame_count <= 0:
		return
	var fx_sprite = AnimatedSprite2D.new()
	fx_sprite.sprite_frames = _build_fx_frames(texture, frame_count, 12.0)
	fx_sprite.animation = "fx"
	fx_sprite.global_position = fx_position
	fx_sprite.scale = fx_scale
	fx_sprite.z_index = 20
	var root = get_tree().current_scene
	if root:
		root.add_child(fx_sprite)
	fx_sprite.play()
	if not fx_sprite.animation_finished.is_connected(fx_sprite.queue_free):
		fx_sprite.animation_finished.connect(fx_sprite.queue_free)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(fx_sprite, "scale", fx_scale * 1.25, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(fx_sprite, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(fx_sprite.queue_free)

func _build_fx_frames(texture: Texture2D, frame_count: int, fps: float) -> SpriteFrames:
	# 将贴图切成特效帧序列
	var frames = SpriteFrames.new()
	frames.add_animation("fx")
	var frame_width = texture.get_width() / float(frame_count)
	var frame_height = texture.get_height()
	for i in range(frame_count):
		var atlas = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * frame_width, 0, frame_width, frame_height)
		frames.add_frame("fx", atlas)
	frames.set_animation_speed("fx", fps)
	frames.set_animation_loop("fx", false)
	return frames

func _play_consume_animation() -> void:
	# 通过轻微缩放强调回血
	if not player_health_bar:
		return
	var base_scale = player_health_bar.scale
	player_health_bar.scale = base_scale
	var tween = create_tween()
	tween.tween_property(player_health_bar, "scale", base_scale * 1.08, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(player_health_bar, "scale", base_scale, 0.2).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)

# --- 🎒 背包开关动画逻辑 (保持你的原有代码不变) ---
func _on_bag_button_pressed() -> void:
	# 背包按钮逻辑：打开/关闭并触发消耗
	if not inventory_panel: return
	if inventory_panel.visible and inventory_panel.modulate.a > 0.1:
		_close_inventory_animation()
	else:
		_consume_meat("open_inventory")
		_open_inventory_animation()

func _on_save_button_pressed() -> void:
	_toggle_save_popup()

func _on_tech_button_pressed() -> void:
	if tech_ui != null and is_instance_valid(tech_ui) and tech_ui.has_method("toggle"):
		tech_ui.call("toggle")

func _open_inventory_animation():
	# 打开背包的弹出动画
	inventory_panel.visible = true
	var tween = create_tween().set_parallel(true)
	inventory_panel.position = origin_pos + Vector2(0, 50)
	inventory_panel.modulate.a = 0.0
	tween.tween_property(inventory_panel, "position", origin_pos, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(inventory_panel, "modulate:a", 1.0, 0.2)

func _close_inventory_animation():
	# 关闭背包的收起动画
	var tween = create_tween().set_parallel(true)
	tween.tween_property(inventory_panel, "position", origin_pos + Vector2(0, 50), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(inventory_panel, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(func(): inventory_panel.visible = false)
