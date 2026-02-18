extends TextureRect
class_name InventorySlot # 注册格子类
# 背包/快捷栏格子：显示图标与数量，并处理拖拽与点击

# 引用子节点 (注意：这里找的是 Icon 和 Amount，不是树木的动画！)
@onready var icon_node: TextureRect = $Icon
@onready var amount_label: Label = $Amount
var item_type: String = ""
var count: int = 0
var slot_role: String = "inventory"
var slot_index: int = -1
# slot_role 用于区分“背包格子”与“快捷栏格子”

# --- 🔄 被动接收指令 ---
# Interface 叫它显示啥，它就显示啥，绝不自己做运算
func update_slot(item_texture: Texture2D, item_count: int, new_item_type: String = "") -> void:
	# 根据传入数据刷新图标与数量
	item_type = new_item_type
	self.count = item_count
	if item_texture:
		# 🟢 如果老板传了图，说明这个坑位有物品
		icon_node.texture = item_texture
		icon_node.visible = true
		
		# 只有数量大于 1 时才显示右下角的数字，看起来更专业
		if item_count > 1:
			amount_label.text = str(item_count)
			amount_label.visible = true
			_play_bounce_animation() # ✨ 数字变动时弹跳反馈
		else:
			amount_label.visible = false
	else:
		# 🔴 如果传了空图，说明这是个空坑位，隐藏图标和数字
		icon_node.visible = false
		amount_label.visible = false

# --- ✨ 视觉反馈层 ---
func _play_bounce_animation() -> void:
	# 数字更新时，将其放大1.5倍
	amount_label.scale = Vector2(1.5, 1.5)
	var tween = create_tween()
	# 利用弹簧缓动(TRANS_SPRING)平滑缩放回原来的 1.0 大小
	tween.tween_property(amount_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_SPRING)

func _get_drag_data(_at_position: Vector2) -> Variant:
	# 拖拽开始时返回数据，并创建预览图
	if item_type == "":
		return null
	var global_size = icon_node.get_global_rect().size
	if global_size == Vector2.ZERO:
		global_size = icon_node.size
	var preview = TextureRect.new()
	preview.texture = icon_node.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = global_size
	preview.size = global_size
	preview.position = -global_size * 0.5
	set_drag_preview(preview)
	return {"item_type": item_type, "count": count}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# 只有快捷栏允许放入物品
	if slot_role != "quick":
		return false
	if data is Dictionary and data.has("item_type"):
		return data["item_type"] != ""
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	# 把拖拽物品放入快捷栏
	if slot_role != "quick":
		return
	if data is Dictionary and data.has("item_type"):
		var interface = get_tree().get_first_node_in_group("interface")
		if interface:
			interface.assign_quick_slot(slot_index, data["item_type"])

func _gui_input(event: InputEvent) -> void:
	# 左键点击快捷栏时直接使用物品
	if slot_role != "quick":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var interface = get_tree().get_first_node_in_group("interface")
		if interface:
			interface.use_quick_slot(slot_index)
