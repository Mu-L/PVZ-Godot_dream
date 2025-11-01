extends Node
class_name LawnMoverManager

## 小推车类型
enum E_LawnMoverType{
	LawnMover,
	PoolCleaner,
	RoofCleaner,
}

## 小推车场景
const LawnMoverSecneMap = {
	E_LawnMoverType.LawnMover : preload("res://scenes/item/game_scenes_item/lawn_mover/lawn_mower.tscn"),
	E_LawnMoverType.PoolCleaner : preload("res://scenes/item/game_scenes_item/lawn_mover/pool_cleaner.tscn"),
	E_LawnMoverType.RoofCleaner : preload("res://scenes/item/game_scenes_item/lawn_mover/roof_cleaner.tscn")
}

## 所有场景中的小推车类型
const AllLawnMoverTypeFromGameScenes = {
	Global.MainScenes.MainGameFront:[0,0,0,0,0],
	Global.MainScenes.MainGameBack:[0,0,1,1,0,0],
	Global.MainScenes.MainGameRoof:[2,2,2,2,2]
}

@onready var lawn_movers: Node2D = %LawnMovers
## 小推车生成的全局x位置
@export var GlobalXLawnMover:float = 20
var all_lawn_movers_type:Array = []
var all_lawn_movers_global_pos:Array[Vector2] = []
var all_lawn_movers:Array[LawnMover] = []

## 是否有小推车
var is_lawn_mover := true
var game_scene:Global.MainScenes
## 初始化plant_cell_manager和zombie_manager两个管理器ready后在初始化该管理器
func init_lawn_mover_manager(game_para:ResourceLevelData) -> void:
	is_lawn_mover = game_para.is_lawn_mover
	game_scene = game_para.game_sences
	## 补充小推车
	EventBus.subscribe("replenish_lawn_mover", replenish_lawn_mover)
	if not is_lawn_mover:
		return
	create_all_lawn_movers()

## 生成所有的小推车
func create_all_lawn_movers():
	all_lawn_movers_type = AllLawnMoverTypeFromGameScenes[game_scene]

	print("创建小推车, 小推车类型", all_lawn_movers_type)
	assert(Global.main_game.zombie_manager.all_zombie_rows.size() == all_lawn_movers_type.size(), "小推车数量与僵尸行数量不一致")
	for lane in range(all_lawn_movers_type.size()):
		var zombie_row:ZombieRow = Global.main_game.zombie_manager.all_zombie_rows[lane]
		var global_pos_lawn_mover:Vector2 = Vector2(GlobalXLawnMover, zombie_row.zombie_create_position.global_position.y)
		all_lawn_movers_global_pos.append(global_pos_lawn_mover)
		var new_lawn_mover = create_lawn_mover(lane, all_lawn_movers_type[lane], all_lawn_movers_global_pos[lane])
		all_lawn_movers.append(new_lawn_mover)

## 补充小推车
func replenish_lawn_mover():
	if all_lawn_movers.is_empty():
		create_all_lawn_movers()
	else:
		for i in range(all_lawn_movers.size()):
			if is_instance_valid(all_lawn_movers[i]) and not all_lawn_movers[i].is_moving:
				continue
			else:
				var new_lawn_mover = create_lawn_mover(i, all_lawn_movers_type[i], all_lawn_movers_global_pos[i])
				all_lawn_movers[i] = new_lawn_mover

## 生成一个小推车
func create_lawn_mover(lane:int, lawn_mover_type:E_LawnMoverType, global_pos:Vector2)->LawnMover:
	var new_lawn_mover:LawnMover = LawnMoverSecneMap[lawn_mover_type].instantiate()
	new_lawn_mover.lane = lane
	new_lawn_mover.z_index = lane * 50 + 40
	new_lawn_mover.position = global_pos - lawn_movers.global_position
	lawn_movers.add_child(new_lawn_mover)
	lawn_mover_appear(new_lawn_mover)
	return new_lawn_mover

## 小推车出现动画
func lawn_mover_appear(lawn_mover:Node2D):
	var pos_x = lawn_mover.position.x
	lawn_mover.position.x -= 100
	var tween:Tween = create_tween()
	tween.tween_property(lawn_mover, "position:x", pos_x, 0.5)
