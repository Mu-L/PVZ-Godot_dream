extends Sprite2D
class_name WallnutBowlingStripe

var plant_cell_manager:PlantCellManager

func init_item(plant_cell_col_j:int=2, plant_cell_can_use:Dictionary = {}):
	## 等待一帧植物格子位置被容器节点修改完成后
	await get_tree().process_frame
	var main_game: MainGameManager = get_tree().current_scene
	plant_cell_manager = main_game.plant_cell_manager
	## 确定红线位置
	var target_plant_cell:PlantCell= Global.main_game.plant_cell_manager.all_plant_cells[0][plant_cell_col_j]
	global_position = target_plant_cell.global_position + Vector2(target_plant_cell.size.x - 11, 0)


	for plant_cells_row in Global.main_game.plant_cell_manager.all_plant_cells:
		## 左边不可以种植
		if not plant_cell_can_use["left_can_plant"]:
			for j in range(plant_cell_col_j + 1):
				var plant_cell:PlantCell = plant_cells_row[j]
				plant_cell.set_bowling_no_plant()
		## 右边不可以种植
		if not plant_cell_can_use["right_can_plant"]:
			for j in range(plant_cell_col_j + 1, plant_cells_row.size()):
				var plant_cell:PlantCell = plant_cells_row[j]
				plant_cell.set_bowling_no_plant()

		## 左边不可以僵尸
		if not plant_cell_can_use["left_can_zombie"]:
			for j in range(plant_cell_col_j + 1):
				var plant_cell:PlantCell = plant_cells_row[j]
				plant_cell.set_bowling_no_zombie()
		## 右边不可以僵尸
		if not plant_cell_can_use["right_can_zombie"]:
			for j in range(plant_cell_col_j + 1, plant_cells_row.size()):
				var plant_cell:PlantCell = plant_cells_row[j]
				plant_cell.set_bowling_no_zombie()

