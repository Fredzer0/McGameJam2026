extends Node3D

@export var auto_fill: bool = true
@export var duration: float = 1.5

func _ready() -> void:
    if auto_fill:
        # If auto_fill is true (casting mode), wait for duration then destroy
        await get_tree().create_timer(duration).timeout
        queue_free()
    else:
        # If auto_fill is false (targeting mode), stay alive until manually freed
        pass
