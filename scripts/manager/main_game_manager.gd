extends Node2D
class_name MainGameManager

## 游戏时测试方便修改阳光数
@export var test_change_sun_value := 9999:
	set(value):
		test_change_sun_value = value
		EventBus.push_event("test_change_sun_value", [value])

#region 游戏管理器
@onready var manager: Node = %Manager
@onready var card_manager: CardManager = %CardManager
@onready var hand_manager: HandManager = %HandManager
@onready var zombie_manager: ZombieManager = %ZombieManager
@onready var game_item_manager: GameItemManager = %GameItemManager
@onready var plant_cell_manager: PlantCellManager = %PlantCellManager
@onready var lawn_mover_manager: LawnMoverManager = %LawnMoverManager

#endregion

#region UI元素、相机
@onready var camera_2d: MainGameCamera = %Camera2D
@onready var ui_remind_word: UIRemindWord = %UIRemindWord
#endregion

#region 游戏主元素
@onready var background: MainGameBackGround = %Background

## 阳光收集位置
@onready var marker_2d_sun_target: Marker2D = %Marker2DSunTargetDefault

## 将子弹\爆炸\阳光
@onready var bullets: Node2D = %Bullets
@onready var bombs: Node2D = %Bombs
@onready var suns: Node2D = %Suns

@onready var coin_bank_label: CoinBankLabel = %CoinBankLabel
## 卡槽
@onready var card_slot_root: CardSlotRoot = %CardSlotRoot
## 僵尸进家panel
@onready var panel_zombie_go_home: Panel = %PanelZombieGoHome

## 全局检测组件,用于检测敌人
##TODO:可能会用于检测敌人离开场景后删除
@onready var detect_component_global: DetectComponentGlobal = %DetectComponentGlobal

#endregion

#region 锤子进入节点鼠标显示
## 鼠标是否一致显示,当有锤子时
var is_mouse_visibel_on_hammer:bool = false
@onready var node_mouse_appear_have_hammer:Array[Control] = [
	## 卡槽
	%CardSlotRoot,
	## 菜单
	%MainGameMenuButton, %MainGameMenuOptionDialog, %Dialog
]

#endregion

#region bgm
## 选卡bgm
@export var bgm_choose_card: AudioStream
## 主游戏bgm
var bgm_main_game: AudioStream
#endregion


#region 主游戏运行阶段
enum E_MainGameProgress{
	NONE,			## 无
	CHOOSE_CARD,	## 选卡界面
	PREPARE,		## 准备阶段(红字)
	MAIN_GAME,		## 游戏阶段
	GAME_OVER		## 游戏结束阶段
}

var main_game_progress := E_MainGameProgress.NONE
#endregion

#region 游戏数据
@export_group("地图特殊地形")
## 斜面(屋顶)
@export var main_game_slope:MainGameSlope
## 主游戏背景
var fog_node:Fog
## 雪人僵尸逃跑概率(默认不使用该概率,赌狗小游戏使用)
var p_yeti_run :float= -1
#endregion

#region 游戏参数
@export_group("本局游戏参数")
## 正常进入游戏会自动更新对应关卡数据,直接进入该场景会使用该关卡数据,并设置is_test=true
@export var game_para : ResourceLevelData
## 若为true,选卡无冷却
var is_test := false
#endregion



#endregion
func _ready() -> void:
	Global.main_game = self
	## 默认禁用全局敌人检测组件(追踪子弹调用, 放置追踪植物时启用,追踪植物死亡时,检测是否关闭)
	detect_component_global.disable_component(ComponentBase.E_IsEnableFactor.Global)
	## 订阅总线事件
	event_bus_subscribe()
	## 主游戏进程
	main_game_progress = E_MainGameProgress.CHOOSE_CARD
	## 播放选卡bgm
	SoundManager.play_bgm(bgm_choose_card)
	## 先获取当前关卡参数
	if Global.game_para != null:
		game_para = Global.game_para
	else:
		is_test = true
	game_para.init_para()

	## 连接子节点信号
	signal_connect()
	## 初始化子管理器
	init_manager()
	## 金币label初始化
	Global.coin_value_label = coin_bank_label
	coin_bank_label.visible = false
	## 初始化游戏背景
	_init_game_BG()

	## 如果有戴夫对话
	if game_para.crazy_dave_dialog:
		var crazy_dave:CrazyDave = SceneRegistry.CRAZY_DAVE.instantiate()
		crazy_dave.init_dave(game_para.crazy_dave_dialog)
		add_child(crazy_dave)
		await crazy_dave.signal_dave_leave_end
		crazy_dave.queue_free()

	## 如果看展示僵尸
	if game_para.look_show_zombie:
		## 创建展示僵尸，等待一秒移动相机
		zombie_manager.create_prepare_show_zombies()
		await get_tree().create_timer(1.0).timeout
		await camera_2d.move_look_zombie()
		## 如果可以选卡
		if game_para.can_choosed_card:
			card_manager.card_slot_appear_choose()
		else:
			await get_tree().create_timer(1.0).timeout
			no_choosed_card_start_game()
	else:
		main_game_start()

## 主游戏管理器事件总线订阅
func event_bus_subscribe():
	## 手持锤子时，修改鼠标离开ui是否显示鼠标
	EventBus.subscribe("change_is_mouse_visibel_on_hammer", change_is_mouse_visibel_on_hammer)
	## 僵尸进家
	EventBus.subscribe("zombie_go_home", on_zombie_go_home)
	## 正常选卡结束后开始游戏
	EventBus.subscribe("card_slot_norm_start_game", choosed_card_start_game)


#region 游戏关卡初始化
## 初始化管理器
func init_manager():
	card_manager.init_card_manager(game_para)
	plant_cell_manager.init_plant_cell_manager(game_para)
	game_item_manager.init_game_item_manager(game_para)
	hand_manager.init_hand_manager(game_para)
	zombie_manager.init_zombie_manager(game_para)
	lawn_mover_manager.init_lawn_mover_manager(game_para)

## 子节点之间信号连接
func signal_connect():
	## 植物种植区域信号
	for plant_cells_row in plant_cell_manager.all_plant_cells:
		for plant_cell in plant_cells_row:
			plant_cell = plant_cell as PlantCell
			plant_cell.click_cell.connect(hand_manager._on_click_cell)
			plant_cell.cell_mouse_enter.connect(hand_manager._on_cell_mouse_enter)
			plant_cell.cell_mouse_exit.connect(hand_manager._on_cell_mouse_exit)
	if game_para.is_hammer:
		for ui_node:Control in node_mouse_appear_have_hammer:
			ui_node.mouse_entered.connect(mouse_appear_have_hammer)
			ui_node.mouse_exited.connect(mouse_disappear_have_hammer)

## 初始化游戏背景,bgm
func _init_game_BG():
	print(game_para.game_BGM)
	var path_bgm_game = game_para.GameBGMMap[game_para.game_BGM]
	bgm_main_game = load(path_bgm_game) as AudioStream

	background.init_background(game_para)

## 不用选择卡片进行的流程
func no_choosed_card_start_game():
	await get_tree().create_timer(2.0).timeout
	## 相机移动回游戏场景
	await camera_2d.move_back_ori()
	main_game_start()
#endregion

## 选择卡片完成
func choosed_card_start_game():
	## 隐藏待选卡槽
	await card_manager.card_slot_disappear_choose()
	## 相机移动回游戏场景
	await camera_2d.move_back_ori()
	main_game_start()

## 选卡结束，开始游戏
func main_game_start():
	## 主游戏进程阶段
	main_game_progress = E_MainGameProgress.PREPARE
	if game_para.is_fog:
		fog_node.come_back_game(5.0)

	## 删除展示僵尸
	if game_para.look_show_zombie:
		zombie_manager.delete_prepare_show_zombies()

	## 开始天降阳光
	if game_para.is_day_sun:
		var day_suns_manager = SceneRegistry.DAY_SUNS_MANAGER.instantiate()
		manager.add_child(day_suns_manager)
		day_suns_manager.start_day_sun()

	print("生成墓碑", game_para.init_tombstone_num)
	## 生成墓碑
	if game_para.init_tombstone_num > 0:
		plant_cell_manager.create_tombstone(game_para.init_tombstone_num)

	## 等待1秒红字出现
	await get_tree().create_timer(1.0).timeout
	await ui_remind_word.ready_set_plant()

	## 卡槽出现,若已出现,不会重复出现,更新卡槽卡片和铲子
	if game_para.have_card_bar:
		card_manager.card_slot_update_main_game()
	## 主游戏进程阶段
	main_game_progress = E_MainGameProgress.MAIN_GAME

	## 红字结束后一秒修改bgm
	await get_tree().create_timer(1.0).timeout
	SoundManager.play_bgm(bgm_main_game)

	zombie_manager.start_game()


#region 游戏结束
## 修改僵尸位置
func change_zombie_position(zombie:Zombie000Base):
	## 要删除碰撞器，不然会闪退
	zombie.be_attacked_box_component.free()
	zombie.get_parent().remove_child(zombie)
	panel_zombie_go_home.add_child(zombie)
	zombie.position = Vector2(75, 360)

## 僵尸进房
func on_zombie_go_home(zombie:Zombie000Base):

	main_game_progress = E_MainGameProgress.GAME_OVER
	card_slot_root.visible = false
	# 游戏暂停
	get_tree().paused = true
	call_deferred("change_zombie_position", zombie)
	## 如果有锤子
	if game_item_manager.all_game_items.has(GameItemManager.E_GameItemType.Hammer):
		game_item_manager.all_game_items[GameItemManager.E_GameItemType.Hammer].set_is_used(false)
	await get_tree().create_timer(1).timeout

	## 设置相机可以移动
	camera_2d.process_mode = Node.PROCESS_MODE_ALWAYS
	camera_2d.move_to(Vector2(-200, 0), 2)
	SoundManager.play_other_SFX("losemusic")
	await get_tree().create_timer(3).timeout
	SoundManager.play_other_SFX("scream")
	ui_remind_word.zombie_won_word_appear()

#endregion


#region 锤子鼠标交互
## 锤子鼠标进入后，显示鼠标
func mouse_appear_have_hammer():
	## 如果有锤子
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

## 有锤子时连接该信号
func mouse_disappear_have_hammer():
	## 如果有锤子不显示鼠标（非重新开始、离开游戏）
	if not is_mouse_visibel_on_hammer:
		## 如果有锤子
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

## 点击重新开始或主菜单时，修改值，可以一直显示鼠标
func change_is_mouse_visibel_on_hammer(value:bool):
	if game_para.is_hammer:
		is_mouse_visibel_on_hammer = value

#endregion

