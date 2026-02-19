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

var meta_hud_container: VBoxContainer
var wave_meta_label: Label
var energy_meta_label: Label
var cpu_meta_label: Label
var logistics_meta_label: Label
var exp_meta_label: Label
var warehouse_meta_label: Label
var objective_meta_label: Label
var hint_meta_label: Label
var exp_level_label: Label
var exp_need_label: Label
var build_buttons_container: HBoxContainer
var build_warehouse_button: TextureButton
var camera_recenter_tween: Tween

var end_overlay: ColorRect
var end_title_label: Label
var end_stats_label: Label
var restart_button: Button
var quit_button: Button
# 这些节点分别对应 UI 中的背包、格子和血条等元素

# --- 🔥 配置区域 ---
# 【检查！】必须在编辑器里把 InventorySlot.tscn 拖给它
@export var slot_scene: PackedScene 
# slot_scene 是背包格子实例的预制体

# 字典：教 UI 如何将 "wood" 映射成对应的图片
@onready var item_icons: Dictionary = {
	"wood": preload("res://Base_Object/Wood_Resource.png"), 
	"gold": preload("res://Base_Object/Gold_Resource.png"),
	"meat": preload("res://Base_Object/Resources/Meat/Meat_Resource.png")
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
# SLOT_SIZE/QUICKBAR_SIZE 控制格子的最小显示尺寸

# 💡【核心数据】这是你真正的背包，所有加减全在这发生
var inventory_data: Dictionary = {} 
var quickbar_items: Array[String] = ["", "", "", ""]
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
	call_deferred("_sync_player_health")

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

func _on_avatar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_recenter_camera_on_player()

# --- 📥 数据更新与接收 ---
# 这个方法会被外界（如 PhysicItem）呼叫
func add_item(item_type: String, amount: int) -> void:
	# 增加某种物品数量
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

func update_meta_hud(waves_survived: int, next_wave_in: float, enemies_alive: int, next_wave_size: int, energy_points: float, energy_decay_per_sec: float, energy_consumes_wood: bool, cpu_level: int, enemy_kill_exp: int, cpu_upgrade_cost: int, logistics_multiplier: float, logistics_enabled: bool, map_seed: int, objective_text: String, hint_text: String, player_level: int, player_exp: int, exp_to_next: int, warehouse_count: int, workers_current: int, workers_cap: int, next_warehouse_wood: int, next_warehouse_gold: int, next_warehouse_meat: int, placing_warehouse: bool) -> void:
	if meta_hud_container == null:
		return
	if wave_meta_label:
		wave_meta_label.text = "波次 " + str(waves_survived) + " | 下波 " + str(int(ceil(next_wave_in))) + "s | 规模 " + str(next_wave_size) + " | 敌人 " + str(enemies_alive)
	if energy_meta_label:
		var burn_text = "烧木" if energy_consumes_wood else "不烧木"
		energy_meta_label.text = "能量 " + str(int(round(energy_points))) + " | 衰减 " + str(snapped(energy_decay_per_sec, 0.1)) + "/s | " + burn_text
	if cpu_meta_label:
		cpu_meta_label.text = "CPU Lv." + str(cpu_level) + " | 杀敌经验 " + str(enemy_kill_exp) + " | 每级 " + str(max(1, cpu_upgrade_cost)) + " | 物流倍率 x" + str(snapped(logistics_multiplier, 0.01))
	if logistics_meta_label:
		logistics_meta_label.text = "物流 " + ("启用" if logistics_enabled else "停用") + " | 种子 " + str(map_seed)
	if exp_meta_label:
		exp_meta_label.text = "经验 Lv." + str(player_level) + " | " + str(player_exp) + "/" + str(exp_to_next)
	if warehouse_meta_label:
		var place_text = " | 放置中" if placing_warehouse else ""
		warehouse_meta_label.text = "仓库 " + str(warehouse_count) + " | 工人 " + str(workers_current) + "/" + str(workers_cap) + " | 下次仓库: 木" + str(next_warehouse_wood) + " 矿" + str(next_warehouse_gold) + " 肉" + str(next_warehouse_meat) + place_text
	if objective_meta_label:
		objective_meta_label.text = objective_text
	if hint_meta_label:
		hint_meta_label.text = hint_text

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
		var cpu_level_val = int(stats.get("cpu_level", 1))
		var map_seed = int(stats.get("seed", 0))
		var resources = stats.get("resources", {})
		var wood = 0
		var gold = 0
		var meat = 0
		if resources is Dictionary:
			wood = int(resources.get("wood", 0))
			gold = int(resources.get("gold", 0))
			meat = int(resources.get("meat", 0))
		end_stats_label.text = "坚持波数: " + str(waves) + "\n击杀敌人: " + str(kills) + "\nCPU: Lv." + str(cpu_level_val) + "\n用时: " + _format_time(time_sec) + "\n地图种子: " + str(map_seed) + "\n资源: 木 " + str(wood) + " | 矿 " + str(gold) + " | 肉 " + str(meat) + "\n\nR 重开 | Q/ESC 退出"
	end_overlay.visible = true

func _build_meta_hud() -> void:
	meta_hud_container = VBoxContainer.new()
	meta_hud_container.name = "MetaHUD"
	meta_hud_container.anchor_left = 1.0
	meta_hud_container.anchor_top = 0.0
	meta_hud_container.anchor_right = 1.0
	meta_hud_container.anchor_bottom = 0.0
	meta_hud_container.offset_left = -520.0
	meta_hud_container.offset_top = 12.0
	meta_hud_container.offset_right = -12.0
	meta_hud_container.offset_bottom = 220.0
	meta_hud_container.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(meta_hud_container)
	wave_meta_label = Label.new()
	energy_meta_label = Label.new()
	cpu_meta_label = Label.new()
	logistics_meta_label = Label.new()
	exp_meta_label = Label.new()
	warehouse_meta_label = Label.new()
	objective_meta_label = Label.new()
	hint_meta_label = Label.new()
	wave_meta_label.text = "波次 0 | 下波 0s | 规模 0 | 敌人 0"
	energy_meta_label.text = "能量 0 | 衰减 0/s | 不烧木"
	cpu_meta_label.text = "CPU Lv.1 | 物流倍率 x1"
	logistics_meta_label.text = "物流 停用 | 种子 0"
	exp_meta_label.text = "经验 Lv.1 | 0/0"
	warehouse_meta_label.text = "仓库 1 | 工人 0/0 | 下次仓库: 木0 矿0 肉0"
	objective_meta_label.text = "目标: "
	hint_meta_label.text = "建议: "
	meta_hud_container.add_child(wave_meta_label)
	meta_hud_container.add_child(energy_meta_label)
	meta_hud_container.add_child(cpu_meta_label)
	meta_hud_container.add_child(logistics_meta_label)
	meta_hud_container.add_child(exp_meta_label)
	meta_hud_container.add_child(warehouse_meta_label)
	meta_hud_container.add_child(objective_meta_label)
	meta_hud_container.add_child(hint_meta_label)

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
		exp_need_label.text = "还需 " + str(max(0, to_next - current))

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
	exp_level_label = Label.new()
	exp_level_label.anchor_left = 0.0
	exp_level_label.anchor_top = 0.5
	exp_level_label.anchor_right = 0.0
	exp_level_label.anchor_bottom = 0.5
	exp_level_label.offset_left = -64.0
	exp_level_label.offset_top = -10.0
	exp_level_label.offset_right = -8.0
	exp_level_label.offset_bottom = 10.0
	exp_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	exp_level_label.text = "Lv.1"
	player_exp_bar_root.add_child(exp_level_label)
	exp_need_label = Label.new()
	exp_need_label.anchor_left = 1.0
	exp_need_label.anchor_top = 0.5
	exp_need_label.anchor_right = 1.0
	exp_need_label.anchor_bottom = 0.5
	exp_need_label.offset_left = 8.0
	exp_need_label.offset_top = -10.0
	exp_need_label.offset_right = 140.0
	exp_need_label.offset_bottom = 10.0
	exp_need_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	exp_need_label.text = "还需 0"
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
	build_warehouse_button.texture_normal = preload("res://Tiny Swords/Tiny Swords (Free Pack)/Buildings/Blue Buildings/Barracks.png")
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

func _on_build_warehouse_pressed() -> void:
	get_tree().call_group("level", "request_build_warehouse")

func update_warehouse_build_button_state(can_build: bool, cost_wood: int, cost_gold: int, cost_meat: int, missing_wood: int, missing_gold: int, missing_meat: int, placing: bool) -> void:
	if build_warehouse_button == null:
		return
	var missing_text = "缺少: 木" + str(missing_wood) + " 矿" + str(missing_gold) + " 肉" + str(missing_meat)
	var cost_text = "成本: 木" + str(cost_wood) + " 矿" + str(cost_gold) + " 肉" + str(cost_meat)
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
