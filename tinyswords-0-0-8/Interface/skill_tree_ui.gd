extends Control

@onready var close_button: TextureButton = $Overlay/Paper/CloseButton
@onready var sp_label: Label = $Overlay/Paper/SPLabel
@onready var tooltip_panel: PanelContainer = $Overlay/Paper/Tooltip
@onready var tooltip_name: Label = $Overlay/Paper/Tooltip/VBox/Name
@onready var tooltip_cost: Label = $Overlay/Paper/Tooltip/VBox/Cost
@onready var tooltip_desc: Label = $Overlay/Paper/Tooltip/VBox/Desc

@onready var tab_hero: Button = $Overlay/Paper/Content/Left/Tabs/TabHero
@onready var tab_sheep: Button = $Overlay/Paper/Content/Left/Tabs/TabSheep
@onready var tab_base: Button = $Overlay/Paper/Content/Left/Tabs/TabBase
@onready var tab_gene: Button = $Overlay/Paper/Content/Left/Tabs/TabGene

@onready var skill_button_example: TextureButton = $Overlay/Paper/Content/Right/Scroll/TreeCanvas/SkillNode_Example/Button

var _prev_paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_button.pressed.connect(close_ui)
	tab_hero.pressed.connect(func(): _on_category_selected("1. 主角专精"))
	tab_sheep.pressed.connect(func(): _on_category_selected("2. 羊群物流"))
	tab_base.pressed.connect(func(): _on_category_selected("3. 基建能量"))
	tab_gene.pressed.connect(func(): _on_category_selected("4. 基因变异"))
	skill_button_example.mouse_entered.connect(func(): _show_tooltip(skill_button_example, "示例技能", 1, "这里是技能描述占位。"))
	skill_button_example.mouse_exited.connect(_hide_tooltip)
	_hide_tooltip()

func toggle() -> void:
	if visible:
		close_ui()
	else:
		open_ui()

func open_ui() -> void:
	if visible:
		return
	_prev_paused = get_tree().paused
	get_tree().paused = true
	visible = true

func close_ui() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _prev_paused
	_hide_tooltip()

func set_skill_points(value: int) -> void:
	sp_label.text = "可用 SP: " + str(max(0, value))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_skill_tree") and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()

func _on_category_selected(category: String) -> void:
	print(category)

func _show_tooltip(for_button: Control, name_text: String, sp_cost: int, desc_text: String) -> void:
	tooltip_name.text = name_text
	tooltip_cost.text = "消耗 SP: " + str(max(0, sp_cost))
	tooltip_desc.text = desc_text
	tooltip_panel.visible = true
	var rect = for_button.get_global_rect()
	var local_pos = tooltip_panel.get_parent().to_local(rect.position + Vector2(rect.size.x + 10.0, 0.0))
	tooltip_panel.position = local_pos

func _hide_tooltip() -> void:
	tooltip_panel.visible = false
