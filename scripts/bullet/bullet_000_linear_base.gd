extends Bullet000Base
class_name BulletLinear000Base
## 直线移动子弹基类

func _process(delta: float) -> void:
	## 每帧移动子弹
	position += direction * speed * delta

	## 移动超过最大距离后销毁，部分子弹有限制
	if global_position.distance_to(start_pos) > max_distance:
		queue_free()

## 改变y位置(三线调用)
func change_y(target_y:float):
	var tween = create_tween()
	var start_y = global_position.y
	tween.tween_method(func(y):
		global_position.y = y,
		start_y,
		target_y,
		0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## 子弹与敌人碰撞,直线子弹检测是否有斜面,判断是否与斜面碰撞
func _on_area_2d_attack_area_entered(area: Area2D) -> void:
	## 线性子弹判断是否攻击到斜坡,非穿透子弹
	if area.owner is Slope:
		if bullet_mode != Global.AttackMode.Penetration:
			var slope:Slope = area.owner
			## 如果方向与斜面法向量夹角小于90度
			if direction.dot(slope.normal_vector_slope) < 0:
				attack_once(null)
		return

	super(area)

## 直线子弹先对壳类进行攻击
func get_first_be_hit_plant_in_cell(plant:Plant000Base)->Plant000Base:
	## shell
	if is_instance_valid(plant.plant_cell.plant_in_cell[Global.PlacePlantInCell.Shell]):
		return plant.plant_cell.plant_in_cell[Global.PlacePlantInCell.Shell]
	elif is_instance_valid(plant.plant_cell.plant_in_cell[Global.PlacePlantInCell.Norm]):
		return plant.plant_cell.plant_in_cell[Global.PlacePlantInCell.Norm]
	elif is_instance_valid(plant.plant_cell.plant_in_cell[Global.PlacePlantInCell.Down]):
		return plant.plant_cell.plant_in_cell[Global.PlacePlantInCell.Down]
	else:
		printerr("当前植物格子没有检测到可以攻击的植物")
		return null
