extends RigidBody2D

# --- ⚙️ 配置区域 ---
@export_category("Drop Settings")
# 🔥 只要改这个名字，样子自动变！
@export var item_type: String = "wood" 

# 🔥 预先加载好两张图，代码自己选
var texture_wood = preload("res://Base_Object/Wood_Resource.png")
var texture_gold = preload("res://Base_Object/Gold_Resource.png")

@export_category("Audio")
@export var sfx_drop: AudioStream   
@export var sfx_pickup: AudioStream 

# --- 🔗 节点引用 ---
@onready var audio_player: AudioStreamPlayer2D = $AudioPlayer
@onready var sprite: Sprite2D = $Sprite2D

# --- 🚀 1. 初始化：自动换装 + 出生效果 ---
func _ready() -> void:
	# 🔥🔥🔥 核心修改：根据名字自动换图 🔥🔥🔥
	if sprite:
		if item_type == "wood":
			sprite.texture = texture_wood
		elif item_type == "gold":
			sprite.texture = texture_gold
	
	# 下面是之前的物理和动画逻辑...
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

# --- 2. 拾取逻辑 (保持不变) ---
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("peao") or body.name == "peao":
		_collect_item(body)

func _collect_item(target: Node2D) -> void:
	$Area2D.set_deferred("monitoring", false)
	set_deferred("freeze", true)
	set_deferred("linear_velocity", Vector2.ZERO)
	
	# 通知背包
	get_tree().call_group("interface", "add_item", item_type, 1)
	
	# 特效
	spawn_floating_text()
	
	if audio_player and sfx_pickup:
		audio_player.stream = sfx_pickup; audio_player.pitch_scale = randf_range(1.1, 1.3); audio_player.play()
	
	_animate_pickup_and_free(target)

# --- 3. 动画与特效 (保持不变) ---
func _animate_pickup_and_free(target: Node2D) -> void:
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
	label.z_index = 100 
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	get_tree().root.add_child(label)
	label.global_position = global_position + Vector2(-20, -45)
	var tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 40, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)
