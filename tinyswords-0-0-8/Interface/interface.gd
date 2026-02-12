extends CanvasLayer
class_name Interface

# --- ⚔️ 区域一：武器栏引用 ---
@onready var slots_container: HBoxContainer = $Avatar/HBoxContainer

# --- 🎒 区域二：背包引用 ---
@onready var inventory_panel: TileMapLayer = $TileMapLayer
@onready var grid_container: GridContainer = $TileMapLayer/InventoryGrid

# --- 🔥 背包配置 ---
@export var slot_scene: PackedScene 

# 物品图标配置 (请确保路径正确)
@onready var item_icons: Dictionary = {
	"wood": preload("res://Base_Object/Wood_Resource.png"), 
	"gold": preload("res://Base_Object/Gold_Resource.png")
}

# --- 🌟 数据变量 ---
var origin_pos: Vector2
var total_slots: int = 21
var inventory_data: Dictionary = {} 
const SLOT_SIZE = Vector2(96, 96)

func _ready() -> void:
	update_weapon_indicator(0)
	
	if inventory_panel:
		origin_pos = inventory_panel.position
		inventory_panel.visible = false
		inventory_panel.modulate.a = 0
		refresh_inventory_ui()

# --- ⚔️ 武器栏逻辑 ---
func update_weapon_indicator(player_index: int) -> void:
	if not slots_container: return
	var slots = slots_container.get_children()
	var target_index = player_index - 1
	for i in range(slots.size()):
		var slot = slots[i]
		if slot.has_node("ColorRect"):
			var indicator = slot.get_node("ColorRect")
			indicator.visible = (i == target_index)

# --- 🎒 背包核心逻辑 ---
func add_item(item_name: String, amount: int = 1) -> void:
	if item_name in inventory_data:
		inventory_data[item_name] += amount
	else:
		inventory_data[item_name] = amount
	refresh_inventory_ui()

func refresh_inventory_ui():
	if not grid_container or not slot_scene: return
	
	# 1. 清空当前所有格子
	for child in grid_container.get_children():
		child.queue_free()
	
	# 2. 将字典数据转为数组，方便索引访问
	# 结果类似于: ["wood", "gold"]
	var item_keys = inventory_data.keys()
	
	# 3. 🔥 核心：循环固定次数（total_slots = 21）
	for i in range(total_slots):
		# 实例化格子模具
		var slot = slot_scene.instantiate()
		slot.custom_minimum_size = SLOT_SIZE 
		grid_container.add_child(slot)
		
		# 4. 填充逻辑
		if i < item_keys.size():
			# 如果当前索引有对应的物资
			var item_name = item_keys[i]
			var icon = item_icons.get(item_name, null)
			var count = inventory_data[item_name]
			
			if slot.has_method("update_slot"):
				slot.update_slot(icon, count)
		else:
			# 如果超出了物资数量，则显示为空格子
			if slot.has_method("update_slot"):
				slot.update_slot(null, 0) # 传入 null 会触发你在 slot 脚本里写的隐藏图标逻辑

# --- 🎒 动画逻辑 (之前的报错也是因为缺了这个！) ---
func _on_bag_button_pressed() -> void:
	if not inventory_panel: return
	if inventory_panel.visible and inventory_panel.modulate.a > 0.1:
		_close_inventory_animation()
	else:
		_open_inventory_animation()

func _open_inventory_animation():
	inventory_panel.visible = true
	var tween = create_tween()
	inventory_panel.position = origin_pos + Vector2(0, 50)
	inventory_panel.modulate.a = 0
	tween.set_parallel(true)
	tween.tween_property(inventory_panel, "modulate:a", 1.0, 0.2)
	tween.tween_property(inventory_panel, "position", origin_pos, 0.5)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _close_inventory_animation():
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(inventory_panel, "modulate:a", 0.0, 0.2)
	tween.tween_property(inventory_panel, "position", origin_pos + Vector2(0, 20), 0.2)
	tween.chain().tween_callback(func(): inventory_panel.visible = false)
