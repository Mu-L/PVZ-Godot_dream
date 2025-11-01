extends Character000Base
class_name Plant000Base

@onready var sleep_component: SleepComponent = %SleepComponent
@onready var blink_component: BlinkComponent = %BlinkComponent
## 花园组件
@onready var garden_component: GardenComponent = %GardenComponent

#region 植物类基础属性
@export var plant_type:Global.PlantType
## 植物初始化受击状态（从1[is_norm] 开始）僵尸攻击检测时判断是否可以攻击
@export var init_be_attack_status :E_BeAttackStatusPlant = 1
## 是否白天睡觉
@export var is_sleep_in_day:bool = false
## 植物是否可以挂载梯子(Nrom位置植物使用)
@export var is_can_ladder := false
## 植物当前状态，僵尸攻击检测时判断是否可以攻击
var curr_be_attack_status:E_BeAttackStatusPlant
## 行和列
var row_col:Vector2i = Vector2i(-1, -1)
## 植物所在格子
var plant_cell:PlantCell
## 植物死亡后是否直接删除
var is_death_free:= true

#endregion

#region 植物动画
@export_group("动画状态")
@export var is_sleeping:=false
## 是否在花园水族馆
@export var is_garden_aquarium := false

## 植物梯子状态变化信号
signal signal_ladder_update

#region 角色枚举
## 检测攻击时，根据状态判断是否可以攻击
enum E_BeAttackStatusPlant{
	IsNorm = 1,		## 正常
	IsFloat = 2,	## 悬浮
	IsDown = 4, 	## 地刺
}
#endregion


#region 花园植物
## 花园初始化数据
var garden_date_init:Dictionary
#endregion


#region 初始化相关
func _ready() -> void:
	super()
	if plant_type == 0:
		push_error(name, "植物类型未赋值")

## 植物初始化相关, 创建植物时 加入场景树之前赋值
func init_plant(init_type:E_CharacterInitType=E_CharacterInitType.IsNorm, plant_cell:PlantCell=null, garden_date:Dictionary={}) -> void:
	self.character_init_type = init_type
	match init_type:
		E_CharacterInitType.IsNorm:
			self.plant_cell = plant_cell
			self.row_col = plant_cell.row_col
			self.lane = plant_cell.row_col.x
		E_CharacterInitType.IsShow:
			### 南瓜背景-1,这里所有植物+1
			#z_index += 1
			pass
		E_CharacterInitType.IsGarden:
			### 南瓜背景-1,这里所有植物+1
			#z_index += 1
			garden_date_init = garden_date
			## 是否为水族馆背景，动画变化
			is_garden_aquarium = garden_date["curr_garden_bg_type"]== GardenManager.E_GardenBgType.Aquarium
			#for c in get_children():
				#if not c.is_in_group("G_Garden") and c is ComponentBase:
					#c = c as ComponentBase
					#c.disable_component(ComponentBase.E_IsEnableFactor.Defautl)


## 初始化正常出战角色信号连接
func init_norm_signal_connect():
	super()
	## 发射子弹攻击组件影响植物眨眼
	var attack_component :AttackComponentBulletBase = get_node_or_null(^"AttackComponent")
	if attack_component:
		attack_component.signal_change_is_attack.connect(
			## 可以攻击时禁用眨眼
			func(value):blink_component.change_is_enabling.bind(not value, ComponentBase.E_IsEnableFactor.Attack)
		)

	## 植物睡眠组件
	sleep_component.signal_is_sleep.connect(update_is_sleeping.bind(true))
	sleep_component.signal_not_is_sleep.connect(update_is_sleeping.bind(false))

	## 植物睡眠影响的组件
	for sleep_influence_component in sleep_component.sleep_influence_components:
		sleep_component.signal_is_sleep.connect(sleep_influence_component.disable_component.bind(ComponentBase.E_IsEnableFactor.Sleep))
		sleep_component.signal_not_is_sleep.connect(sleep_influence_component.enable_component.bind(ComponentBase.E_IsEnableFactor.Sleep))

## 初始化正常出战角色
func init_norm():
	super()
	garden_component.queue_free()
	curr_be_attack_status = init_be_attack_status
	## 如果白天睡觉
	if is_sleep_in_day:
		sleep_component.judge_is_sleeping()

	## 斜面与水平面的差值
	var diff_slope_flat:float = 0
	if is_instance_valid(plant_cell):
		diff_slope_flat = plant_cell.position.y

	if diff_slope_flat != 0:
		position.y -= diff_slope_flat
		body.position.y += diff_slope_flat
		shadow.position.y += diff_slope_flat
		hp_component.position.y += diff_slope_flat
		be_attacked_box_component.move_y_hurt_box_real(diff_slope_flat)
		for c in special_component_update_pos_in_slope:
			c.update_component_y(diff_slope_flat)
		for n in special_node2d_update_pos_in_slope:
			n.position.y += diff_slope_flat
## 初始化展示角色
func init_show():
	super()
	garden_component.queue_free()

## 初始化花园角色
func init_garden():
	super()
	garden_component.init_garden_component(garden_date_init)
	sleep_component.signal_is_sleep.connect(garden_component.disable_component.bind(ComponentBase.E_IsEnableFactor.Sleep))
	sleep_component.signal_not_is_sleep.connect(garden_component.enable_component.bind(ComponentBase.E_IsEnableFactor.Sleep))
	## 如果白天睡觉
	if is_sleep_in_day:
		sleep_component.judge_is_sleeping()
	shadow.visible = false

#endregion

#region 植物受伤、死亡
## 被蹦极僵尸偷走
func be_bungi()->Node2D:
	var body_copy:Node2D = body.duplicate()
	plant_cell.add_child(body_copy)
	body_copy.global_position = body.global_position
	## 死亡直接消失,复制一个body给蹦极
	character_death_disappear()
	return body_copy

## 被僵尸啃食
## attack_value:伤害
## attack_zombie:攻击的僵尸
func be_zombie_eat(attack_value:int, attack_zombie:Zombie000Base):
	hp_component.Hp_loss(attack_value, Global.AttackMode.Penetration, true, false)

## 被僵尸啃食一次发光
func be_zombie_eat_once(attack_zombie:Zombie000Base):
	body.body_light()
	_be_zombie_eat_once_special(attack_zombie)

## 被僵尸啃食一次特殊效果,魅惑\大蒜
func _be_zombie_eat_once_special(attack_zombie:Zombie000Base):
	pass

## 植物死亡
func character_death():
	## 发射死亡信号
	super()
	if is_instance_valid(be_attacked_box_component):
		## 要先删除碰撞器，否则僵尸攻击检测组件有问题
		be_attacked_box_component.queue_free()
	if is_death_free:
		queue_free()

## 死亡不消失
func character_death_not_disappear():
	is_death_free = false
	hp_component.Hp_loss_death()

#endregion

#region 与铲子\种植交互
## 被铲子威胁
func be_shovel_look():
	if Global.plant_be_shovel_front:
		z_index += 10
	body.set_other_color(BodyCharacter.E_ChangeColors.BeShovelLookColor, Color(2, 2, 2))

## 被铲子威胁结束
func be_shovel_look_end():
	if Global.plant_be_shovel_front:
		z_index -= 10
	body.set_other_color(BodyCharacter.E_ChangeColors.BeShovelLookColor, Color(1, 1, 1))

## 被铲子铲除,禁止亡语
func be_shovel_kill():
	is_can_death_language = false
	hp_component.Hp_loss_death()

## 手持紫卡植物可以种植在该植物上
func preplant_purple_body_light_and_dark():
	if Global.plant_be_shovel_front:
		z_index += 10
	body.body_light_and_dark()

## 手持紫卡植物可以种植在该植物上结束
func preplant_purple_body_light_and_dark_end():
	if Global.plant_be_shovel_front:
		z_index -= 10
	body.body_light_and_dark_end()

#endregion
## 睡眠植物被咖啡豆唤醒
func coffee_bean_awake_up():
	var tween:Tween = create_tween()
	tween.tween_property(body, ^"scale:y", 0.8, 0.5)
	tween.tween_property(body, ^"scale:y", 1.2, 0.5)
	tween.tween_property(body, ^"scale:y", 1, 0.5)
	tween.tween_callback(sleep_component.end_sleep)


## 植物修改睡眠
func update_is_sleeping(is_sleeping:bool):
	self.is_sleeping = is_sleeping


#region 花园植物
## 满足当前需求
func satisfy_need(item: GardenManager.E_NeedItem):
	garden_component.satisfy_need(item)

## 获取当前花园植物数据
func get_curr_plant_data():
	return garden_component.get_curr_plant_data()
#endregion
