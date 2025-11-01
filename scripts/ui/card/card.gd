extends CardBase
class_name Card

@onready var character_static: Node2D = $CardBg/CharacterStatic
@onready var short_cut: Label = $ShortCut
@onready var button: Button = $Button

var _is_cooling : bool = false		# 是否正在冷却
var is_sun_enough: bool = true		# 阳光是否足够
var _cool_timer : float				# 冷却计时器
var is_can_click := true		## 是否可以点击


#region 开局选卡相关
## 开局选择卡片时 是否被选中
var is_choosed_pre_card := false
var card_candidate_container:CardCandidateContainer
#endregion

## 点击信号,选卡时使用该信号(种植点击使用时间总线)
signal signal_card_click(card:Card)
## 卡片种植完成后信号，生成卡片所在卡槽连接该信号
signal signal_card_use_end(card:Card)

func _ready() -> void:
	super()
	_cool_mask.value = 0

## 改变卡片的冷却时间（测试时使用）
func card_change_cool_time(cool_time:float):
	self.cool_time = cool_time
	_cool_mask.value = 0

## 设置卡片冷却时间并开始冷却
func set_card_cool_time_start_cool(cool_time:float):
	self.cool_time = cool_time
	_cool_mask.value = cool_time
	card_cool()

## 设置卡片禁用(不冷却)
func set_card_disabel():
	self.cool_time = 1
	_cool_mask.value = cool_time
	_is_cooling = false
	_cool_mask.visible = true
	is_can_click = false

## 传送带卡槽初始化卡片
func card_init_conveyor_belt():
	_cool_mask.value = 0
	sun_cost = 0


## 卡片冷卻
func _process(delta: float) -> void:
	if _is_cooling:
		_cool_timer -= delta
		_cool_mask.value = _cool_timer
		# 卡片冷却完成
		if _cool_timer <= 0:
			_is_cooling = false
			judge_card_ready()

## 修改阳光时会调用
func judge_sun_enough(curr_sun_value):
	# 判断阳光是否足够
	is_sun_enough = curr_sun_value >= sun_cost
	judge_card_ready()

## 判断卡片是否可以点击
func judge_card_ready():
	# 阳光充足 且 卡片冷却完成
	if is_sun_enough and not _is_cooling:
		## 紫卡并且不能种植
		if is_purple_card and not plant_condition.judge_purple_card_can_plant(Global.main_game.plant_cell_manager.all_plant_cells, card_plant_type):
			card_not_can_click()
		else:
			card_ready()
	else:
		card_not_can_click()


## 卡片可以点击
func card_ready():
	_cool_mask.visible = false
	is_can_click = true

## 卡片不可以点击
func card_not_can_click():
	_cool_mask.visible = true
	is_can_click = false

## 卡片开始冷却
func card_cool():
	_is_cooling = true
	_cool_mask.visible = true
	_cool_timer = cool_time
	_cool_mask.value = cool_time
	is_can_click = false

## 点击卡片时
func _on_button_pressed() -> void:
	## 如果时主游戏场景,并且游戏中
	if is_instance_valid(Global.main_game) and Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME:
		## 可以点击
		if is_can_click:
			EventBus.push_event("main_game_click_card", [self])
		else:
			SoundManager.play_other_SFX("buzzer")
	else:
		signal_card_click.emit()

## 快捷键设置
func set_shortcut(i:int):
	short_cut.text = str(i)
	short_cut.visible = true
