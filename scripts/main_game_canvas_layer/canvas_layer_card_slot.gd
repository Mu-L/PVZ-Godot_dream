extends CanvasLayer
class_name CanvasLayerCardSlot

@onready var card_slot_root: CardSlotRoot = %CardSlotRoot


func _ready() -> void:
	Global.signal_change_card_slot_top_mouse_focus.connect(card_slot_top_mouse_focus)
	card_slot_root.mouse_entered.connect(_on_bg_mouse_entered)
	card_slot_root.mouse_exited.connect(_on_bg_mouse_exited)

#region 卡槽处于焦点时置顶
func _on_bg_mouse_entered() -> void:
	if Global.card_slot_top_mouse_focus and Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME:
		# 鼠标进入时，提高z_index，保证在前面显示
		layer = 1

func _on_bg_mouse_exited() -> void:
	if Global.card_slot_top_mouse_focus and Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME:
		# 鼠标离开时，恢复原始
		layer = -1

## 修改控制台按钮时
## 植物卡槽取消置顶,取消鼠标焦点卡槽置顶时
func card_slot_top_mouse_focus():
	if not Global.card_slot_top_mouse_focus:
		layer = -1

#endregion
