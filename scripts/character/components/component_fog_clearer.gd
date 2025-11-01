extends ComponentBase
class_name FogClearerComponent

@onready var area_2d_fog_clear: Area2D = $Area2DFogClear

var fog_node:Fog

func _ready() -> void:
	super._ready()
	if is_instance_valid(Global.main_game):
		fog_node = Global.main_game.fog_node
	if is_instance_valid(fog_node):
		### 要等待一帧后，不然会有偏移，不知道为什么
		#await get_tree().process_frame
		fog_node.add_fog_clearer(area_2d_fog_clear)

## 植物死亡
func _exit_tree() -> void:
	if is_instance_valid(fog_node):
		### 要等待一帧后，不然会有偏移，不知道为什么
		#await get_tree().process_frame
		fog_node.del_fog_clearer(area_2d_fog_clear)


