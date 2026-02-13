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
	"gold": preload("res://Base_Object/Gold_Resource.png")
}

# --- 🌟 数据中枢 ---
var origin_pos: Vector2
var total_slots: int = 21 # 背包总共有多少格子
const SLOT_SIZE = Vector2(96, 96)

# 💡【核心数据】这是你真正的背包，所有加减全在这发生
var inventory_data: Dictionary = {} 

# --- 🚀 初始化 ---
func _ready() -> void:
	# 🌟【架构解耦】把自己加入 interface 组，外界不需要知道你的路径，发消息就能找到你
	add_to_group("interface")
	
	update_weapon_indicator(0)
	
	if inventory_panel:
		origin_pos = inventory_panel.position
		inventory_panel.visible = false
		inventory_panel.modulate.a = 0
		# 游戏开始时刷新一次空背包
		refresh_inventory_ui()

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

# --- ⚔️ 武器栏逻辑 (保留你的原有代码流) ---
func update_weapon_indicator(player_index: int) -> void:
	if not slots_container: return
	var slots = slots_container.get_children()
	# 你的武器轮换逻辑写在这里...
	pass

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
