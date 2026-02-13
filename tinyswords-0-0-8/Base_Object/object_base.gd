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

# --- 💀 死亡逻辑 (核心修改区) ---
func die() -> void:
	print("💀 物体死亡: ", name, " | 自身属性类型: ", type)
	
	if drop_item_scene:
		var final_drop_count = randi_range(min_drop, max_drop)
		print("  💰 本次掉落数量: ", final_drop_count)

		for i in range(final_drop_count):
			var drop = drop_item_scene.instantiate() 
			
			# 🌟 强力鉴定黑魔法：根据自身 type 决定掉什么！万无一失！
			var my_drop_type = "wood"
			if type == "Gold" or type == "Rock":
				my_drop_type = "gold"
				
			# 如果 drop 身上有 item_type 属性，强行赋值
			if "item_type" in drop:
				drop.item_type = my_drop_type
			
			drop.global_position = global_position
			get_tree().current_scene.call_deferred("add_child", drop)
			
	queue_free()
