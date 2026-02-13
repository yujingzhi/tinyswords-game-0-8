extends TextureRect
class_name InventorySlot # 注册格子类

# 引用子节点 (注意：这里找的是 Icon 和 Amount，不是树木的动画！)
@onready var icon_node: TextureRect = $Icon
@onready var amount_label: Label = $Amount

# --- 🔄 被动接收指令 ---
# Interface 叫它显示啥，它就显示啥，绝不自己做运算
func update_slot(item_texture: Texture2D, count: int) -> void:
	if item_texture:
		# 🟢 如果老板传了图，说明这个坑位有物品
		icon_node.texture = item_texture
		icon_node.visible = true
		
		# 只有数量大于 1 时才显示右下角的数字，看起来更专业
		if count > 1:
			amount_label.text = str(count)
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
