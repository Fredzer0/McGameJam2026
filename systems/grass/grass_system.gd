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

@export_group("Tall Grass Settings")
@export var tall_grass_noise: FastNoiseLite:
	set(value):
		tall_grass_noise = value
		if value and not value.changed.is_connected(populate_grass):
			value.changed.connect(populate_grass)
		if is_node_ready():
			populate_grass()

## The threshold for the noise value (0.0 to 1.0) above which grass becomes tall
@export_range(-1.0, 1.0) var tall_grass_threshold: float = 0.1:
	set(value):
		tall_grass_threshold = value
		if is_node_ready():
			populate_grass()

@export_range(0, 360) var uniform_rotation_degrees: float = 0.0:
	set(value):
		uniform_rotation_degrees = value
		if is_node_ready():
			populate_grass()

const GRASS_MESH = preload("res://systems/grass/SM_grassBlade_01.obj")
const SHORT_GRASS_MATERIAL = preload("res://systems/grass/materials/short_grass.tres")
const TALL_GRASS_MATERIAL = preload("res://systems/grass/materials/tall_grass.tres")

var _short_grass_mm: MultiMeshInstance3D
var _tall_grass_mm: MultiMeshInstance3D

func _ready() -> void:
	# Setup Short Grass
	_short_grass_mm = MultiMeshInstance3D.new()
	_short_grass_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_short_grass_mm.layers = 2
	_short_grass_mm.name = "ShortGrassMM"
	add_child(_short_grass_mm)
	
	_short_grass_mm.multimesh = MultiMesh.new()
	_short_grass_mm.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_short_grass_mm.multimesh.use_colors = true
	_short_grass_mm.multimesh.mesh = GRASS_MESH
	_short_grass_mm.material_override = SHORT_GRASS_MATERIAL

	# Setup Tall Grass
	_tall_grass_mm = MultiMeshInstance3D.new()
	_tall_grass_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_tall_grass_mm.layers = 2
	_tall_grass_mm.name = "TallGrassMM"
	add_child(_tall_grass_mm)
	
	_tall_grass_mm.multimesh = MultiMesh.new()
	_tall_grass_mm.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_tall_grass_mm.multimesh.use_colors = true
	_tall_grass_mm.multimesh.mesh = GRASS_MESH
	_tall_grass_mm.material_override = TALL_GRASS_MATERIAL
	
	# Listen for children changes to re-populate
	child_entered_tree.connect(func(_node): populate_grass())
	child_exiting_tree.connect(func(_node): populate_grass())
	
	populate_grass()

func populate_grass() -> void:
	if not _short_grass_mm or not _short_grass_mm.multimesh or not _tall_grass_mm or not _tall_grass_mm.multimesh:
		return
		
	# Clear existing instances
	_short_grass_mm.multimesh.instance_count = 0
	_tall_grass_mm.multimesh.instance_count = 0
	
	var areas_data = [] 
	
	# Collect spawn areas
	for child in get_children():
		if child == _short_grass_mm or child == _tall_grass_mm: continue 
		
		if child is Area3D:
			for grandchild in child.get_children():
				if grandchild is CollisionShape3D and grandchild.shape is BoxShape3D:
					var shape = grandchild.shape as BoxShape3D
					var size = shape.size
					var area_xz = size.x * size.z
					# Calculate approximate count, we might skip some depending on implementation, 
					# or better yet, just generate points and decide type.
					var count = int(area_xz * density)
					
					areas_data.append({
						"shape": shape,
						"transform": grandchild.global_transform,
						"count": count,
						"size": size
					})

	if areas_data.is_empty():
		return

	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# Temporary arrays to hold transforms before setting them to MultiMeshes
	var short_instances = []
	var tall_instances = []
	
	# We need to transform global points to local space of the MultiMeshInstance
	# Assuming both MM instances are at (0,0,0) locally relative to this node, 
	# but safer to check. Since we add them as children, global_transform.affine_inverse() 
	# of THIS node is what we want if we assume MMs inherit transform identity.
	var my_global_inverse = global_transform.affine_inverse()
	
	# Use default noise if not assigned
	var noise = tall_grass_noise
	if not noise:
		noise = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_PERLIN
		noise.frequency = 0.5
		noise.seed = 1234
	
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
			# Convert to local space of the grass system
			var point_local = my_global_inverse * point_world
			
			point_local.y += 0.5 
			
			var rotation_y = deg_to_rad(uniform_rotation_degrees)
			if random_rotation:
				rotation_y = rng.randf_range(0, TAU)
			
			var basis = Basis(Vector3.UP, rotation_y)
			var transform = Transform3D(basis, point_local)
			
			# Decide if tall or short
			var noise_val = noise.get_noise_2d(point_world.x, point_world.z)
			if noise_val > tall_grass_threshold:
				tall_instances.append(transform)
			else:
				short_instances.append(transform)

	# Apply to MultiMeshes
	_short_grass_mm.multimesh.instance_count = short_instances.size()
	for i in range(short_instances.size()):
		_short_grass_mm.multimesh.set_instance_transform(i, short_instances[i])
		
	_tall_grass_mm.multimesh.instance_count = tall_instances.size()
	for i in range(tall_instances.size()):
		_tall_grass_mm.multimesh.set_instance_transform(i, tall_instances[i])
