extends StaticBody2D
class_name ObjectBase # 注册为全局类，方便以后类型提示
# 可破坏的场景物体基类，例如树与矿石

signal destroyed(object_type: String, drop_type: String, world_position: Vector2)

# --- 🌲 原有表现层配置 ---
@export var object_type: String = "Tree_" 
@export var variation_count: int = 4      
# object_type + variation 组合出动画名，例如 Tree_1

# --- ✨ 核心配置：生命与掉落 ---
@export_category("Object Stats")
@export var type: String = "Tree"          
@export var health: int = 6               
# type 用于工具匹配，health 为可破坏生命值

# 🔥🔥🔥 新增：物品掉落系统 🔥🔥🔥
@export_group("Drop Settings")
# 【导师注】核心参数！在编辑器里，Tree 填 "wood"，Gold 填 "gold"
@export var drop_item_type: String = "wood" 
# 掉落的物品类型字符串

@export var min_drop: int = 1  # 每次最少掉落几个
@export var max_drop: int = 3  # 每次最多掉落几个
@export var drop_item_scene: PackedScene # 掉落物预制体 (PhysicItem.tscn)
@export var drop_item_texture: Texture2D # (保留原有配置)
# drop_item_scene 决定掉落物实例的类型
@export var redwood_seed_drop_chance: float = 0.04
@export var redwood_seed_item_type: String = "redwood_seed"

# --- 🔗 节点引用 ---
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D
@onready var aux_anim_player: AnimationPlayer = $AuxAnimationPlayer 
# aux_anim_player 用于播放受击闪烁

# --- 🚀 生命周期 ---
func _ready() -> void:
	# 初始化随机外观，并加入障碍物分组
	add_to_group("obstacle")
	# 【导师修正】Godot 4.x 推荐使用 randi_range() 进行安全且均等的区间随机
	if variation_count > 0:
		var variation: int = randi_range(1, variation_count) 
		var anim_name: String = object_type + str(variation) 
		
		# 【导师防错防御】检查动画节点是否存在，以及动画列表中是否确实包含该动画
		if is_instance_valid(anim_player) and anim_player.has_animation(anim_name):
			anim_player.play(anim_name)
		else:
			push_warning("【导师警告】未找到动画: " + anim_name + "，请核对 AnimationPlayer 中的命名规范！")
		
	# 随机初始化生命值
	health = randi_range(4, 6)

# --- ⚔️ 受伤逻辑 ---
func update_health(damage: int) -> void:
	# 受到伤害时扣血并播放受击动画
	# 严格的类型注解与防错
	var player: Node = get_tree().get_first_node_in_group("peao") 
	var dist: String = "未知"
	
	if is_instance_valid(player) and player is Node2D:
		dist = str(int(global_position.distance_to(player.global_position)))
	
	print("🔴 受击物体: ", name, " | 距离主角: ", dist)
	
	# 扣血并播放闪白动画
	health -= damage
	if is_instance_valid(aux_anim_player) and aux_anim_player.has_animation("hit"):
		aux_anim_player.play("hit")
	
	# 血量清零，进入死亡流转
	if health <= 0:
		die()

# --- 💀 死亡逻辑 (终极完整版) ---
func die() -> void:
	# 死亡后生成掉落物并销毁自身
	print("💀 物体死亡: ", name, " | 准备掉落: ", drop_item_type)
	destroyed.emit(type, drop_item_type, global_position)
	
	if drop_item_scene:
		var final_drop_count = randi_range(min_drop, max_drop)
		for i in range(final_drop_count):
			var drop_instance = drop_item_scene.instantiate()
			if drop_instance:
				get_parent().call_deferred("add_child", drop_instance)
				
				# ✨✨✨ 核心解法 1：暴力注入身份 ✨✨✨
				# 既然没有 initialize_item，我们直接给它的属性赋值！
				if "item_type" in drop_instance:
					drop_instance.item_type = self.drop_item_type 
				if drop_item_type == "rainbow_gold" and sprite != null and is_instance_valid(sprite):
					if "has_custom_item_modulate" in drop_instance:
						drop_instance.has_custom_item_modulate = true
					if "custom_item_modulate" in drop_instance:
						drop_instance.custom_item_modulate = sprite.modulate
				
				# ✨✨✨ 核心解法 2：强制它立刻换衣服 ✨✨✨
				# 防止它拿着 "gold" 的身份还穿着 "wood" 的图
				if drop_instance.has_method("_refresh_texture"):
					drop_instance.call_deferred("_refresh_texture")
					
				var random_offset = Vector2(randf_range(-15.0, 15.0), randf_range(-15.0, 15.0))
				drop_instance.set_deferred("global_position", global_position + random_offset)
		if type == "Tree" and drop_item_type == "wood" and redwood_seed_drop_chance > 0.0 and randf() < redwood_seed_drop_chance:
			var seed_instance = drop_item_scene.instantiate()
			if seed_instance:
				get_parent().call_deferred("add_child", seed_instance)
				if "item_type" in seed_instance:
					seed_instance.item_type = redwood_seed_item_type
				if seed_instance.has_method("_refresh_texture"):
					seed_instance.call_deferred("_refresh_texture")
				var seed_offset = Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
				seed_instance.set_deferred("global_position", global_position + seed_offset)
				
	queue_free()
