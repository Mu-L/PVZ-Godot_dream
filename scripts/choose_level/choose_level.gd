extends Control
class_name ChooseLevel

## 用于生成关卡 ID 的计数
var next_level_number: int = 1

@onready var all_page: Control = $AllPage
@onready var label_page: Label = get_node_or_null("LabelPage")
## 游戏模式,用于管理关卡存档
@export var game_mode:Global.MainScenes = Global.MainScenes.Null

var all_pages_array : Array[GridContainer]
@export var curr_page := 0

## 选卡bgm
var bgm_choose_card: AudioStream = preload("res://assets/audio/BGM/choose_card.mp3")

func _ready() -> void:

	for page_i in all_page.get_child_count():
		var page = all_page.get_child(page_i)
		all_pages_array.append(page)
		page.visible = false
		for node in page.get_children():
			## 如果是选关按钮
			if node is ChooseLevelButton:
				var level_id:String = generate_level_id()
				if node.curr_level_data_game_para == null:
					continue
				node.signal_choose_level_button.connect(_on_choose_level_button)
				## 初始化游戏数据的选关数据
				node.curr_level_data_game_para.set_choose_level(game_mode, page_i, level_id)
				node.update_curr_level_button_state(Global.curr_all_level_state_data.get(node.curr_level_data_game_para.save_game_name, {}))

	print("当前模式关卡数量:", next_level_number - 1)

	_ready_update_page()


func _ready_update_page():
	## 如果从游戏中退出
	if Global.game_para != null and Global.game_para.game_mode == game_mode:
		curr_page = Global.game_para.level_page

	if curr_page > all_pages_array.size():
		curr_page = 0
	if not all_pages_array.is_empty():
		all_pages_array[curr_page].visible = true
		if is_instance_valid(label_page):
			_update_page(curr_page)

	SoundManager.play_bgm(bgm_choose_card)

## 获取关卡id
func generate_level_id() -> String:
	# 用格式化字符串，让数字变成 4 位，前面补 0
	# GDScript 支持类似 C 风格字符串格式化
	var id_str = "%04d" % next_level_number  # 例如 0 -> "0000", 12 -> "0012"
	next_level_number += 1
	return id_str

func _on_choose_level_button(choose_level_button:ChooseLevelButton):
	Global.game_para = choose_level_button.curr_level_data_game_para
	choose_level_start_game(choose_level_button.curr_level_data_game_para.game_sences)

## 进入游戏关卡
func choose_level_start_game(game_scense:Global.MainScenes):
	get_tree().change_scene_to_file(Global.MainScenesMap[game_scense])

## 返回开始菜单
func back_start_menu():
	get_tree().change_scene_to_file(Global.MainScenesMap[Global.MainScenes.StartMenu])


func _on_last_pressed() -> void:
	_update_page(curr_page - 1)

func _on_next_pressed() -> void:
	_update_page(curr_page + 1)


func _update_page(new_page:int):
	new_page = posmod(new_page, all_pages_array.size())
	all_pages_array[curr_page].visible = false
	curr_page = new_page
	all_pages_array[curr_page].visible = true
	label_page.text = "当前页数:" + str(curr_page + 1) + "/" + str(all_pages_array.size())
