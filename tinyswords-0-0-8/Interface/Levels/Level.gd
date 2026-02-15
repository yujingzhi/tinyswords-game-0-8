extends Node2D
class_name Level

# --- 配置变量 ---
# 1. 在检查器里，把 Tree.tscn 和 Rock.tscn 拖进这个数组
@export var object_scenes: Array[PackedScene] = []

# 2. 你想生成多少个物体？
@export var total_objects: int = 40
@export var sheep_scene: PackedScene
@export var total_sheep: int = 6
@export var sheep_roam_cell_radius: int = 4

# --- 节点引用 ---
# 注意：路径必须和你场景里的实际名字一致！
# 这是你在 Terrain 里画了蓝色方块的那一层 (通常设为透明)
@onready var spawn_layer: TileMapLayer = $Terrain/SpawnLayer
@onready var sheep_spawn_layer: TileMapLayer = $Terrain/SheepSpawnLayer

# 这是用来存放生成物体的容器 (开启了 Y-Sort 的那个 Node2D)
@onready var objects_container: Node2D = $Objects

func _ready() -> void:
	spawn_objects()
	spawn_sheep()
	
	# 🔥🔥🔥 启动延迟体检 🔥🔥🔥
	print("\n================ 🕵️‍♂️ 游戏体检开始 ================")
	await get_tree().create_timer(1.0).timeout # 等1秒让物体生成完
	
	# --- 1. 检查主角 (Peao) ---
	var player = get_tree().get_first_node_in_group("peao")
	if player:
		print("✅ 主角检查: 找到主角 '", player.name, "'")
		print("   - 分组: ", player.get_groups())
	else:
		printerr("❌ 主角检查失败: 没找到组名为 'peao' 的节点！")
		printerr("   -> 解决办法: 选中主角根节点 -> 节点(Node)面板 -> 分组 -> 添加 'peao'")

	# --- 2. 检查掉落配置 ---
	if object_scenes.is_empty():
		printerr("❌ 错误: Level 的 Object Scenes 是空的！")
	else:
		for i in range(object_scenes.size()):
			var scn = object_scenes[i]
			if scn:
				var instance = scn.instantiate()
				print("🔍 检查列表第 ", i, " 项: ", instance.name)
				
				# 检查是不是把掉落物填进来了
				if instance is RigidBody2D:
					printerr("   ❌ 严重错误: 你把【掉落物】(RigidBody2D) 填进了 Object Scenes！")
					printerr("   -> 它是: ", instance.name)
					printerr("   -> 解决办法: 必须换成 Gold.tscn 或 Tree.tscn (StaticBody2D)")
				
				# 检查金矿的配置
				elif "drop_item_scene" in instance:
					var drop = instance.drop_item_scene.instantiate()
					# 检查掉落物有没有脚本
					if drop.get_script() == null:
						printerr("   ❌ 严重错误: ", instance.name, " 掉落的物品没挂脚本！")
					else:
						print("   ✅ 掉落配置正常，掉落物脚本: ", drop.get_script().resource_path)
					drop.queue_free()
				
				instance.queue_free()
	print("================ 👨‍⚕️ 体检结束 ================\n")

func spawn_objects() -> void:
	# 1. 获取所有允许生成的格子坐标 (你在编辑器里画过的)
	var available_cells: Array[Vector2i] = spawn_layer.get_used_cells()
	
	# 如果没有画生成层，就报错并返回，防止游戏崩溃
	if available_cells.is_empty():
		print("错误：SpawnLayer 没有画任何格子！无法生成物体。")
		return
		
	# 2. 记录已经占用的格子，防止重叠
	var occupied_cells: Array[Vector2i] = []
	var spawned_count: int = 0
	
	# 3. 循环生成，直到数量达标
	while spawned_count < total_objects:
		# 从可用列表中随机挑一个坐标
		var random_cell = available_cells.pick_random()
		
		# 检查：如果这个格子已经生成过东西了，就跳过本次循环
		if random_cell in occupied_cells:
			continue
		
		# 检查：如果没有设置物体场景，就跳出
		if object_scenes.is_empty():
			print("错误：没有在 Inspector 里给 Object Scenes 赋值！")
			break
			
		# 4. 随机挑选一个物体 (树 或 石头)
		var random_object_scene = object_scenes.pick_random()
		var obj_instance = random_object_scene.instantiate()
		
		# 5. 设置位置
		# 关键步骤：把网格坐标 (例如 10, 5) 转成像素坐标 (例如 640, 320)
		obj_instance.position = spawn_layer.map_to_local(random_cell)
		
		# 6. 添加到场景
		objects_container.add_child(obj_instance)
		
		# ... 生成物体代码 ...

		# 7. 关键一步：把地盘圈起来！(九宫格防御)
		# 如果不写这段，电脑就会觉得这块地还是空的，下次还往这儿放
		occupied_cells.append(random_cell)                   # 正中心
		occupied_cells.append(random_cell + Vector2i(0, 1))  # 下
		occupied_cells.append(random_cell + Vector2i(0, -1)) # 上
		occupied_cells.append(random_cell + Vector2i(1, 0))  # 右
		occupied_cells.append(random_cell + Vector2i(-1, 0)) # 左
		
		# 如果还是重叠，把四个角也加上（防斜着穿模）
		occupied_cells.append(random_cell + Vector2i(1, 1))
		occupied_cells.append(random_cell + Vector2i(1, -1))
		occupied_cells.append(random_cell + Vector2i(-1, 1))
		occupied_cells.append(random_cell + Vector2i(-1, -1))
		
		spawned_count += 1
		
	print("生成完毕！共生成了 ", spawned_count, " 个物体。")

func spawn_sheep() -> void:
	var available_cells: Array[Vector2i] = sheep_spawn_layer.get_used_cells()
	if available_cells.is_empty():
		print("错误：SheepSpawnLayer 没有画任何格子！无法生成羊。")
		return
		
	if sheep_scene == null:
		print("错误：没有在 Inspector 里给 Sheep Scene 赋值！")
		return
		
	var occupied_cells: Array[Vector2i] = []
	var spawned_count: int = 0
	var target_total = min(total_sheep, available_cells.size())
	
	while spawned_count < target_total:
		var random_cell = available_cells.pick_random()
		if random_cell in occupied_cells:
			continue
			
		var sheep_instance = sheep_scene.instantiate()
		sheep_instance.position = sheep_spawn_layer.map_to_local(random_cell)
		objects_container.add_child(sheep_instance)
		if sheep_instance.has_method("setup_roam"):
			sheep_instance.setup_roam(sheep_spawn_layer, random_cell, sheep_roam_cell_radius)
		
		occupied_cells.append(random_cell)
		spawned_count += 1
