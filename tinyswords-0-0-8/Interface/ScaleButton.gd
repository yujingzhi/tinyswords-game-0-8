extends TextureButton

# 定义缩放比例
const SCALE_DOWN = Vector2(0.9, 0.9)
const SCALE_UP = Vector2(1.1, 1.1)
const SCALE_NORMAL = Vector2(1.0, 1.0)

# 定义颜色
const MODULATE_NORMAL = Color(1, 1, 1, 1)
const MODULATE_PRESSED = Color(0.8, 0.8, 0.8, 1)

# 🔥 1. 获取子节点的音频播放器
# (确保你的节点名字就叫 AudioStreamPlayer，如果改了名这里也要改)
@onready var click_sound: AudioStreamPlayer = $AudioStreamPlayer

func _ready() -> void:
	pivot_offset = size / 2
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)

func _on_button_down() -> void:
	# --- 动画部分 (保持不变) ---
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", SCALE_DOWN, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", MODULATE_PRESSED, 0.1)
	
	# 🔥 2. 播放声音 (新增)
	# 加上 if 判断是为了防止没拖素材时报错
	if click_sound and click_sound.stream:
		# 每次按下前，强制重置音调 (稍微变化一点点，更自然)
		click_sound.pitch_scale = randf_range(0.95, 1.05)
		click_sound.play()

func _on_button_up() -> void:
	# --- 动画部分 (保持不变) ---
	var tween = create_tween()
	tween.set_parallel(false)
	tween.tween_property(self, "scale", SCALE_UP, 0.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", SCALE_NORMAL, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	create_tween().tween_property(self, "modulate", MODULATE_NORMAL, 0.1)
