extends Node
class_name CardManager

@onready var card_slot_root: CardSlotRoot = %CardSlotRoot
@onready var card_slot_container: PanelContainer = %CardSlotContainer

## 普通卡槽
var card_slot_norm: CardSlotNorm
var card_slot_battle:CardSlotBattle
## 普通卡槽是否已出现
var is_norm_appeared:=false

## 传送带卡槽
var card_slot_conveyor_belt: CardSlotConveyorBelt

## 金币卡槽
var card_slot_coin: CardSlotCoin
var card_slot_battle_coin: CardSlotBattleCoin

var card_mode:ResourceLevelData.E_CardMode

## 是否有铲子
var is_shovel:=true

## 当前的卡片
var curr_cards:Array[Card]

## 初始化卡片管理器
func init_card_manager(game_para:ResourceLevelData):
	self.card_mode = game_para.card_mode
	self.is_shovel = game_para.is_shovel
	match self.card_mode:
		ResourceLevelData.E_CardMode.Norm:
			card_slot_norm = load("res://scenes/card_slot/card_slot_norm.tscn").instantiate()
			card_slot_root.add_child(card_slot_norm)
			card_slot_norm.init_card_slot_norm(game_para)
			card_slot_battle = card_slot_norm.card_slot_battle
			card_slot_root.curr_cards = card_slot_battle.curr_cards
			curr_cards = card_slot_battle.curr_cards

		ResourceLevelData.E_CardMode.ConveyorBelt:
			card_slot_conveyor_belt = load("res://scenes/card_slot/card_slot_conveyor_belt.tscn").instantiate()
			card_slot_root.add_child(card_slot_conveyor_belt)
			card_slot_conveyor_belt.init_card_slot_conveyor_belt(game_para)
			card_slot_root.curr_cards = card_slot_conveyor_belt.curr_cards
			curr_cards = card_slot_conveyor_belt.curr_cards

		ResourceLevelData.E_CardMode.Coin:
			card_slot_coin = load("res://scenes/card_slot/card_slot_coin.tscn").instantiate()
			card_slot_root.add_child(card_slot_coin)
			card_slot_coin.init_card_slot_coin(game_para)
			card_slot_battle_coin = card_slot_coin.card_slot_battle_coin
			card_slot_root.curr_cards = card_slot_battle_coin.curr_cards
			curr_cards = card_slot_battle_coin.curr_cards

## 卡槽出现(选卡)
func card_slot_appear_choose():
	is_norm_appeared = true
	card_slot_norm.move_card_slot_battle(true)
	card_slot_norm.move_card_slot_candidate(true)

## 卡槽出现（主游戏阶段开始）
func card_slot_update_main_game():
	match self.card_mode:
		ResourceLevelData.E_CardMode.Norm:
			if not is_norm_appeared:
				await card_slot_norm.move_card_slot_battle(true)
			card_slot_norm.remove_child(card_slot_battle)
			card_slot_container.add_child(card_slot_battle)
			card_slot_battle.main_game_refresh_card()
			## 测试模式卡片没有冷却
			if Global.main_game.is_test:
				for card in card_slot_battle.curr_cards:
					card.card_change_cool_time(0)
		ResourceLevelData.E_CardMode.ConveyorBelt:
			await card_slot_conveyor_belt.move_card_slot_conveyor_belt(true)
			card_slot_root.remove_child(card_slot_conveyor_belt)
			card_slot_container.add_child(card_slot_conveyor_belt)
			card_slot_conveyor_belt.start_conveyor_belt()
		ResourceLevelData.E_CardMode.Coin:
			if not is_norm_appeared:
				await card_slot_coin.move_card_slot_battle(true)
			card_slot_coin.remove_child(card_slot_battle_coin)
			card_slot_container.add_child(card_slot_battle_coin)
			card_slot_battle_coin.main_game_refresh_card()
			## 测试模式卡片没有冷却
			if Global.main_game.is_test:
				for card in card_slot_battle_coin.curr_cards:
					card.card_change_cool_time(0)
	if is_shovel:
		card_slot_root.ui_shovel.visible = true

## 待选卡槽卡槽消失
func card_slot_disappear_choose():
	await card_slot_norm.move_card_slot_candidate(false)

