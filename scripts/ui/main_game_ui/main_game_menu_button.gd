extends PVZButtonBase


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	button_down.connect(SoundManager.play_sfx.bind("MainGameUI/ButtonDown"))
