extends CanvasLayer
class_name Interface # 注册大管家
# UI 总控：背包、快捷栏、血量/体力条的更新

# --- 🔗 引用区域 ---
@onready var slots_container: HBoxContainer = $Avatar/HBoxContainer
@onready var inventory_panel: TileMapLayer = $TileMapLayer
@onready var grid_container: GridContainer = $TileMapLayer/InventoryGrid
@onready var player_health_bar: TextureProgressBar = $PlayerHealthBar/Fill
@onready var player_stamina_bar: TextureProgressBar = $PlayerStaminaBar/Fill
@onready var quickbar_container: HBoxContainer = $QuickBar
@onready var wood_label: Label = $ResourceHUD/WoodLabel
@onready var gold_label: Label = $ResourceHUD/GoldLabel
@onready var meat_label: Label = $ResourceHUD/MeatLabel
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
	call_deferred("_sync_player_bars")

func _unhandled_input(event: InputEvent) -> void:
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
	_refresh_quickbar_ui()
	_update_resource_hud()

func _update_resource_hud() -> void:
	if wood_label:
		wood_label.text = "木材 " + str(inventory_data.get("wood", 0))
	if gold_label:
		gold_label.text = "矿石 " + str(inventory_data.get("gold", 0))
	if meat_label:
		meat_label.text = "肉 " + str(inventory_data.get("meat", 0))

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

func update_player_stamina(current: int, max_value: int) -> void:
	# 更新体力条显示
	if player_stamina_bar:
		player_stamina_bar.max_value = max_value
		player_stamina_bar.value = current

func _sync_player_bars() -> void:
	# 从玩家节点读取当前状态并同步 UI
	var player = get_tree().get_first_node_in_group("peao")
	if player:
		var max_health = player.get("max_health")
		var current_health = player.get("current_health")
		if max_health != null and current_health != null:
			update_player_health(current_health, max_health)
		var max_stamina = player.get("max_stamina")
		var current_stamina = player.get("current_stamina")
		if max_stamina != null and current_stamina != null:
			update_player_stamina(current_stamina, max_stamina)

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
