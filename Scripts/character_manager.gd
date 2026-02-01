extends Node

signal character_changed(model_path: String)

enum WitchType {
	CONE_HAT,
	FLOWER_HAT,
	HORSE_HAT
}

var current_index: int = 0
var models: Array[String] = [
	"res://animation/witch/models/SK_Witch_And_ConeHat.fbx",
	"res://animation/witch/models/SK_Witch_And_FlowerHat.fbx",
	"res://animation/witch/models/SK_Witch_And_HorseHat.fbx"
]

func next_character() -> void:
	current_index += 1
	if current_index >= models.size():
		current_index = 0
	_emit_change()

func previous_character() -> void:
	current_index -= 1
	if current_index < 0:
		current_index = models.size() - 1
	_emit_change()

func get_current_model_path() -> String:
	return models[current_index]

func _emit_change() -> void:
	character_changed.emit(models[current_index])
