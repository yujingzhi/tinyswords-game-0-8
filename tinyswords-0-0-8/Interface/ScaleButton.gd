extends TextureButton
# 带缩放与音效反馈的按钮组件

# 定义缩放比例
const SCALE_DOWN = Vector2(0.9, 0.9)
const SCALE_UP = Vector2(1.1, 1.1)
const SCALE_NORMAL = Vector2(1.0, 1.0)
# 三种缩放分别对应按下、弹起与正常状态

# 定义颜色
const MODULATE_NORMAL = Color(1, 1, 1, 1)
const MODULATE_PRESSED = Color(0.8, 0.8, 0.8, 1)
# 按下时颜色稍微变暗

# 🔥 1. 获取子节点的音频播放器
# (确保你的节点名字就叫 AudioStreamPlayer，如果改了名这里也要改)
@onready var click_sound: AudioStreamPlayer = get_node_or_null("AudioStreamPlayer")
# 如果节点不存在将返回 null，避免报错

func _ready() -> void:
	# 以中心为缩放点，并监听按钮按下/抬起
	pivot_offset = size / 2
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)

func _on_button_down() -> void:
	# 按下时缩小并变暗
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", SCALE_DOWN, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", MODULATE_PRESSED, 0.1)
	
	# 播放点击音效
	if click_sound and click_sound.stream:
		# 轻微随机音调让声音更自然
		click_sound.pitch_scale = randf_range(0.95, 1.05)
		click_sound.play()

func _on_button_up() -> void:
	# 抬起时先稍微放大再回到正常大小
	var tween = create_tween()
	tween.set_parallel(false)
	tween.tween_property(self, "scale", SCALE_UP, 0.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", SCALE_NORMAL, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	create_tween().tween_property(self, "modulate", MODULATE_NORMAL, 0.1)
