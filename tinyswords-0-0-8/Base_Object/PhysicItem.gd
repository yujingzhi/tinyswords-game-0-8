extends RigidBody2D
class_name PhysicItem

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
	"gold": preload("res://Base_Object/Gold_Resource.png")
	# 未来扩展示范： "stone": preload("res://Base_Object/Stone.png")
}

@export_category("Audio")
@export var sfx_drop: AudioStream   
@export var sfx_pickup: AudioStream 
@export var is_static_spawn: bool = false 

@onready var audio_player: AudioStreamPlayer2D = $AudioPlayer
@onready var sprite: Sprite2D = $Sprite2D
@onready var pickup_area: Area2D = $Area2D 

func _ready() -> void:
	collision_mask = 1 
	
	if is_instance_valid(pickup_area) and not pickup_area.body_entered.is_connected(_on_pickup_area_body_entered):
		pickup_area.body_entered.connect(_on_pickup_area_body_entered)
		
	_refresh_texture()
	
	if not is_static_spawn:
		lock_rotation = true 
		# 🌟 优化 3：全面补充强类型声明 (Vector2, Tween)
		var random_dir: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		
		# 🌟 优化 4：Godot 4 推荐使用 apply_central_impulse 直接作用于质心
		apply_central_impulse(random_dir * 200.0) 
		
		if is_instance_valid(sprite):
			sprite.scale = Vector2.ZERO 
			var tween: Tween = create_tween()
			tween.tween_property(sprite, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			
			var jump_tween: Tween = create_tween()
			jump_tween.tween_property(sprite, "offset:y", -45.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			jump_tween.tween_property(sprite, "offset:y", 0.0, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _refresh_texture() -> void:
	if is_instance_valid(sprite):
		# 🌟 优化 2 配合：直接从字典取图。如果找不到对应的，默认给 wood (防错设计)
		sprite.texture = ITEM_TEXTURES.get(item_type, ITEM_TEXTURES["wood"])

func _on_pickup_area_body_entered(body: Node2D) -> void:
	# 🌟 优化 5：使用 &"字符串" (StringName) 提升底层分组查询性能
	if body is CharacterBase or body.is_in_group(&"player") or body.is_in_group(&"peao"):
		# 完美联动 UI 系统
		get_tree().call_group(&"interface", &"add_item", item_type, 1)
		spawn_floating_text()
		
		if is_instance_valid(audio_player) and sfx_pickup:
			audio_player.stream = sfx_pickup
			audio_player.pitch_scale = randf_range(1.1, 1.3)
			audio_player.play()
		
		_animate_pickup_and_free(body)

func _animate_pickup_and_free(target: Node2D) -> void:
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
	var label: Label = Label.new()
	label.text = "+1" 
	var settings: LabelSettings = LabelSettings.new()
	settings.font_size = 12                  
	settings.font_color = Color(0.2, 1.0, 0.2) 
	settings.outline_size = 4                
	settings.outline_color = Color.BLACK      
	label.label_settings = settings
	label.z_index = 100 
	
	get_tree().current_scene.add_child(label)
	label.global_position = global_position
	
	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 30.0, 0.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(label.queue_free)
