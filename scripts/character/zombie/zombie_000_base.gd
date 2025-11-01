extends Character000Base
class_name Zombie000Base

@onready var attack_component: AttackComponentBase = %AttackComponent
@onready var hp_stage_change_component: HpStageChangeComponent = %HpStageChangeComponent
@onready var charred_component: CharredComponent = %CharredComponent
@onready var move_component: MoveComponent = %MoveComponent
@onready var swim_box_component: SwimBoxComponent = %SwimBoxComponent
@onready var drop_item_component: DropItemComponent = %DropItemComponent

#region 僵尸类基础属性
@export var zombie_type:Global.ZombieType
## 僵尸基础属性参数，_ready初始化
@export_group("僵尸基础属性")
## 是否忽略梯子,即可以攻击梯子下的植物
@export var is_ignore_ladder:=false

@export_subgroup("僵尸铁器")
## 僵尸铁器类型
@export var iron_type:Global.IronType = Global.IronType.Null
## 僵尸铁器节点
@export var iron_node:IronNodeBase
@export_subgroup("僵尸初始化状态")
## 僵尸初始化状态（从1[is_norm] 开始，被攻击时是否能被攻击到的属性）
@export var init_be_attack_status :E_BeAttackStatusZombie = 1
## 僵尸出生波次
var curr_wave:=-1
## 僵尸当前状态
var curr_be_attack_status:E_BeAttackStatusZombie:
	set(value):
		curr_be_attack_status = value
		signal_status_update.emit()

## 当前僵尸所在行，陆地、水池
var curr_zombie_row_type:Global.ZombieRowType=Global.ZombieRowType.Land
## 水路两栖僵尸当前行为水路时body变化
@export var body_change_on_pool:ResourceBodyChange

## 是否可以触发倭瓜位置判定，默认都为否，可以跳跃的僵尸跳跃组件跳跃后修改为否
@export var is_trigger_squash_pos_judge := false
## 是否可以高建国强行停止跳跃判定，默认都为否，可以跳跃的僵尸跳跃组件跳跃后修改为否
@export var is_trigger_tall_nut_stop_jump := false

## 状态更新信号
signal signal_status_update
## 行更新信号
signal signal_lane_update
#func _update_lane(new_lane):
	#lane = new_lane
	#signal_lane_update.emit()

## 僵尸掉血信号（只有僵尸使用）,参数为损失的血量值
signal signal_zombie_hp_loss(all_loss_hp:int, wave:int)

#endregion

#region 角色枚举
## 检测攻击时，根据状态判断是否可以攻击
enum E_BeAttackStatusZombie{
	IsNorm = 1,		## 正常
	IsJump = 2,		## 跳跃
	IsDownPool = 4,		## 水下
	IsSky = 8,			## 空中
	IsDownGround = 16,	## 地下
	IsJumpInPool = 32,	## 跳入泳池,该状态无法被高建国拦截
}

#endregion

#region 僵尸动画状态参数
@export_group("动画状态")
## 默认为移动状态,is_walk由多种状态控制
@export var is_walk := true
@export var is_attack := false:
	set(value):
		is_attack = value
		_judge_is_walk()
@export var is_swimming := false
##是否为珊瑚僵尸
var is_seaweed:=false
## 父类通用
#var is_death := false

## 被炸死
var is_bomb_death := false:
	set(value):
		is_bomb_death = value
		_judge_is_walk()

## is_walk由is_attack 和 is_bomb_death控制
func _judge_is_walk():
	is_walk = not is_attack and not is_bomb_death

#endregion

@export_group("入场音效")
@export var sfx_enter_name:StringName
## 入场音效
var sfx_enter:AudioStreamPlayer
var is_sfxing:=false
## 停止入场音效(死亡\失去小丑盒子)
func _stop_sfx_enter():
	if is_sfxing:
		sfx_enter.stop()

@export_group("其他")
@export_subgroup("黄油")
## 头的节点路径,黄油糊脸使用
@export_node_path("Sprite2D") var head1_path:NodePath = "Body/BodyCorrect/Anim_head1"
## 头的节点
@onready var head_node:Node2D = get_node(head1_path)
## 黄油节点,
var butter_splat:Node2D
## 修改初始化状态，在添加到场景树之前调用
func init_zombie(
	character_init_type:E_CharacterInitType, 	## 角色初始化类型（正常、展示）
	curr_zombie_row_type:Global.ZombieRowType,	## 僵尸所在行属性（水、陆地）
	lane:int = -1, 	## 僵尸行
	curr_wave:int = -1,		## 僵尸波次
	curr_pos:Vector2 = Vector2.ZERO,	## 僵尸局部位置
):
	self.character_init_type = character_init_type
	self.curr_zombie_row_type = curr_zombie_row_type
	self.lane = lane
	self.curr_wave = curr_wave
	self.position = curr_pos

	## 两栖类僵尸在水路时变化
	if Global.get_zombie_info(zombie_type, Global.ZombieInfoAttribute.ZombieRowType) == Global.ZombieRowType.Both:
		if body_change_on_pool != null:
			## 水路时body变化
			if curr_zombie_row_type == Global.ZombieRowType.Pool:
				for sprite_path in body_change_on_pool.sprite_appear:
					var sprite = get_node(sprite_path)
					sprite.visible = true

				for sprite_path in body_change_on_pool.sprite_disappear:
					var sprite = get_node(sprite_path)
					sprite.visible = false
			else:

				for sprite_path in body_change_on_pool.sprite_appear:
					var sprite = get_node(sprite_path)
					sprite.visible = false

				for sprite_path in body_change_on_pool.sprite_disappear:
					var sprite = get_node(sprite_path)
					sprite.visible = true

## 初始化正常出战角色
func init_norm():
	super()
	curr_be_attack_status = init_be_attack_status
	## 若生成位置在斜面中,生成时修正斜面位置
	if is_instance_valid(Global.main_game.main_game_slope):
		## 获取对应位置的斜面y相对位置
		var slope_y_first = Global.main_game.main_game_slope.get_all_slope_y(global_position.x)
		move_y_body(slope_y_first)
	## 僵尸普通攻击组件连接信号
	if attack_component is AttackComponentZombieNorm:
		## 攻击组件是否攻击梯子下僵尸
		attack_component.init_attack_component(is_ignore_ladder)

## 初始化正常出战角色信号连接
func init_norm_signal_connect():
	super()
	## 入场音效相关
	if not sfx_enter_name.is_empty():
		## 入场音效
		sfx_enter = SoundManager.play_zombie_SFX(zombie_type, sfx_enter_name)
		## 同一帧多次播放同一音效时不播放新音效
		if sfx_enter:
			is_sfxing = true
			sfx_enter.finished.connect(func():is_sfxing = false)
			hp_component.signal_hp_component_death.connect(_stop_sfx_enter)

	hp_component.signal_zombie_hp_loss.connect(func(hp_loss:int): signal_zombie_hp_loss.emit(hp_loss, curr_wave))
	## 角色死亡时禁用攻击组件
	hp_component.signal_hp_component_death.connect(attack_component.disable_component.bind(ComponentBase.E_IsEnableFactor.Death))
	## 攻击组件
	attack_component.signal_change_is_attack.connect(move_component.update_move_factor.bind(move_component.E_MoveFactor.IsAttack))
	attack_component.signal_change_is_attack.connect(change_is_attack)
	## 攻击时受击组件
	attack_component.signal_change_is_attack.connect(be_attacked_box_component.change_area_attack_appear)

	## 死亡时取消黄油
	hp_component.signal_hp_component_death.connect(death_stop_butter)

	## 血量状态变化组件
	hp_component.signal_hp_loss.connect(hp_stage_change_component.judge_body_change)
	## 防具血量状态变化组件
	hp_component.signal_hp_armor1_loss.connect(hp_stage_change_component.judge_body_change_armor.bind(true))
	hp_component.signal_hp_armor2_loss.connect(hp_stage_change_component.judge_body_change_armor.bind(false))

	## 当前动画结束时，移动组件改变移动状态
	anim_component.signal_animation_finished.connect(move_component._on_animation_finished)

	## 被魅惑信号
	signal_character_be_hypno.connect(be_attacked_box_component.owner_be_hypno)
	signal_character_be_hypno.connect(attack_component.owner_be_hypno)
	signal_character_be_hypno.connect(move_component._walking_start)

	## 游泳信号
	swim_box_component.signal_change_is_swimming.connect(change_is_swimming)

	## 铁器防具
	match iron_type:
		Global.IronType.IronArmor1:
			hp_component.signal_armor1_death.connect(func():iron_type=Global.IronType.Null)
		Global.IronType.IronArmor2:
			hp_component.signal_armor2_death.connect(func():iron_type=Global.IronType.Null)

	## 掉落战利品
	hp_component.signal_hp_component_death.connect(drop_item_component.drop_coin)
	hp_component.signal_hp_component_death.connect(drop_item_component.drop_garden_plant)

	## 移动y方向
	move_component.signal_move_body_y.connect(move_y_body)

	## 对移动速度影响,只对速度移动模式生效
	signal_update_speed.connect(move_component.owner_update_speed)
	## 对攻击影响,
	signal_update_speed.connect(attack_component.owner_update_speed)

## 初始化展示角色
func init_show():
	super()
	move_component.disable_component(ComponentBase.E_IsEnableFactor.InitType)

## 改变攻击状态攻击
func change_is_attack(value:bool):
	is_attack = value

## 更新移动方向修正(斜面时使用)
func update_move_dir_y_correct(move_dir_y_correct_slope:Vector2):
	#print("更新移动方向:", move_dir)
	move_component.move_dir_y_correct_slope = move_dir_y_correct_slope


## body\shader\灰烬\受击(真实)框移动y方向
func move_y_body(move_y:float):
	body.position.y += move_y
	shadow.position.y += move_y
	charred_component.position.y += move_y
	hp_component.position.y += move_y
	be_attacked_box_component.move_y_hurt_box_real(move_y)

	for c in special_component_update_pos_in_slope:
		c.update_component_y(move_y)
	for n in special_node2d_update_pos_in_slope:
		n.position.y += move_y

## 改变游泳状态,切换动画时0.2秒过度时间停止移动
func change_is_swimming(value:bool):
	is_swimming = value
	move_component.update_move_factor(true, MoveComponent.E_MoveFactor.IsSwimingChange)
	await get_tree().create_timer(0.2).timeout
	move_component.update_move_factor(false, MoveComponent.E_MoveFactor.IsSwimingChange)
	shadow.visible = not value

#region 僵尸受伤、死亡、
## 角色死亡
func character_death():
	super()
	be_attacked_box_component.queue_free()
	swim_box_component._on_owner_is_death()
	#attack_component.queue_free()

## 僵尸死亡后逐渐透明，最后删除节点
func _fade_and_remove():
	var tween = create_tween()  # 自动创建并绑定Tween节点
	tween.tween_property(self, "modulate:a", 0.0, 1.0)  # 1秒内透明度降为0
	tween.tween_callback(queue_free)  # 动画完成后删除僵尸

## 死亡不消失(海草\TODO:小推车)
func character_death_not_disappear():
	hp_stage_change_component.is_no_change = true
	hp_component.Hp_loss_death()

## 死亡直接消失
func character_death_disappear():
	is_death = true
	hp_stage_change_component.is_no_change = true
	hp_component.Hp_loss_death()
	queue_free()

## 被小推车碾压
## TODO: 修改为原版
func be_mowered_run():
	hp_component.Hp_loss_death(true)

## 角色在泳池中死亡,泳池死亡动画调用
func in_water_death_start():
	var tween = create_tween()
	# 仅移动y轴，在1.5秒内下移200像素
	tween.tween_property(body, "position:y", body.position.y + 80, 2)
	#swim_box_component.in_water_death_start()

## 被水草缠住,
func be_grap_in_pool():
	attack_component.disable_component(ComponentBase.E_IsEnableFactor.Death)
	anim_component.stop_anim()
	move_component.update_move_factor(true, MoveComponent.E_MoveFactor.IsDeath)

## 被炸弹炸
## 灰烬动画从角色本体摘出来,本体节点free,灰烬动画播放玩后删除
## is_cherry_bomb:bool = false ：是否灰烬炸弹(非土豆雷)
func be_bomb(attack_value:int, is_cherry_bomb:bool = false):
	is_can_death_language = false
	hp_component.Hp_loss(attack_value, Global.AttackMode.Penetration, false, false)
	## 如果角色死亡
	if is_death:
		## 在在灰烬动画条件下
		if is_cherry_bomb and (not is_swimming or not curr_be_attack_status != E_BeAttackStatusZombie.IsDownGround):
			charred_component.play_charred_anim()
		queue_free()
	#await get_tree().process_frame
	set_deferred("is_can_death_language", true)

## 被大嘴花吃
func be_chomper_eat(attack_value:int):
	is_can_death_language = false
	hp_component.Hp_loss(attack_value, Global.AttackMode.Penetration, false, false)
	if is_death:
		queue_free()
	#await get_tree().process_frame
	set_deferred("is_can_death_language", true)

## 被倭瓜压
func be_squash(attack_value:int=1800):
	is_can_death_language = false
	hp_component.Hp_loss(attack_value, Global.AttackMode.Penetration, false, false)
	if is_death:
		queue_free()
	#await get_tree().process_frame
	set_deferred("is_can_death_language", true)

#endregion
## 铁器被吸走
## 非一类防具和非二类防具需重写该函数
func be_magnet_iron():
	match iron_type:
		Global.IronType.IronArmor1:
			hp_component.Hp_loss(hp_component.curr_hp_armor1, Global.AttackMode.Norm, false, false)
		Global.IronType.IronArmor2:
			hp_component.Hp_loss(hp_component.curr_hp_armor2, Global.AttackMode.Norm, false, false)
		Global.IronType.IronItem:
			loss_iron_item()

## 失去铁器道具的影响,对应子类继承重写
func loss_iron_item():
	iron_node.visible = false
	iron_type = Global.IronType.Null

## 被吹走,在空中的僵尸被三叶草吹时调用
func be_blow_away():
	pass

## 从地下出来
func zombie_up_from_ground():
	await body.zombie_body_up_from_ground()

## 跳跃被高坚果停止
func jump_be_stop(plant:Plant000Base):
	pass


#region 黄油
## 黄油糊脸
##[butter_time:float]:黄油糊脸时间
func be_butter(butter_time:float=4):
	if not is_death:
		## 黄油节点
		if not is_instance_valid(butter_splat):
			butter_splat = SceneRegistry.BUTTER_SPLAT.instantiate()
			# 将精灵添加到当前场景中
			add_child(butter_splat)
		butter_splat.visible = true
		butter_splat.global_position = head_node.to_global(Vector2(20, 10))

		## 更新速度
		update_speed_factor(0.0, E_Influence_Speed_Factor.Butter)
		if not is_instance_valid(all_timer[E_TimerType.Butter]):
			all_timer[E_TimerType.Butter] = GlobalUtils.create_new_timer_once(self, _on_butter_timer_timeout)

		all_timer[E_TimerType.Butter].start(butter_time)

## 死亡时停止黄油
func death_stop_butter():
	if is_instance_valid(butter_splat):
		_on_butter_timer_timeout()

## 黄油时间计时器结束
func _on_butter_timer_timeout() -> void:
	update_speed_factor(1.0, E_Influence_Speed_Factor.Butter)
	butter_splat.visible = false
#endregion

#region 僵尸吃大蒜换行
func update_lane_on_eat_garlic():
	SoundManager.play_zombie_SFX(0, "yuck")
	update_speed_factor(0.0, E_Influence_Speed_Factor.EatGarlic)
	await get_tree().create_timer(0.5, false).timeout
	update_speed_factor(1.0, E_Influence_Speed_Factor.EatGarlic)
	update_lane()


## 换行
func update_lane():
	## 可以换的行索引
	var can_update_zombie_row_i:Array[int] = []
	if lane != 0 and Global.main_game.zombie_manager.all_zombie_rows[lane-1].zombie_row_type == curr_zombie_row_type:
		can_update_zombie_row_i.append(lane-1)
	if lane != Global.main_game.zombie_manager.all_zombie_rows.size()-1 and Global.main_game.zombie_manager.all_zombie_rows[lane+1].zombie_row_type == curr_zombie_row_type:
		can_update_zombie_row_i.append(lane+1)

	var new_lane_i = can_update_zombie_row_i.pick_random()
	lane = new_lane_i
	signal_lane_update.emit()

	## 禁用攻击组件
	attack_component.disable_component(ComponentBase.E_IsEnableFactor.Garlic)
	GlobalUtils.child_node_change_parent(self, Global.main_game.zombie_manager.all_zombie_rows[lane])
	var tween:Tween = create_tween()
	tween.tween_property(self, ^"position:y", Global.main_game.zombie_manager.all_zombie_rows[lane].zombie_create_position.position.y, 1)
	tween.tween_callback(attack_component.enable_component.bind(ComponentBase.E_IsEnableFactor.Garlic))

#endregion


#region 梯子
## 梯子检测到僵尸时,僵尸爬过梯子
func start_climbing_ladder():
	move_component.start_ladder()

#endregion
