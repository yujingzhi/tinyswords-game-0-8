extends StaticBody2D
class_name ObjectBase # 注册为全局类，方便以后类型提示

# --- 🌲 原有表现层配置 ---
@export var object_type: String = "Tree_" 
@export var variation_count: int = 4      

# --- ✨ 核心配置：生命与掉落 ---
@export_category("Object Stats")
@export var type: String = "Tree"          
@export var health: int = 6               

# 🔥🔥🔥 新增：物品掉落系统 🔥🔥🔥
@export_group("Drop Settings")
# 【导师注】核心参数！在编辑器里，Tree 填 "wood"，Gold 填 "gold"
@export var drop_item_type: String = "wood" 

@export var min_drop: int = 1  # 每次最少掉落几个
@export var max_drop: int = 3  # 每次最多掉落几个
@export var drop_item_scene: PackedScene # 掉落物预制体 (PhysicItem.tscn)
@export var drop_item_texture: Texture2D # (保留原有配置)

# --- 🔗 节点引用 ---
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D
@onready var aux_anim_player: AnimationPlayer = $AuxAnimationPlayer 

# --- 🚀 生命周期 ---
func _ready() -> void:
	# 随机变体逻辑：让环境看起来不那么单一
	var variation = (randi() % variation_count) + 1 
	var anim_name = object_type + str(variation) 
	if anim_player and anim_player.has_animation(anim_name):
		anim_player.play(anim_name)
		
	# 随机初始化生命值
	health = randi_range(4, 6)

# --- ⚔️ 受伤逻辑 ---
func update_health(damage: int) -> void:
	# 寻找玩家，仅仅是为了计算受击距离做 Debug 打印
	var player = get_tree().get_first_node_in_group("peao") 
	var dist = "未知"
	if player:
		dist = str(int(global_position.distance_to(player.global_position)))
	
	print("🔴 受击物体: ", name, " | 距离主角: ", dist)

	# 扣血并播放闪白动画
	health -= damage
	if aux_anim_player:
		aux_anim_player.play("hit")
	
	# 血量清零，进入死亡流转
	if health <= 0:
		die()

# --- 💀 死亡逻辑 (核心手术区) ---
func die() -> void:
	print("💀 物体死亡: ", name)
	
	# 如果配置了掉落物场景，才生成掉落
	if drop_item_scene:
		# 1. 随机决定本次爆几个物品
		var final_drop_count = randi_range(min_drop, max_drop)
		print("  💰 本次掉落数量: ", final_drop_count)

		# 2. 循环生成对应数量的物理掉落物
		for i in range(final_drop_count):
			var drop = drop_item_scene.instantiate() as PhysicItem
			
			# 💡 【向下注入哲学】告诉掉落物：“你是一块木头/金子”
			drop.item_type = drop_item_type
			
			# 把它放在自己死掉的位置
			drop.global_position = global_position
			
			# ⚠️ 防错：物理引擎运算期间不能直接改节点树，必须用 call_deferred 放到下一帧执行
			get_tree().current_scene.call_deferred("add_child", drop)
			
	# 从游戏世界中抹除自己
	queue_free()
