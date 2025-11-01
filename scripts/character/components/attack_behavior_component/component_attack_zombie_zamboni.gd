extends AttackComponentBase
class_name AttackComponentZombieZamboni

## 开始攻击
func attack_start():
	detect_component.enemy_can_be_attacked.be_flattened(owner)

## 结束攻击
func attack_end():
	pass

## 修改速度
func owner_update_speed(speed_product:float):
	pass
