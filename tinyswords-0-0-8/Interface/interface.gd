extends CanvasLayer
class_name Interface

# --- ⚔️ 引用区域 ---
@onready var slots_container: HBoxContainer = $Avatar/HBoxContainer
@onready var inventory_panel: TileMapLayer = $TileMapLayer
@onready var grid_container: GridContainer = $TileMapLayer/InventoryGrid

# --- 🔥 配置区域 ---
# 必须在编辑器里把 InventorySlot.tscn 拖进来！
@export var slot_scene: PackedScene 

# 物品配置 (Key 必须全是小写，对应 PhysicItem 的 item_type)
@onready var item_icons: Dictionary = {
	"wood": preload("res://Base_Object/Wood_Resource.png"), 
	"gold": preload("res://Base_Object/Gold_Resource.png")
}

# --- 🌟 数据变量 ---
var origin_pos: Vector2
var total_slots: int = 21 # 🔥 固定生成 21 个格子
var inventory_data: Dictionary = {} 
const SLOT_SIZE = Vector2(96, 96)

func _ready() -> void:
	update_weapon_indicator(0)
	
	if inventory_panel:
		origin_pos = inventory_panel.position
		inventory_panel.visible = false
		inventory_panel.modulate.a = 0
		# 🚀 游戏启动时，立刻生成空网格
		refresh_inventory_ui()

# --- ⚔️ 武器栏逻辑 (保持不变) ---
func update_weapon_indicator(player_index: int) -> void:
	if not slots_container: return
	var slots = slots_container.get_children()
	var target_index = player_index - 1
	for i in range(slots.size()):
		var slot = slots[i]
		if slot.has_node("ColorRect"):
			slot.get_node("ColorRect").visible = (i == target_index)

# --- 🎒 背包数据更新 ---
func add_item(item_name: String, amount: int = 1) -> void:
	if item_name in inventory_data:
		inventory_data[item_name] += amount
	else:
		inventory_data[item_name] = amount
	
	print("🎒 获得物品:", item_name, " 总数:", inventory_data[item_name])
	refresh_inventory_ui()

# --- 🔥 核心：网格生成与刷新逻辑 (重写版) ---
func refresh_inventory_ui():
	# 安全检查
	if not grid_container or not slot_scene: 
		print("❌ 错误：GridContainer 或 Slot Scene 未设置！")
		return
	
	# 1. 清空当前所有格子 (防止重复生成)
	for child in grid_container.get_children():
		child.queue_free()
	
	# 2. 获取当前拥有的物品列表 ["wood", "gold"]
	var item_keys = inventory_data.keys()
	
	# 3. 循环固定次数，铺满网格
	for i in range(total_slots):
		# 实例化格子
		var slot = slot_scene.instantiate()
		slot.custom_minimum_size = SLOT_SIZE 
		grid_container.add_child(slot)
		
		# 4. 判断当前格子该填什么
		if i < item_keys.size():
			# 如果这个位置有物品
			var key = item_keys[i]
			var icon = item_icons.get(key, null)
			var count = inventory_data[key]
			slot.update_slot(icon, count)
		else:
			# 如果这个位置没物品 (空格子)
			slot.update_slot(null, 0)

# --- 🎒 动画逻辑 (保持不变) ---
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
	inventory_panel.modulate.a = 0
	tween.tween_property(inventory_panel, "modulate:a", 1.0, 0.2)
	tween.tween_property(inventory_panel, "position", origin_pos, 0.5)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _close_inventory_animation():
	var tween = create_tween().set_parallel(true)
	tween.tween_property(inventory_panel, "modulate:a", 0.0, 0.2)
	tween.tween_property(inventory_panel, "position", origin_pos + Vector2(0, 20), 0.2)
	tween.chain().tween_callback(func(): inventory_panel.visible = false)
