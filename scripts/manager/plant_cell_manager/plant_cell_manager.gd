extends Node
class_name PlantCellManager

@onready var plant_cells_root: Node2D = %PlantCellsRoot
@onready var tomb_stone_manager: TombStoneManager = $TombStoneManager

## PlantCellManager初始化
## 二维数组，保存每个植物格子节点
var all_plant_cells: Array[Array] = []
## 植物格子的行和列
var row_col:Vector2i = Vector2i.ZERO
## TombStoneManager(PlantCellManager子节点)初始化
## 生成的墓碑列表(一维)
var tombstone_list :Array[TombStone] = []

## 当前植物种植的信息[植物种类:植物数量]
var curr_plant_num:Dictionary[Global.PlantType, int]


func _ready() -> void:
	## 火爆辣椒爆炸特效
	EventBus.subscribe("jalapeno_bomb_effect", jalapeno_bomb_effect)
	## 火爆辣椒销毁道具[冰道和梯子]
	EventBus.subscribe("jalapeno_bomb_item_lane", jalapeno_bomb_item_lane)
	# 植物种植区域信号，更新植物位置列号,更新墓碑信息
	for plant_cells_row_i in plant_cells_root.get_child_count():
		## 某一行all_plant_cells
		var plant_cells_row:CanvasItem = plant_cells_root.get_child(plant_cells_row_i)
		plant_cells_row.z_index = plant_cells_row_i * 50 + 10
		var plant_cells_row_node := []
		## plant_cell是从右向左的顺序，这里从左到右
		for plant_cells_col_j in range(plant_cells_row.get_child_count() - 1, -1, -1):
			var plant_cell:PlantCell = plant_cells_row.get_child(plant_cells_col_j)
			plant_cell.row_col = Vector2(plant_cells_row_i, plant_cells_col_j)
			plant_cells_row_node.append(plant_cell)
			plant_cell.signal_plant_create.connect(update_plant_info_create)
			plant_cell.signal_plant_free.connect(update_plant_info_free)

		all_plant_cells.append(plant_cells_row_node)

	row_col = Vector2i(all_plant_cells.size(), all_plant_cells[0].size())

## 更新植物信息(创建新植物)
func update_plant_info_create(plant_cell:PlantCell, plant_type:Global.PlantType):
	curr_plant_num[plant_type] = curr_plant_num.get(plant_type, 0) + 1
	EventBus.push_event("update_card_purple_sun_cost")

## 更新植物信息(植物死亡)
func update_plant_info_free(plant_cell:PlantCell, plant_type:Global.PlantType):
	curr_plant_num[plant_type] -= 1
	EventBus.push_event("update_card_purple_sun_cost")
	if curr_plant_num[plant_type] < 0:
		printerr(plant_type, ":该植物类型数量小于0")


func init_plant_cell_manager(game_para:ResourceLevelData):
	tomb_stone_manager.init_tomb_stone_manager(game_para)
	## 预种植植物数据
	var all_pre_plant_data = game_para.all_pre_plant_data
	for pre_plant_data in all_pre_plant_data:
		if pre_plant_data == null:
			printerr("关卡数据中预种植植物有空值")
			continue
		## 行或列大于当前最大值\小于0,跳过
		if pre_plant_data.plant_cell_pos.x > row_col.x or\
		pre_plant_data.plant_cell_pos.y > row_col.y or\
		pre_plant_data.plant_cell_pos.x < 0 or pre_plant_data.plant_cell_pos.y < 0:
			continue
		## 满屏铺满
		elif pre_plant_data.plant_cell_pos.x == 0 and pre_plant_data.plant_cell_pos.y == 0:
			for plant_cell_row in all_plant_cells:
				for plant_cell:PlantCell in plant_cell_row:
					plant_cell.create_plant(pre_plant_data.plant_type)
		## 某一列
		elif pre_plant_data.plant_cell_pos.x == 0 and pre_plant_data.plant_cell_pos.y != 0:
			for plant_cell_row in all_plant_cells:
				var plant_cell:PlantCell = plant_cell_row[pre_plant_data.plant_cell_pos.y-1]
				plant_cell.create_plant(pre_plant_data.plant_type)
		## 某一行
		elif pre_plant_data.plant_cell_pos.x != 0 and pre_plant_data.plant_cell_pos.y == 0:
			var plant_cell_row = all_plant_cells[pre_plant_data.plant_cell_pos.x-1]
			for plant_cell:PlantCell in plant_cell_row:
				plant_cell.create_plant(pre_plant_data.plant_type)
		## 某一个
		else:
			var plant_cell:PlantCell = all_plant_cells[pre_plant_data.plant_cell_pos.x-1][pre_plant_data.plant_cell_pos.y-1]
			plant_cell.create_plant(pre_plant_data.plant_type)

func create_tombstone(new_num:int):
	tomb_stone_manager.create_tombstone(new_num)

## 火爆辣椒爆炸特效
## [lane:int]:行
func jalapeno_bomb_effect(lane:int):
	for plant_cell:PlantCell in all_plant_cells[lane]:
		var fire_new:BombEffectFire = SceneRegistry.FIRE.instantiate()
		## 修改其图层
		fire_new.z_index = 400 + (lane + 1) * 10 + 5
		fire_new.z_as_relative = false

		plant_cell.add_child(fire_new)
		fire_new.global_position = plant_cell.global_position + Vector2(plant_cell.size.x / 2, plant_cell.size.y)
		fire_new.activate_bomb_effect()

func jalapeno_bomb_item_lane(lane:int):
	## 梯子
	for p_c :PlantCell in all_plant_cells[lane]:
		if is_instance_valid(p_c.ladder):
			p_c.ladder.queue_free()


## 获取有植物的植物格子
func get_cell_have_plant()->Array[PlantCell]:
	var all_cell_have_plant:Array[PlantCell]
	for plant_cell_lane in Global.main_game.plant_cell_manager.all_plant_cells:
		for plant_cell:PlantCell in plant_cell_lane:
			if plant_cell.get_curr_plant_num()>0:
				all_cell_have_plant.append(plant_cell)
	return all_cell_have_plant

