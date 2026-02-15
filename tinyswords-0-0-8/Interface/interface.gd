extends CanvasLayer
class_name Interface # 注册大管家

# --- 🔗 引用区域 ---
@onready var slots_container: HBoxContainer = $Avatar/HBoxContainer
@onready var inventory_panel: TileMapLayer = $TileMapLayer
@onready var grid_container: GridContainer = $TileMapLayer/InventoryGrid

# --- 🔥 配置区域 ---
# 【检查！】必须在编辑器里把 InventorySlot.tscn 拖给它
@export var slot_scene: PackedScene 

# 字典：教 UI 如何将 "wood" 映射成对应的图片
@onready var item_icons: Dictionary = {
	"wood": preload("res://Base_Object/Wood_Resource.png"), 
	"gold": preload("res://Base_Object/Gold_Resource.png"),
	"meat": preload("res://Base_Object/Resources/Meat/Meat_Resource.png")
}

# --- 🌟 数据中枢 ---
var origin_pos: Vector2
var total_slots: int = 21 # 背包总共有多少格子
const SLOT_SIZE = Vector2(96, 96)

# 💡【核心数据】这是你真正的背包，所有加减全在这发生
var inventory_data: Dictionary = {} 

# --- 🚀 初始化 ---
func _ready() -> void:
	add_to_group("interface")
	
	# 💡 引擎哲学：游戏一开始，默认不拿任何武器 (-1 代表空手)
	update_weapon_indicator(-1) 
	
	if inventory_panel:
		origin_pos = inventory_panel.position
		inventory_panel.visible = false
		inventory_panel.modulate.a = 0
		# 游戏开始时刷新一次空背包
		refresh_inventory_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		_on_bag_button_pressed()

# --- 📥 数据更新与接收 ---
# 这个方法会被外界（如 PhysicItem）呼叫
func add_item(item_type: String, amount: int) -> void:
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
	# 1. 暴力美学：清空网格里所有的老格子
	for child in grid_container.get_children():
		child.queue_free()
	
	# 2. 拿到现在有的物品种类名单，比如 ["wood", "gold"]
	var item_keys = inventory_data.keys()
	
	# 3. 循环 21 次铺满格子
	for i in range(total_slots):
		var slot = slot_scene.instantiate() as InventorySlot
		slot.custom_minimum_size = SLOT_SIZE 
		grid_container.add_child(slot)
		
		# 4. 判断逻辑
		if i < item_keys.size():
			# 只要种类名单还没循环完，就把对应的数据填进去
			var key = item_keys[i]
			var icon = item_icons.get(key, null)
			var count = inventory_data[key]
			slot.update_slot(icon, count)
		else:
			# 种类发完了，剩下的全是空格子
			slot.update_slot(null, 0)

# --- ⚔️ 武器栏逻辑 ---
# --- ⚔️ 武器栏高级视觉交互 ---
func update_weapon_indicator(weapon_index: int) -> void:
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

# --- 🎒 背包开关动画逻辑 (保持你的原有代码不变) ---
func _on_bag_button_pressed() -> void:
	if not inventory_panel: return
	if inventory_panel.visible and inventory_panel.modulate.a > 0.1:
		_close_inventory_animation()
	else:
		_open_inventory_animation()

func _open_inventory_animation():
	inventory_panel.visible = true
	var tween = create_tween().set_parallel(true)
	inventory_panel.position = origin_pos + Vector2(0, 50)
	inventory_panel.modulate.a = 0.0
	tween.tween_property(inventory_panel, "position", origin_pos, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(inventory_panel, "modulate:a", 1.0, 0.2)

func _close_inventory_animation():
	var tween = create_tween().set_parallel(true)
	tween.tween_property(inventory_panel, "position", origin_pos + Vector2(0, 50), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(inventory_panel, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(func(): inventory_panel.visible = false)
