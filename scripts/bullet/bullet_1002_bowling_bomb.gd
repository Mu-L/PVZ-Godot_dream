extends BulletLinear000Base
class_name Bullet1002BowlingBomb

@onready var body_correct: Node2D = $Body/BodyCorrect
@onready var bomb_component: BombComponentNorm = %BombComponent

## 旋转速度
var rotation_speed = 5.0


func _process(delta: float) -> void:
	super._process(delta)
	body_correct.rotation += rotation_speed * delta


## 攻击一次
func attack_once(enemy:Character000Base):
	bomb_component.bomb_once()
	queue_free()
