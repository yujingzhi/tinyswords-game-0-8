extends TextureRect

# 引用子节点
@onready var icon_node: TextureRect = $Icon
@onready var amount_label: Label = $Amount

# 🔄 刷新格子的核心逻辑
func update_slot(item_texture: Texture2D, count: int) -> void:
	if item_texture:
		# 有物品：显示图标和数量
		icon_node.texture = item_texture
		icon_node.visible = true
		
		# 只有数量 > 1 时才显示数字
		if count > 1:
			amount_label.text = str(count)
			amount_label.visible = true
		else:
			amount_label.visible = false
	else:
		# 没有物品：隐藏图标和数字，只露出根节点的背景图
		icon_node.visible = false
		amount_label.visible = false
