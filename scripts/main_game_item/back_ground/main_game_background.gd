extends Sprite2D
class_name MainGameBackGround

@onready var home: MainGameHome = %Home

## 初始化背景
func init_background(game_para:ResourceLevelData):
	var curr_texture: Texture2D = game_para.GameBgTextureMap[game_para.game_BG]
	self.texture = curr_texture
	home.init_home(game_para.game_BG)

	if game_para.is_fog:
		Global.main_game.fog_node = SceneRegistry.FOG.instantiate()
		add_child(Global.main_game.fog_node)
	match game_para.game_BG:
		ResourceLevelData.GameBg.Pool, ResourceLevelData.GameBg.Fog:
			var pool:Pool = get_node(^"Pool")
			pool.init_pool(game_para.game_BG)
