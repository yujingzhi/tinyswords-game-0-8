extends RigidBody2D
class_name PhysicItem

@export_category("Drop Settings")
@export var item_type: String = "wood": set = set_item_type

var texture_wood = preload("res://Base_Object/Wood_Resource.png")
var texture_gold = preload("res://Base_Object/Gold_Resource.png")

@export_category("Audio")
@export var sfx_drop: AudioStream   
@export var sfx_pickup: AudioStream 
@export var is_static_spawn: bool = false 

@onready var audio_player: AudioStreamPlayer2D = $AudioPlayer
@onready var sprite: Sprite2D = $Sprite2D
# 🌟 关键：引用旧版 tscn 里自带的 Area2D，它才是真正的拾取触发器！
@onready var pickup_area: Area2D = $Area2D 

func _ready() -> void:
	# 🌟 物理层防阻挡黑魔法：
	# 让 RigidBody 失去与主角的物理碰撞（防止推着走），只保留重力和摩擦力
	collision_mask = 1 # 假设 1 是默认地形
	
	# 让 Area2D 负责检测主角
	if pickup_area and not pickup_area.body_entered.is_connected(_on_pickup_area_body_entered):
		pickup_area.body_entered.connect(_on_pickup_area_body_entered)
		
	_refresh_texture()
	
	if not is_static_spawn:
		lock_rotation = true 
		var random_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		apply_impulse(random_dir * 200.0) # 给一个爆出的力度
		
		if sprite:
			sprite.scale = Vector2.ZERO 
			var tween = create_tween()
			# 旧版的神仙弹跳表现，我帮你保留并优化了
			tween.tween_property(sprite, "scale", Vector2(1, 1), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			var jump_tween = create_tween()
			jump_tween.tween_property(sprite, "offset:y", -45.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			jump_tween.tween_property(sprite, "offset:y", 0.0, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func set_item_type(new_type: String) -> void:
	item_type = new_type
	if is_node_ready():
		_refresh_texture()

func _refresh_texture() -> void:
	if sprite:
		if item_type == "gold":
			sprite.texture = texture_gold
		else:
			sprite.texture = texture_wood

# 🌟 注意：这里改成了 Area2D 的触发函数
func _on_pickup_area_body_entered(body: Node2D) -> void:
	if body is CharacterBase or body.is_in_group("player") or body.is_in_group("peao"):
		get_tree().call_group("interface", "add_item", item_type, 1)
		spawn_floating_text()
		
		if audio_player and sfx_pickup:
			audio_player.stream = sfx_pickup
			audio_player.pitch_scale = randf_range(1.1, 1.3)
			audio_player.play()
		
		_animate_pickup_and_free(body)

func _animate_pickup_and_free(target: Node2D) -> void:
	set_deferred("freeze", true) 
	if pickup_area:
		pickup_area.set_deferred("monitoring", false) # 关闭触发，防止连续拾取两次
		
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
	
	# 必须先加到场景树里，才能调用 create_tween
	get_tree().current_scene.add_child(label)
	label.global_position = global_position
	
	# 🌟 导师级防错：让 label 自己创建缓动！
	# 这样就算掉落物被删了，这个文字动画依然能独立播完并销毁自己！
	var tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 30, 0.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	# 动画播完，精准超度自己
	tween.chain().tween_callback(label.queue_free)
