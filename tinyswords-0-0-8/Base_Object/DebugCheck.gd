extends Node

func _ready() -> void:
	print("\n================ 🕵️‍♂️ 游戏体检开始 ================")
	await get_tree().create_timer(1.0).timeout # 等1秒让其他东西先生成完
	
	# --- 1. 检查主角 (Peao) ---
	var player = get_tree().get_first_node_in_group("peao")
	if player:
		print("✅ 主角检查: 找到主角 '", player.name, "'")
		print("   - 分组: ", player.get_groups())
		print("   - 碰撞层 (Layer): ", player.collision_layer)
	else:
		printerr("❌ 主角检查失败: 没找到组名为 'peao' 的节点！")
		printerr("   -> 解决办法: 选中主角根节点 -> 节点(Node)面板 -> 分组 -> 添加 'peao'")

	# --- 2. 检查关卡配置 (Level) ---
	var level = get_parent() # 假设你把这个脚本挂在 Level 下面
	if "object_scenes" in level:
		print("\n✅ 关卡生成器检查:")
		var scenes = level.object_scenes
		if scenes.is_empty():
			printerr("❌ 错误: Level 的 Object Scenes 是空的！")
		else:
			for i in range(scenes.size()):
				var scn = scenes[i]
				if scn:
					var instance = scn.instantiate()
					if instance is RigidBody2D:
						printerr("❌ 严重错误 (索引", i, "): 你把【掉落物】(RigidBody2D) 塞进了地图生成列表！")
						printerr("   -> 它是: ", instance.name)
						printerr("   -> 解决办法: 去 Level 检查器里，把它换成 Gold.tscn 或 Tree.tscn (StaticBody2D)")
					elif instance is StaticBody2D:
						print("✅ 场景 ", i, " 正常: 是静态物体 (", instance.name, ")")
						# 顺便查查它的掉落物配置
						_check_drop_config(instance)
					instance.queue_free()
	else:
		print("⚠️ 警告: 父节点好像不是 Level (没找到 object_scenes 变量)，跳过地图检查。")

	print("================ 👨‍⚕️ 体检结束 ================\n")

func _check_drop_config(obj):
	if "drop_item_scene" in obj:
		var drop_scn = obj.drop_item_scene
		if drop_scn:
			var drop = drop_scn.instantiate()
			print("   🔍 检查掉落物配置 (", obj.name, " -> ", drop.name, "):")
			
			# A. 检查脚本
			var script = drop.get_script()
			if script:
				print("      ✅ 脚本已挂载: ", script.resource_path)
			else:
				printerr("      ❌ 严重错误: 掉落物没有挂载脚本！")
				printerr("      -> 解决办法: 打开 ", drop.name, ".tscn，把 PhysicItem.gd 拖给根节点。")
			
			# B. 检查碰撞监测 (Area2D)
			var area = drop.get_node_or_null("Area2D")
			if area:
				# 检查 Mask (是否能看见主角)
				# 主角通常在第1层 (Value 1)
				if area.collision_mask & 1: 
					print("      ✅ 碰撞掩码 (Mask): 正常 (包含第1层)")
				else:
					printerr("      ❌ 错误: Area2D 看不见主角！(Mask 第1层未勾选)")
			else:
				printerr("      ❌ 错误: 掉落物里没有叫 'Area2D' 的子节点！")
			
			drop.queue_free()
		else:
			printerr("   ❌ 错误: ", obj.name, " 没有设置 Drop Item Scene！")
