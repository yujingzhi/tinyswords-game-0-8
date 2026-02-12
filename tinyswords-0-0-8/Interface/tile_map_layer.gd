@tool
extends TileMapLayer

@export_category("背景尺寸设置")
@export var grid_width: int = 3:
	set(value):
		grid_width = value
		if grid_width < 2: grid_width = 2
		_draw_panel()

@export var grid_height: int = 3:
	set(value):
		grid_height = value
		if grid_height < 2: grid_height = 2
		_draw_panel()

# --- 请根据你的 TileSet 面板悬停显示的实际坐标修改这里 ---
const SOURCE_ID = 0
const CELL_TL = Vector2i(0, 0)
const CELL_T  = Vector2i(12, 0)
const CELL_TR = Vector2i(20, 0)
const CELL_L  = Vector2i(0, 12)
const CELL_C  = Vector2i(12, 12)
const CELL_R  = Vector2i(20, 12)
const CELL_BL = Vector2i(0, 20)
const CELL_B  = Vector2i(12, 20)
const CELL_BR = Vector2i(20, 20)

func _ready():
	_draw_panel()

func _draw_panel():
	print("正在绘制面板... 宽:", grid_width, " 高:", grid_height) # 看输出面板有没有这就话
	clear()
	
	for x in range(grid_width):
		for y in range(grid_height):
			var final_coord = CELL_C
			
			if x == 0:
				if y == 0: final_coord = CELL_TL
				elif y == grid_height - 1: final_coord = CELL_BL
				else: final_coord = CELL_L
			elif x == grid_width - 1:
				if y == 0: final_coord = CELL_TR
				elif y == grid_height - 1: final_coord = CELL_BR
				else: final_coord = CELL_R
			else:
				if y == 0: final_coord = CELL_T
				elif y == grid_height - 1: final_coord = CELL_B
			
			set_cell(Vector2i(x, y), SOURCE_ID, final_coord)
