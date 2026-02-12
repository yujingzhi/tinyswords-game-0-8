extends RigidBody2D

# --- ⚙️ 配置区域 ---
@export_category("Drop Settings")
# 🔥 这里必须填 "wood" (小写)，因为它是去 Interface 字典里查图片的“钥匙”
@export var item_type: String = "wood" 

@export_category("Audio")
@export var sfx_drop: AudioStream   # 拖入 SFX_Item_Drop.tres
@export var sfx_pickup: AudioStream # 拖入 SFX_Item_Pickup.tres

# --- 🔗 节点引用 ---
@onready var audio_player: AudioStreamPlayer2D = $AudioPlayer
@onready var sprite: Sprite2D = $Sprite2D

# --- 1. 初始化 (保持不变) ---
func _ready() -> void:
	lock_rotation = true 
	var random_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	apply_impulse(random_dir * 200.0)
	
	if sprite:
		sprite.scale = Vector2.ZERO 
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(1, 1), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var jump_tween = create_tween()
		jump_tween.tween_property(sprite, "offset:y", -45.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		jump_tween.tween_property(sprite, "offset:y", 0.0, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	if audio_player and sfx_drop:
		audio_player.stream = sfx_drop; audio_player.pitch_scale = randf_range(0.9, 1.1); audio_player.play()

# --- 2. 拾取逻辑 ---
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("peao") or body.name == "peao":
		_collect_item(body)

func _collect_item(target: Node2D) -> void:
	# 停止物理
	$Area2D.set_deferred("monitoring", false)
	set_deferred("freeze", true)
	set_deferred("linear_velocity", Vector2.ZERO)
	
	# 🎒 通知背包
	get_tree().call_group("interface", "add_item", item_type, 1)
	
	# ✨ 纯代码生成 "+1" 特效
	spawn_floating_text()
	
	# 🔊 播放音效
	if audio_player and sfx_pickup:
		audio_player.stream = sfx_pickup; audio_player.pitch_scale = randf_range(1.1, 1.3); audio_player.play()
	
	# 🎬 吸附动画并销毁
	_animate_pickup_and_free(target)

# --- 🎬 吸附动画 ---
func _animate_pickup_and_free(target: Node2D) -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", target.global_position, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.3, 1.5), 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)

# --- ✨✨✨ 纯代码 "+1" 特效 (修正版) ✨✨✨ ---
func spawn_floating_text() -> void:
	# 1. 创建 Label
	var label = Label.new()
	label.text = "+1" # 🔥 只显示 +1
	
	# 2. 设置样式 (纯代码描边)
	var settings = LabelSettings.new()
	settings.font_size = 12                  
	settings.font_color = Color(0.2, 1.0, 0.2) # 亮绿色
	settings.outline_size = 4                # 黑色描边 (关键！否则看不清)
	settings.outline_color = Color.BLACK     
	label.label_settings = settings
	
	label.z_index = 100 # 确保在最上层
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# 3. 加到【游戏根节点】，确保不受掉落物销毁影响
	get_tree().root.add_child(label)
	
	# 设置初始位置 (物品头顶)
	label.global_position = global_position + Vector2(-20, -45)
	
	# 4. 动画：向上飘 + 变透明
	var tween = label.create_tween()
	tween.set_parallel(true)
	
	# 向上飘
	tween.tween_property(label, "global_position:y", label.global_position.y - 40, 0.6)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 变透明 (0.3秒后开始变淡)
	tween.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.3)
	
	# 5. 🔥🔥🔥 绝对销毁 🔥🔥🔥
	# 动画播完，立即删除 Label，绝不残留
	tween.chain().tween_callback(label.queue_free)
