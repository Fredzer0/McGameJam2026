extends CanvasLayer

@onready var label: Label = $Label

func _ready() -> void:
    # Default to hidden if user prefers, or visible. "can disable" implies enabled by default.
    visible = true

func _process(_delta: float) -> void:
    if visible:
        label.text = "FPS: %d" % Engine.get_frames_per_second()

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
        visible = not visible
