extends RigidBody2D
class_name PhysicItem
# 掉落物逻辑：生成时弹起、玩家接触拾取、播放特效与音效

@export_category("Drop Settings")
# 🌟 优化 1：整合了 Setter 逻辑，删除了下方冗余的 set_item_type 函数
@export var item_type: String = "wood": 
	set(value):
		item_type = value
		# 使用 is_node_ready() 确保节点已加载，防止在编辑器里拖拽时报错
		if is_node_ready():
			_refresh_texture()

# 🌟 优化 2：物品图鉴字典！彻底告别 if-else，扩展性拉满！
const ITEM_TEXTURES: Dictionary = {
	"wood": preload("res://Base_Object/Wood_Resource.png"),
	"gold": preload("res://Base_Object/Gold_Resource.png"),
	"meat": preload("res://Base_Object/Resources/Meat/Meat_Resource.png")
	# 未来扩展示范： "stone": preload("res://Base_Object/Stone.png")
}
# ITEM_TEXTURES 是“物品类型 -> 贴图”映射表
var custom_item_modulate: Color = Color(1, 1, 1, 1)
var has_custom_item_modulate: bool = false
var pickup_fx_defs: Array[Dictionary] = [
	{"texture": preload("res://Assets/FX/Particles/Dust_01.png"), "frames": 8},
	{"texture": preload("res://Assets/FX/Particles/Dust_02.png"), "frames": 10},
	{"texture": preload("res://Assets/FX/Particles/Water Splash.png"), "frames": 9}
]
# 拾取时随机播放的粒子特效配置

@export_category("Audio")
@export var sfx_drop: AudioStream   
@export var sfx_pickup: AudioStream 
@export var is_static_spawn: bool = false 
# is_static_spawn 为 true 表示静态生成，不做弹起动画

@onready var audio_player: AudioStreamPlayer2D = $AudioPlayer
@onready var sprite: Sprite2D = $Sprite2D
@onready var text_label: Label = $TextLabel
@onready var pickup_area: Area2D = $Area2D 
# pickup_area 用于检测玩家接近

func _ready() -> void:
	# 初始化碰撞层，并连接拾取回调
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	add_to_group(&"pickup_item")
	
	if is_instance_valid(pickup_area) and not pickup_area.body_entered.is_connected(_on_pickup_area_body_entered):
		pickup_area.body_entered.connect(_on_pickup_area_body_entered)
		
	_refresh_texture()
	# 非静态生成时增加弹跳与缩放效果
	if not is_static_spawn:
		set_deferred("lock_rotation", true) 
		# 🌟 优化 3：全面补充强类型声明 (Vector2, Tween)
		var random_dir: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		
		# 🌟 优化 4：Godot 4 推荐使用 apply_central_impulse 直接作用于质心
		call_deferred("apply_central_impulse", random_dir * 200.0) 
		
		if is_instance_valid(sprite):
			sprite.scale = Vector2.ZERO 
			var tween: Tween = create_tween()
			tween.tween_property(sprite, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			
			var jump_tween: Tween = create_tween()
			jump_tween.tween_property(sprite, "offset:y", -45.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			jump_tween.tween_property(sprite, "offset:y", 0.0, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _refresh_texture() -> void:
	# 根据 item_type 切换贴图
	if is_instance_valid(sprite):
		if item_type != "rainbow_gold":
			has_custom_item_modulate = false
			custom_item_modulate = Color(1, 1, 1, 1)
		if item_type == "redwood_seed":
			sprite.texture = null
			sprite.modulate = Color(1, 1, 1, 1)
			if text_label:
				text_label.text = "红木种子"
				text_label.modulate = Color(1.0, 0.35, 0.35, 1.0)
				text_label.visible = true
		elif item_type == "redwood":
			sprite.texture = ITEM_TEXTURES.get("wood", null)
			sprite.modulate = Color(1.0, 0.25, 0.25, 1.0)
			if text_label:
				text_label.visible = false
		elif item_type == "red_meat":
			sprite.texture = ITEM_TEXTURES.get("meat", null)
			sprite.modulate = Color(1.0, 0.25, 0.25, 1.0)
			if text_label:
				text_label.visible = false
		elif item_type == "rainbow_gold":
			sprite.texture = ITEM_TEXTURES.get("gold", null)
			if not has_custom_item_modulate:
				has_custom_item_modulate = true
				custom_item_modulate = Color.from_hsv(randf(), 0.75, 1.0, 1.0)
			sprite.modulate = custom_item_modulate
			if text_label:
				text_label.visible = false
		elif item_type == "lamb":
			sprite.texture = null
			sprite.modulate = Color(1, 1, 1, 1)
			if text_label:
				text_label.text = "羊仔"
				text_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
				text_label.visible = true
		else:
			# 🌟 优化 2 配合：直接从字典取图。如果找不到对应的，默认给 wood (防错设计)
			sprite.texture = ITEM_TEXTURES.get(item_type, ITEM_TEXTURES["wood"])
			sprite.modulate = Color(1, 1, 1, 1)
			if text_label:
				text_label.visible = false

func _on_pickup_area_body_entered(body: Node2D) -> void:
	# 🌟 优化 5：使用 &"字符串" (StringName) 提升底层分组查询性能
	if body.has_method("receive_pickup"):
		var accepted = body.call("receive_pickup", item_type)
		if accepted:
			_spawn_pickup_fx()
			_animate_pickup_and_free(body)
		return
	if body is CharacterBase or body.is_in_group(&"player") or body.is_in_group(&"peao"):
		# 通知 UI 增加物品数量
		get_tree().call_group(&"interface", &"add_item", item_type, 1)
		spawn_floating_text()
		_spawn_pickup_fx()
		
		if is_instance_valid(audio_player) and sfx_pickup:
			audio_player.stream = sfx_pickup
			audio_player.pitch_scale = randf_range(1.1, 1.3)
			audio_player.play()
		
		_animate_pickup_and_free(body)

func auto_collect() -> void:
	get_tree().call_group(&"interface", &"add_item", item_type, 1)
	spawn_floating_text()
	_spawn_pickup_fx()
	if is_instance_valid(audio_player) and sfx_pickup:
		audio_player.stream = sfx_pickup
		audio_player.pitch_scale = randf_range(1.1, 1.3)
		audio_player.play()
	queue_free()

func _animate_pickup_and_free(target: Node2D) -> void:
	# 拾取时向玩家飞去并淡出销毁
	set_deferred("freeze", true) 
	if is_instance_valid(pickup_area):
		pickup_area.set_deferred("monitoring", false) 
		
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", target.global_position, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.3, 1.5), 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)

func spawn_floating_text() -> void:
	# 创建飘字提示 +1
	var label: Label = Label.new()
	if item_type == "redwood_seed":
		label.text = "+红木种子"
	elif item_type == "redwood":
		label.text = "+红木+5"
	elif item_type == "red_meat":
		label.text = "+红肉+5"
	elif item_type == "rainbow_gold":
		label.text = "+彩矿+5"
	elif item_type == "lamb":
		label.text = "+羊仔"
	else:
		label.text = "+1"
	var settings: LabelSettings = LabelSettings.new()
	settings.font_size = 24                  
	if item_type == "redwood_seed" or item_type == "redwood" or item_type == "red_meat":
		settings.font_color = Color(1.0, 0.35, 0.35)
	elif item_type == "rainbow_gold":
		settings.font_color = Color(0.95, 0.85, 1.0)
	else:
		settings.font_color = Color(0.2, 1.0, 0.2) 
	settings.outline_size = 6                
	settings.outline_color = Color.BLACK      
	label.label_settings = settings
	label.z_index = 100 
	
	get_tree().current_scene.add_child(label)
	label.global_position = global_position
	
	var move_tween: Tween = label.create_tween()
	move_tween.set_parallel(true)
	move_tween.tween_property(label, "global_position:y", label.global_position.y - 46.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	move_tween.tween_property(label, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	move_tween.chain().tween_callback(label.queue_free)
	
	var scale_tween: Tween = label.create_tween()
	scale_tween.tween_property(label, "scale", Vector2(1.35, 1.35), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_SPRING)

func _spawn_pickup_fx() -> void:
	# 拾取时播放粒子特效
	if pickup_fx_defs.is_empty():
		return
	var fx = pickup_fx_defs.pick_random()
	var texture = fx["texture"]
	var frame_count = int(fx["frames"])
	if texture == null or frame_count <= 0:
		return
	var fx_sprite = AnimatedSprite2D.new()
	fx_sprite.sprite_frames = _build_fx_frames(texture, frame_count, 12.0)
	fx_sprite.animation = "fx"
	fx_sprite.global_position = global_position + Vector2(0, -8)
	fx_sprite.scale = Vector2(0.6, 0.6)
	fx_sprite.z_index = 15
	var root = get_tree().current_scene
	if root:
		root.add_child(fx_sprite)
	fx_sprite.play()
	if not fx_sprite.animation_finished.is_connected(fx_sprite.queue_free):
		fx_sprite.animation_finished.connect(fx_sprite.queue_free)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(fx_sprite, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(fx_sprite, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(fx_sprite.queue_free)

func _build_fx_frames(texture: Texture2D, frame_count: int, fps: float) -> SpriteFrames:
	# 将贴图切成动画帧
	var frames = SpriteFrames.new()
	frames.add_animation("fx")
	var frame_width = texture.get_width() / float(frame_count)
	var frame_height = texture.get_height()
	for i in range(frame_count):
		var atlas = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * frame_width, 0, frame_width, frame_height)
		frames.add_frame("fx", atlas)
	frames.set_animation_speed("fx", fps)
	frames.set_animation_loop("fx", false)
	return frames
