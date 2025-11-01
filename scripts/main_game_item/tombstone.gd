extends Node2D
class_name  TombStone

@onready var tombstone: Sprite2D = $TombstoneMask/tombstone
@onready var gpu_particles_2d: GPUParticles2D = $GPUParticles2D
@onready var mound: Sprite2D = $MoundMask/mound
@onready var tombstone_mask: Panel = $TombstoneMask

@export var zombie_candidate_list :Array[Global.ZombieType]

var plant_cell:PlantCell
var new_zombie:Zombie000Base
var row_col:Vector2i

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_init_tombstone()

## 初始化赋值
func init_tombstone(plant_cell:PlantCell):
	self.plant_cell = plant_cell
	self.row_col = plant_cell.row_col

## 随机生成一种墓碑（一共5种）
func _init_random_frame():
	var random_frame = randi_range(0,4)
	tombstone.frame = random_frame
	mound.frame = random_frame
	SoundManager.play_other_SFX("gravestone_rumble")

## 初始化墓碑
func _init_tombstone():
	_init_random_frame()
	gpu_particles_2d.emitting = true
	var mound_ori_position = mound.position
	var tombstone_ori_position = tombstone.position
	mound.position = Vector2(39, 84)
	tombstone.position = Vector2(39, 136)
	await get_tree().create_timer(0.5).timeout
	var tween := create_tween()
	tween.tween_property(mound, "position", mound_ori_position, 0.1)
	tween.tween_property(tombstone, "position", tombstone_ori_position, 0.5)


## 被墓碑吞吃时修改mask位置
func start_be_grave_buster_eat():
	tombstone_mask.position.y += 30
	tombstone.position.y -= 30

func failure_eat_tombstone():
	tombstone_mask.position.y -= 30
	tombstone.position.y += 30

## 生成僵尸
func create_new_zombie(new_zombie_type:Global.ZombieType, anim_multiply:float=1.0):
	if not new_zombie:
		new_zombie = Global.main_game.zombie_manager.create_norm_zombie(
			new_zombie_type,
			Global.main_game.zombie_manager.all_zombie_rows[row_col.x],
			Character000Base.E_CharacterInitType.IsNorm,
			row_col.x,
			-1,
			Vector2(global_position.x - Global.main_game.zombie_manager.all_zombie_rows[row_col.x].global_position.x,
				Global.main_game.zombie_manager.all_zombie_rows[row_col.x].zombie_create_position.position.y
			)
		)
		new_zombie.call_deferred("update_speed_factor", anim_multiply, Character000Base.E_Influence_Speed_Factor.HammerZombieSpeed)
		await new_zombie.zombie_up_from_ground()
		new_zombie = null
	else:
		print("当前墓碑正在生产僵尸")
