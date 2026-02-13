extends StaticBody2D
class_name ObjectBase

# --- 原有配置 ---
@export var object_type: String = "Tree_" 
@export var variation_count: int = 4      

# --- ✨ 配置：属性与掉落 ---
@export_category("Object Stats")
@export var type: String = "Tree"          
@export var health: int = 6               

# 🔥🔥🔥 新增：数量控制 (可以在编辑器里为树和矿设不同的值) 🔥🔥🔥
@export_group("Drop Amounts")
@export var min_drop: int = 1  # 最少掉落数量
@export var max_drop: int = 3  # 最多掉落数量

@export_group("Drop Resources")
@export var drop_item_scene: PackedScene
@export var drop_item_texture: Texture2D

# --- 节点引用 ---
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D
@onready var aux_anim_player: AnimationPlayer = $AuxAnimationPlayer 

func _ready() -> void:
	# 随机变体逻辑
	var variation = (randi() % variation_count) + 1 
	var anim_name = object_type + str(variation) 
	if anim_player.has_animation(anim_name):
		anim_player.play(anim_name)
		
	# 初始化生命值
	health = randi_range(4, 6)

# --- 受伤逻辑 ---
func update_health(damage: int) -> void:
	var player = get_tree().get_first_node_in_group("peao") 
	var dist = "未知"
	if player:
		dist = str(int(global_position.distance_to(player.global_position)))
	
	print("🔴 受击物体: ", name, " | 距离主角: ", dist)

	health -= damage
	if aux_anim_player:
		aux_anim_player.play("hit")
	if health <= 0:
		die()


func _resolve_drop_item_type() -> String:
	var normalized = String(type).to_lower()
	if normalized == "tree":
		return "wood"
	if normalized == "gold":
		return "gold"
	return normalized

# --- 死亡逻辑 (核心修改区) ---
func die() -> void:
	print("💀 物体死亡: ", name)
	
	if drop_item_scene:
		# 🔥🔥🔥 1. 计算本次掉落的总数 🔥🔥🔥
		var final_drop_count = randi_range(min_drop, max_drop)
		var drop_type = _resolve_drop_item_type()
		print("  💰 本次掉落数量: ", final_drop_count, " | 类型: ", drop_type)

		# 🔥🔥🔥 2. 使用循环生成掉落物 🔥🔥🔥
		for i in range(final_drop_count):
			var item = drop_item_scene.instantiate()
			if "item_type" in item:
				item.item_type = drop_type
			
			# 换肤逻辑
			var sprite_node = item.find_child("Sprite2D", true, false)
			if drop_item_texture and sprite_node:
				sprite_node.texture = drop_item_texture
			
			# 设置位置 (稍微偏移一点点，防止重叠得太完美)
			var offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
			item.global_position = global_position + offset
			
			# 延迟添加到场景
			get_parent().call_deferred("add_child", item)
			
		print("  ✅ 所有掉落物已生成完毕")
	else:
		print("  ❌ 错误：未配置 drop_item_scene")
	
	queue_free()
