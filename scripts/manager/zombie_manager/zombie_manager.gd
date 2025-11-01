extends Node
class_name ZombieManager

## 最后一波僵尸每秒检测是否有僵尸离开当前视野
@onready var check_zombie_end_wave_timer: Timer = $CheckZombieEndWaveTimer

## 管理器
@onready var zombie_wave_manager: ZombieWaveManager = $ZombieWaveManager
@onready var zombie_show_in_start: ZombieShowInStart = $ZombieShowInStart
@onready var hammer_zombie_manager: HammerZombieManager = $HammerZombieManager
## 僵尸数量label
@onready var label_zombie_sum: Label = %LabelZombieSum
## 所有僵尸根节点
@onready var zombies_root: Node2D = %ZombiesRoot

var curr_zombie_num:int = 0:
	set(v):
		curr_zombie_num=v
		label_zombie_sum.text = "当前僵尸数量：" + str(curr_zombie_num)
		signal_curr_zombie_num_change.emit(v)

## 是否为最后一波,最后一波时，僵尸数量为0后结束游戏
var is_end_wave := false
## 被魅惑僵尸列表
var all_zombies_be_hypno:Array[Zombie000Base] = []
## 僵尸可以存在的x坐标范围,超出该范围,每波刷新时删除,最后一波时每秒删除检查删除
var zombie_range_pos_x:=Vector2(-300, 900)
## 出怪模式
var monster_mode:ResourceLevelData.E_MonsterMode
## 所有僵尸列表,用于每波清除在地图外的僵尸(矿工,魅惑等僵尸)
var all_zombies_1d:Array[Zombie000Base]

## 所有僵尸行
var all_zombie_rows:Array[ZombieRow] = []
## 冰道,按行保存每行的冰道
var all_ice_roads:Array[Array] = []
## 按行保存僵尸，用于保存僵尸列表的列表
var all_zombies_2d:Array[Array]

signal signal_curr_zombie_num_change(num:int)

func _ready():
	## 注册事件总线
	EventBus.subscribe("ice_all_zombie", ice_all_zombie)
	## 火爆辣椒销毁道具[冰道和梯子]
	EventBus.subscribe("jalapeno_bomb_item_lane", jalapeno_bomb_item_lane)
	EventBus.subscribe("jalapeno_bomb_lane_zombie", jalapeno_bomb_lane_zombie)
	EventBus.subscribe("blover_blow_away_in_sky_zombie", blover_blow_away_in_sky_zombie)
	## 非刷怪模式最后一波僵尸
	EventBus.subscribe("end_wave_zombie", func():is_end_wave=true)

	## 初始化僵尸和行列表
	for zombie_row_i in zombies_root.get_child_count():
		var zombie_row :CanvasItem= zombies_root.get_child(zombie_row_i)
		zombie_row.z_index = zombie_row_i * 50 + 30

		all_zombie_rows.append(zombie_row)
		var row_ice_roads:Array[IceRoad] = []
		all_ice_roads.append(row_ice_roads)

		var row_zombies:Array[Zombie000Base] = []
		all_zombies_2d.append(row_zombies)

## 初始僵尸管理器
func init_zombie_manager(game_para:ResourceLevelData):
	zombie_show_in_start.init_zombie_show_in_start(game_para)
	self.monster_mode = game_para.monster_mode
	match self.monster_mode:
		## 没有僵尸刷新,直接启动最后一波僵尸检查计时器
		ResourceLevelData.E_MonsterMode.Null:
			check_zombie_end_wave_timer.start()

		ResourceLevelData.E_MonsterMode.Norm:
			zombie_wave_manager.init_zombie_wave_manager(game_para)
			## 波次刷新时判断是否为最后一波，删除多余魅惑僵尸
			zombie_wave_manager.signal_wave_refresh.connect(wave_refresh)
			## 僵尸数量改变时，剩余僵尸为0触发提前刷新
			signal_curr_zombie_num_change.connect(zombie_wave_manager.zombie_wave_refresh_manager.judge_total_refresh)

		ResourceLevelData.E_MonsterMode.HammerZombie:
			hammer_zombie_manager.init_hammer_zombie_manager(game_para)
			## 波次刷新时判断是否为最后一波，删除多余魅惑僵尸
			hammer_zombie_manager.signal_wave_refresh.connect(wave_refresh)


## 开始第一波
func start_game():
	match self.monster_mode:
		ResourceLevelData.E_MonsterMode.Null:
			return

		ResourceLevelData.E_MonsterMode.Norm:
			## 10秒后开始刷新僵尸
			await get_tree().create_timer(10).timeout
			zombie_wave_manager.start_first_wave()

		ResourceLevelData.E_MonsterMode.HammerZombie:
			await get_tree().create_timer(2).timeout
			hammer_zombie_manager.start_first_wave()

#region 生成僵尸
## 生成一个正常出战僵尸，所有出战僵尸都要从这里生成
func create_norm_zombie(
	zombie_type:Global.ZombieType,	## 僵尸类型
	zombie_parent:Node,				## 僵尸父节点
	zombie_init_type:Character000Base.E_CharacterInitType,	## 僵尸初始化类型（战斗、展示）
	lane:int = -1, 			## 僵尸行
	curr_wave:int = -1,		## 僵尸波次
	pos:Vector2=Vector2.ZERO,
	init_zombie_special:Callable = Callable()		## 初始化僵尸特殊属性
) -> Zombie000Base:
	var zombie:Zombie000Base = Global.get_zombie_info(zombie_type, Global.ZombieInfoAttribute.ZombieScenes).instantiate()
	zombie.init_zombie(
		zombie_init_type,
		Global.main_game.zombie_manager.all_zombie_rows[lane].zombie_row_type,
		lane,
		curr_wave,
		pos,
	)
	if not init_zombie_special.is_null():
		init_zombie_special.call(zombie)

	zombie_parent.add_child(zombie)
	## 只要创建僵尸，都要连接这两个信号
	zombie.signal_character_death.connect(_on_zombie_dead.bind(zombie))
	zombie.signal_character_be_hypno.connect(_on_zombie_hypno.bind(zombie))
	zombie.signal_lane_update.connect(zombie_update_lane.bind(zombie, zombie.lane))

	all_zombies_2d[lane].append(zombie)
	all_zombies_1d.append(zombie)

	curr_zombie_num += 1

	return zombie

#endregion

#region 僵尸死亡、魅惑信号

## 僵尸被魅惑发射信号
func _on_zombie_hypno(zombie:Zombie000Base):
	## 出战僵尸保存列表删除该僵尸
	curr_zombie_num -= 1
	all_zombies_2d[zombie.lane].erase(zombie)
	## 掉血信号
	zombie.signal_zombie_hp_loss.emit(zombie.hp_component.get_all_hp(), zombie.curr_wave)
	var conns = zombie.signal_zombie_hp_loss.get_connections()
	for conn in conns:
		zombie.signal_zombie_hp_loss.disconnect(conn.callable)
	all_zombies_be_hypno.append(zombie)


## 僵尸发射死亡信号后调用函数
func _on_zombie_dead(zombie: Zombie000Base) -> void:
	all_zombies_1d.erase(zombie)
	if zombie.is_hypno:
		all_zombies_be_hypno.erase(zombie)
	else:
		curr_zombie_num -= 1
		all_zombies_2d[zombie.lane].erase(zombie)

		## 如果到了最后一波刷新,且僵尸全部死亡
		if is_end_wave and curr_zombie_num == 0:
			print("=======================游戏结束，您获胜了=======================")
			var trophy = SceneRegistry.TROPHY.instantiate()
			get_tree().current_scene.add_child(trophy)
			trophy.global_position = zombie.global_position
			if trophy.global_position.x >= 750:
				var x_diff = trophy.global_position.x - 750
				throw_to(trophy, trophy.position - Vector2(x_diff + randf_range(0,50), 0))
			else:
				throw_to(trophy, trophy.position - Vector2(randf_range(-50,50), 0))

## 奖杯抛出
func throw_to(node:Node2D, target_pos: Vector2, duration: float = 1.0):
	var start_pos = node.position
	var peak_pos = start_pos.lerp(target_pos, 0.5)
	peak_pos.y -= 50  # 向上抛

	var tween = create_tween()
	tween.tween_property(node, "position:x", target_pos.x, duration).set_trans(Tween.TRANS_LINEAR)

	tween.parallel().tween_property(node, "position:y", peak_pos.y, duration / 2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(node, "position:y", target_pos.y, duration / 2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(duration / 2)

func wave_refresh(is_end_wave:bool):
	self.is_end_wave = is_end_wave
	set_zombie_death_over_view()
	if is_end_wave:
		check_zombie_end_wave_timer.start()
		print("最后一波僵尸检测是否有离开当前视野的僵尸")

### 删除移动超出视野的僵尸,每次刷新僵尸调用
func set_zombie_death_over_view():
	for z:Zombie000Base in all_zombies_1d:
		# 检查是否在屏幕外
		if z.global_position.x > zombie_range_pos_x.y or z.global_position.x < zombie_range_pos_x.x:
			#all_zombies_be_hypno.erase(z)
			z.character_death_disappear()
	#print("删除离开当前视野的僵尸，目前还剩的僵尸：", all_zombies_1d)
#endregion

#region 生成关卡前展示僵尸
func create_prepare_show_zombies():
	zombie_show_in_start.create_prepare_show_zombies()

func delete_prepare_show_zombies():
	zombie_show_in_start.delete_prepare_show_zombies()
#endregion

#region 植物调用相关，寒冰菇\火爆辣椒\三叶草
## 冰冻所有僵尸
func ice_all_zombie(time_ice:float, time_decelerate: float):
	for zombie_row:Array in all_zombies_2d:
		if zombie_row.is_empty():
			continue
		for zombie:Zombie000Base in zombie_row:
			zombie.be_ice_freeze(time_ice, time_decelerate)
			if is_instance_valid(zombie.ice_effect):
				zombie.ice_effect.queue_free()
			## 冰冻效果
			var ice_effect = SceneRegistry.ICE_EFFECT.instantiate()
			zombie.add_child(ice_effect)
			zombie.ice_effect = ice_effect
			ice_effect.start_ice_effect(time_ice)


func jalapeno_bomb_item_lane(lane:int):
	## 冰道
	for i in range(all_ice_roads[lane].size()-1, -1, -1):
		var ice_road:IceRoad = all_ice_roads[lane][i]
		ice_road.ice_road_disappear()

## 火爆辣椒爆炸整行僵尸
func jalapeno_bomb_lane_zombie(lane:int):
	print(all_zombies_2d[lane])
	for i in range(all_zombies_2d[lane].size()-1,-1,-1) :
		if is_instance_valid(all_zombies_2d[lane][i]):
			var zombie:Zombie000Base = all_zombies_2d[lane][i]
			zombie.be_bomb(1800, true)

## 三叶草吹走空中僵尸
func blover_blow_away_in_sky_zombie():
	for zombie_row:Array in all_zombies_2d:
		if zombie_row.is_empty():
			continue
		for i in range(zombie_row.size()-1, -1, -1):
			var zombie:Zombie000Base = zombie_row[i]
			if zombie.curr_be_attack_status == Zombie000Base.E_BeAttackStatusZombie.IsSky:
				zombie.be_blow_away()

#endregion

## 最后一波时每秒检查是否有僵尸离开当前视野
func _on_check_zombie_end_wave_timer_timeout() -> void:
	set_zombie_death_over_view()

## 僵尸换行,更新数据
func zombie_update_lane(zombie:Zombie000Base, ori_lane:int):
	if all_zombies_2d[ori_lane].has(zombie):
		all_zombies_2d[ori_lane].erase(zombie)
		all_zombies_2d[zombie.lane].append(zombie)
		zombie.signal_lane_update.disconnect(zombie_update_lane.bind(zombie, ori_lane))
		zombie.signal_lane_update.connect(zombie_update_lane.bind(zombie, zombie.lane))
		#print("僵尸换行")

