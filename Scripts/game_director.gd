extends Node3D

var totalVillagerCount

var currentVillagerCount
var remainingTime
# Called when the node enters the scene tree for the first time.
func _ready() -> void:

	totalVillagerCount = get_tree().get_nodes_in_group("npc").size()
	currentVillagerCount = totalVillagerCount
	$Timer.timeout.connect(_on_timer_timeout)
	$Timer.start()
	

	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:

	remainingTime = $Timer.time_left
	print_debug(remainingTime)
	if (currentVillagerCount == 0):
		win()
	pass



func morphVillager():
	currentVillagerCount -= 1

func unmorphVillager():
	currentVillagerCount += 1

func _on_timer_timeout() -> void:
	lose()

func win():
	#$AnimationPlayer.play("fade_out")
	#await $AnimationPlayer.animation_finished
	get_tree().change_scene_to_file("res://levels/GameWin.tscn")

func lose():
	#$AnimationPlayer.play("fade_out")
	#await $AnimationPlayer.animation_finished
	get_tree().change_scene_to_file("res://levels/GameOver.tscn")
