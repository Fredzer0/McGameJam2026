extends Control

@export var next_scene: String = "res://ui/menus/MainMenu3D.tscn"

@onready var video: VideoStreamPlayer = $VideoStreamPlayer
@onready var anim: AnimationPlayer = $ColorRect/AnimationPlayer

var is_exiting := false

func _ready():
    video.finished.connect(_on_video_finished)
    video.play()

func _input(event):
    if is_exiting:
        return

    if event is InputEventKey and event.pressed:
        exit_video()

func _on_video_finished():
    exit_video()

func exit_video():
    if is_exiting:
        return

    is_exiting = true
    video.stop()

    anim.play("fade_out")
    await anim.animation_finished

    get_tree().change_scene_to_file(next_scene)