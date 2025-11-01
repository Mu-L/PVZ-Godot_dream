extends Plant000Base
class_name Plant042TwinSunFlower

@onready var create_sun_component: CreateSunComponent = $CreateSunComponent


## 初始化正常出战角色信号连接
func init_norm_signal_connect():
	super()
	signal_update_speed.connect(create_sun_component.owner_update_speed)
