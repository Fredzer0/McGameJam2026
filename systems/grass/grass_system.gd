@tool
extends Node3D

@export var density: float = 10.0: # Instances per square unit
	set(value):
		density = value
		if is_node_ready():
			mark_dirty()

@export var random_rotation: bool = false:
	set(value):
		random_rotation = value
		if is_node_ready():
			mark_dirty()

@export_group("Tall Grass Settings")
@export var tall_grass_noise: FastNoiseLite:
	set(value):
		tall_grass_noise = value
		if value and not value.changed.is_connected(mark_dirty):
			# Disconnect old signal if needed? Standard practice is tricky here without prev value. 
			# Simplified: Just connect new. Old listeners might leak if changing noise frequently.
			# But for tool scripts usually fine. 
			# Ideally we should disconnect old, but let's stick to the current logic pattern.
			value.changed.connect(mark_dirty)
		if is_node_ready():
			mark_dirty()

## The threshold for the noise value (0.0 to 1.0) above which grass becomes tall
@export_range(-1.0, 1.0) var tall_grass_threshold: float = 0.1:
	set(value):
		tall_grass_threshold = value
		if is_node_ready():
			mark_dirty()

@export_range(0, 360) var uniform_rotation_degrees: float = 0.0:
	set(value):
		uniform_rotation_degrees = value
		if is_node_ready():
			mark_dirty()

@export var spawn_mask: Texture2D:
	set(value):
		spawn_mask = value
		if is_node_ready():
			mark_dirty()

@export var chunk_size: float = 5.0:
	set(value):
		chunk_size = value
		if is_node_ready():
			mark_dirty()

@export var view_distance: float = 50.0:
	set(value):
		view_distance = value
		if is_node_ready():
			mark_dirty()

@export var animation_distance: float = 20.0:
	set(value):
		animation_distance = value
		_update_material_parameters()

const GRASS_MESH = preload("res://systems/grass/SM_grassBlade_01.obj")
const SHORT_GRASS_MATERIAL = preload("res://systems/grass/materials/short_grass.tres")
const TALL_GRASS_MATERIAL = preload("res://systems/grass/materials/tall_grass.tres")

var _chunks_container: Node3D
var _dirty: bool = false

func _ready() -> void:
	# Create container for chunks
	if not _chunks_container:
		_chunks_container = Node3D.new()
		_chunks_container.name = "GrassChunks"
		add_child(_chunks_container)
	
	# Listen for children changes to re-populate
	child_entered_tree.connect(func(_node): if _node != _chunks_container: mark_dirty())
	child_exiting_tree.connect(func(_node): if _node != _chunks_container: mark_dirty())
	
	_update_material_parameters()
	mark_dirty()



func _update_material_parameters() -> void:
	if SHORT_GRASS_MATERIAL:
		SHORT_GRASS_MATERIAL.set_shader_parameter("animation_distance", animation_distance)
	if TALL_GRASS_MATERIAL:
		TALL_GRASS_MATERIAL.set_shader_parameter("animation_distance", animation_distance)

func mark_dirty() -> void:
	if _dirty: return
	_dirty = true
	call_deferred("_update_grass_deferred")

func _update_grass_deferred() -> void:
	if not _dirty: return
	_dirty = false
	populate_grass()

func populate_grass() -> void:
	if not is_inside_tree():
		return
		
	# Create container if missing (e.g. tool reload)
	if not _chunks_container or not is_instance_valid(_chunks_container):
		var existing = get_node_or_null("GrassChunks")
		if existing:
			_chunks_container = existing
		else:
			_chunks_container = Node3D.new()
			_chunks_container.name = "GrassChunks"
			add_child(_chunks_container)

	# Clear existing chunks
	for child in _chunks_container.get_children():
		child.queue_free()
	
	var areas_data = [] 
	
	# Collect spawn areas
	for child in get_children():
		if child == _chunks_container: continue 
		
		if child is Area3D:
			for grandchild in child.get_children():
				if grandchild is CollisionShape3D and grandchild.shape is BoxShape3D:
					var shape = grandchild.shape as BoxShape3D
					var size = shape.size
					var area_xz = size.x * size.z
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
	
	# We need to transform global points to local space of the grass system
	var my_global_inverse = global_transform.affine_inverse()
	
	# Use default noise if not assigned
	var noise = tall_grass_noise
	if not noise:
		noise = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_PERLIN
		noise.frequency = 0.5
		noise.seed = 1234
	
	var mask_data: PackedByteArray
	var mask_width: int = 0
	var mask_height: int = 0
	
	if spawn_mask:
		var img = spawn_mask.get_image()
		if img and not img.is_empty():
			# Convert to L8 (Grayscale) for 1 byte per pixel access
			# We duplicate to avoid modifying the original resource if it's shared/cached
			img = img.duplicate() 
			
			if img.is_compressed():
				img.decompress()
				
			img.convert(Image.FORMAT_L8)
			mask_width = img.get_width()
			mask_height = img.get_height()
			mask_data = img.get_data()
	
	# Process each area independently (Chunking)
	for data in areas_data:
		var count = data["count"]
		var size = data["size"]
		var shape_transform = data["transform"]
		
		# Buckets for chunking: key (Vector2i) -> Array of Transform3D
		var chunk_short_buckets = {}
		var chunk_tall_buckets = {}
		
		for i in range(count):
			var rx = rng.randf_range(-size.x / 2.0, size.x / 2.0)
			var rz = rng.randf_range(-size.z / 2.0, size.z / 2.0)
			var ry = 0.0
			
			# Optimization: Check directly against byte array
			if not mask_data.is_empty():
				var u = (rx / size.x) + 0.5
				var v = (rz / size.z) + 0.5
				
				# Clamp UVs
				if u < 0.0: u = 0.0
				elif u > 1.0: u = 1.0
				if v < 0.0: v = 0.0
				elif v > 1.0: v = 1.0
				
				var pixel_x = int(u * (mask_width - 1))
				var pixel_y = int(v * (mask_height - 1))
				
				if pixel_x >= 0 and pixel_x < mask_width and pixel_y >= 0 and pixel_y < mask_height:
					# Access raw byte directly. 0-255.
					var idx = pixel_y * mask_width + pixel_x
					if idx < mask_data.size():
						var pixel_val = mask_data[idx]
						# Optimization: Integer comparison avoids float division
						# rng.randf() is 0.0-1.0. 
						# integer rejection: check if random byte < pixel_val
						if (rng.randi() % 256) < pixel_val:
							continue
			
			# Logic Fix: Instances should be local to the chunk (Area), not the system.
			# The MultiMeshInstance3D will be placed at the Area's transform.
			# So we use point_in_shape directly (which is local to the Area).
			var point_local = Vector3(rx, ry, rz)
			
			# Note: We still need world pos for Noise sampling
			var point_world = shape_transform * point_local
			
			point_local.y += 0.5 
			
			var rotation_y = deg_to_rad(uniform_rotation_degrees)
			if random_rotation:
				rotation_y = rng.randf_range(0, TAU)
			
			var basis = Basis(Vector3.UP, rotation_y)
			var transform = Transform3D(basis, point_local)
			
			# Bucket key based on grid
			var bucket_x = floor(rx / chunk_size)
			var bucket_z = floor(rz / chunk_size)
			var bucket_key = Vector2i(bucket_x, bucket_z)
			
			# Decide if tall or short
			var noise_val = noise.get_noise_2d(point_world.x, point_world.z)
			if noise_val > tall_grass_threshold:
				if not chunk_tall_buckets.has(bucket_key):
					chunk_tall_buckets[bucket_key] = []
				chunk_tall_buckets[bucket_key].append(transform)
			else:
				if not chunk_short_buckets.has(bucket_key):
					chunk_short_buckets[bucket_key] = []
				chunk_short_buckets[bucket_key].append(transform)

		# Create meshes for short grass chunks
		for key in chunk_short_buckets.keys():
			var instances = chunk_short_buckets[key]
			if instances.is_empty(): continue
			
			var mm = MultiMeshInstance3D.new()
			mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			mm.visibility_range_end = view_distance
			mm.visibility_range_end_margin = 10.0
			mm.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			
			mm.multimesh = MultiMesh.new()
			mm.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			mm.multimesh.use_colors = true
			mm.multimesh.mesh = GRASS_MESH
			mm.material_override = SHORT_GRASS_MATERIAL
			mm.name = "Chunk_Short_%d_%d" % [key.x, key.y]
			_chunks_container.add_child(mm)
			
			mm.global_transform = shape_transform
			
			mm.multimesh.instance_count = instances.size()
			for i in range(instances.size()):
				mm.multimesh.set_instance_transform(i, instances[i])
				
		# Create meshes for tall grass chunks
		for key in chunk_tall_buckets.keys():
			var instances = chunk_tall_buckets[key]
			if instances.is_empty(): continue
			
			var mm = MultiMeshInstance3D.new()
			mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			mm.visibility_range_end = view_distance
			mm.visibility_range_end_margin = 10.0
			mm.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			
			mm.multimesh = MultiMesh.new()
			mm.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			mm.multimesh.use_colors = true
			mm.multimesh.mesh = GRASS_MESH
			mm.material_override = TALL_GRASS_MATERIAL
			mm.name = "Chunk_Tall_%d_%d" % [key.x, key.y]
			_chunks_container.add_child(mm)
			
			mm.global_transform = shape_transform
			
			mm.multimesh.instance_count = instances.size()
			for i in range(instances.size()):
				mm.multimesh.set_instance_transform(i, instances[i])
