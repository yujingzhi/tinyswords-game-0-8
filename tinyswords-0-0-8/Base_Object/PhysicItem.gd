extends RigidBody2D
class_name PhysicItem 

# --- ⚙️ 配置区域 ---
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

func _ready() -> void:
	# 🌟 导师级防错黑魔法：强制开启物理接触监听，再也不用在面板里手动勾选了！
	contact_monitor = true
	max_contacts_reported = 5
	
	_refresh_texture()
	
	if not is_static_spawn:
		lock_rotation = true 
		var random_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		apply_impulse(random_dir * 200.0)
		
		if sprite:
			sprite.scale = Vector2.ZERO 
			var tween = create_tween()
			tween.tween_property(sprite, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

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

func _on_body_entered(body: Node2D) -> void:
	# 🌟 极致鸭子类型：只要你是角色基类，或者在相关分组里，都能捡！绝不漏判！
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
	
	get_tree().current_scene.add_child(label)
	label.global_position = global_position
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 30, 0.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(label.queue_free)
