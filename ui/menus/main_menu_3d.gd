extends Node3D

@onready var sub_viewport = $SubViewport
@onready var sprite_3d = $Sprite3D
@onready var area_3d = $Area3D

func _ready():
	# Connect the input signal
	area_3d.input_event.connect(_on_area_3d_input_event)

func _on_area_3d_input_event(_camera: Node, event: InputEvent, event_pos: Vector3, _normal: Vector3, _shape_idx: int):
	# We rely on the Mouse event to drive the UI
	if event is InputEventMouse:
		# Calculate the 2D position within the viewport
		var pixel_size = sprite_3d.pixel_size
		var viewport_size = Vector2(sub_viewport.size)
		var quad_size = viewport_size * pixel_size
		
		# Position is global collision point. We need it local to the Area3D node to map to UV.
		var local_pos = area_3d.to_local(event_pos)
		
		var half_size = quad_size / 2.0
		
		# Map local X/Y to 0-1 range. 
		# Note: In 3D, local Y is UP, so positive Y is top half.
		# In 2D, Y is DOWN, so 0 is top.
		
		var x_pct = (local_pos.x + half_size.x) / quad_size.x
		var y_pct = (-local_pos.y + half_size.y) / quad_size.y # Invert Y for 2D coord system
		
		var mouse_pos_2d = Vector2(x_pct * viewport_size.x, y_pct * viewport_size.y)
		
		# Duplicate the event to avoid modifying the original if passed elsewhere (though rarely an issue here)
		var input_event_2d = event.duplicate()
		input_event_2d.position = mouse_pos_2d
		input_event_2d.global_position = mouse_pos_2d
		
		# Push the event to the SubViewport
		sub_viewport.push_input(input_event_2d)
