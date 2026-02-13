extends RigidBody2D
class_name PhysicItem # 注册全局类名

# --- ⚙️ 配置区域 ---
@export_category("Drop Settings")
# 🔥 重点逻辑：setget。只要外部(如 object_base)修改了它的值，立刻触发 set_item_type 刷新图片
@export var item_type: String = "wood": set = set_item_type

# 预加载图片资源，避免游戏运行时卡顿
var texture_wood = preload("res://Base_Object/Wood_Resource.png")
var texture_gold = preload("res://Base_Object/Gold_Resource.png")

@export_category("Audio")
@export var sfx_drop: AudioStream   
@export var sfx_pickup: AudioStream 

# 开关：是否是静态摆放的（地图自带的不乱弹，砍树爆的需要弹跳）
@export var is_static_spawn: bool = false 

# --- 🔗 节点引用 ---
@onready var audio_player: AudioStreamPlayer2D = $AudioPlayer
@onready var sprite: Sprite2D = $Sprite2D

# --- 🚀 1. 初始化 ---
func _ready() -> void:
	# 确保一开始图片就匹配 item_type
	_refresh_texture()
	
	# 如果是爆出来的，就给它一个随机冲力，呈现弹跳散落的物理效果
	if not is_static_spawn:
		lock_rotation = true # 锁定旋转，别让木头滚得四脚朝天
		var random_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		apply_impulse(random_dir * 200.0)
		
		# 变大弹出的果冻效果
		if sprite:
			sprite.scale = Vector2.ZERO 
			var tween = create_tween()
			tween.tween_property(sprite, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

# 当身份被改写时执行 (Setter)
func set_item_type(new_type: String) -> void:
	item_type = new_type
	# 确保节点已经加载完了再刷新图片，防报错
	if is_node_ready():
		_refresh_texture()

# 刷新对应的 UI 图标
func _refresh_texture() -> void:
	if sprite:
		if item_type == "gold":
			sprite.texture = texture_gold
		else:
			sprite.texture = texture_wood

# --- 📥 2. 核心交互 (你的碰撞体必须连接这个信号) ---
# 【导师提示】确保 RigidBody2D 的 Contact Monitor 开启，且 Max Contacts Reported > 0
func _on_body_entered(body: Node2D) -> void:
	# 容错：只允许主角触发拾取
	if body.is_in_group("player") or body.name == "Player":
		
		# 🟢 【向上通信哲学】呼叫 interface 大管家，让数据中心去加数字
		get_tree().call_group("interface", "add_item", item_type, 1)
		
		# 播放 "+1" 悬浮字特效
		spawn_floating_text()
		
		# 播放拾取音效 (稍微改变音调，避免重复听觉得烦)
		if audio_player and sfx_pickup:
			audio_player.stream = sfx_pickup
			audio_player.pitch_scale = randf_range(1.1, 1.3)
			audio_player.play()
		
		# 将物体吸向玩家并删除
		_animate_pickup_and_free(body)

# --- ✨ 3. 动画与特效 ---
func _animate_pickup_and_free(target: Node2D) -> void:
	# 关键：马上冻结物理，防止因为动画延迟导致被重复拾取 2 次
	set_deferred("freeze", true) 
	
	# 被吸走并消失的动画
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", target.global_position, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.3, 1.5), 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)

func spawn_floating_text() -> void:
	var label = Label.new()
	label.text = "+1" 
	var settings = LabelSettings.new()
	settings.font_size = 12                  
	settings.font_color = Color(0.2, 1.0, 0.2) 
	settings.outline_size = 4                
	settings.outline_color = Color.BLACK      
	label.label_settings = settings
	
	# 加到场景最外层，防止跟随物体移动
	get_tree().current_scene.add_child(label)
	label.global_position = global_position
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 30, 0.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(label.queue_free)
