@tool
extends Node3D

@export var density: float = 10.0: # Instances per square unit
	set(value):
		density = value
		if is_node_ready():
			populate_grass()

@export var random_rotation: bool = false:
	set(value):
		random_rotation = value
		if is_node_ready():
			populate_grass()

@export_range(0, 360) var uniform_rotation_degrees: float = 0.0:
	set(value):
		uniform_rotation_degrees = value
		if is_node_ready():
			populate_grass()

@export var alpha_texture: Texture2D:
	set(value):
		alpha_texture = value
		_update_material_properties()

@export var noise_texture: Texture2D:
	set(value):
		noise_texture = value
		_update_material_properties()

@export var noise_scale: float = 0.05:
	set(value):
		noise_scale = value
		_update_material_properties()

@export var grass_color: Color = Color(0.1, 0.5, 0.1, 1):
	set(value):
		grass_color = value
		_update_material_properties()

@export var grass_color_tip: Color = Color(0.5, 0.8, 0.2, 1):
	set(value):
		grass_color_tip = value
		_update_material_properties()

@export var sway_speed: float = 1.0:
	set(value):
		sway_speed = value
		_update_material_properties()

@export var sway_strength: float = 0.1:
	set(value):
		sway_strength = value
		_update_material_properties()

var _multimesh_instance: MultiMeshInstance3D

func _update_material_properties() -> void:
	if _multimesh_instance and _multimesh_instance.multimesh and _multimesh_instance.multimesh.mesh:
		var mat = _multimesh_instance.multimesh.mesh.surface_get_material(0) as ShaderMaterial
		if mat:
			mat.set_shader_parameter("alpha_texture", alpha_texture)
			mat.set_shader_parameter("noise_texture", noise_texture)
			mat.set_shader_parameter("noise_scale", noise_scale)
			mat.set_shader_parameter("color", grass_color)
			mat.set_shader_parameter("color_tip", grass_color_tip)
			mat.set_shader_parameter("sway_speed", sway_speed)
			mat.set_shader_parameter("sway_strength", sway_strength)
			mat.set_shader_parameter("variation_strength", 0.5)

func _ready() -> void:
	_multimesh_instance = MultiMeshInstance3D.new()
	# Important: Do NOT set name or owner if we don't want it saved. 
	add_child(_multimesh_instance)
	
	_multimesh_instance.multimesh = MultiMesh.new()
	_multimesh_instance.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh_instance.multimesh.mesh = load("res://systems/grass/SM_grassBlade_01.obj")
		
	# Setup internal material
	var mat = ShaderMaterial.new()
	mat.shader = load("res://systems/grass/grass.gdshader")
	_multimesh_instance.multimesh.mesh.surface_set_material(0, mat)
	
	# Load default texture if not set
	if not alpha_texture:
		var tex_path = "res://systems/grass/T_GrassBlade_A.png"
		if ResourceLoader.exists(tex_path):
			alpha_texture = load(tex_path)
	
	# Ensure texture and params are applied
	_update_material_properties()
	
	# Listen for children changes to re-populate
	child_entered_tree.connect(func(_node): populate_grass())
	child_exiting_tree.connect(func(_node): populate_grass())
	
	populate_grass()

func populate_grass() -> void:
	if not _multimesh_instance or not _multimesh_instance.multimesh:
		return
		
	# Clear existing instances
	_multimesh_instance.multimesh.instance_count = 0
	
	var total_instances = 0
	var areas_data = [] 
	
	# First pass: Calculate total instances needed
	for child in get_children():
		if child == _multimesh_instance: continue 
		
		if child is Area3D:
			for grandchild in child.get_children():
				if grandchild is CollisionShape3D and grandchild.shape is BoxShape3D:
					var shape = grandchild.shape as BoxShape3D
					var size = shape.size
					var area_xz = size.x * size.z
					var count = int(area_xz * density)
					total_instances += count
					
					areas_data.append({
						"shape": shape,
						"transform": grandchild.global_transform,
						"count": count,
						"size": size
					})

	if total_instances == 0:
		return

	_multimesh_instance.multimesh.instance_count = total_instances
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	var instance_index = 0
	
	# We need to transform global points to local space of the MultiMeshInstance
	var my_global_inverse = _multimesh_instance.global_transform.affine_inverse()
	
	for data in areas_data:
		var count = data["count"]
		var size = data["size"]
		var shape_transform = data["transform"]
		
		for i in range(count):
			var rx = rng.randf_range(-size.x / 2.0, size.x / 2.0)
			var rz = rng.randf_range(-size.z / 2.0, size.z / 2.0)
			var ry = 0.0
			
			var point_in_shape = Vector3(rx, ry, rz)
			var point_world = shape_transform * point_in_shape
			var point_local = my_global_inverse * point_world
			
			point_local.y += 0.5 
			
			var rotation_y = deg_to_rad(uniform_rotation_degrees)
			if random_rotation:
				rotation_y = rng.randf_range(0, TAU)
				
			var basis = Basis(Vector3.UP, rotation_y)
			var transform = Transform3D(basis, point_local)
			
			_multimesh_instance.multimesh.set_instance_transform(instance_index, transform)
			instance_index += 1
