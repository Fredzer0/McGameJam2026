extends Node

func _ready():
	print("Conversion script started.")
	var source_path = "res://levels/environement_village_v_02.tscn"
	var target_path = "res://levels/environement_village_v_02.scn"
	# Use user:// for writing log
	var log_path = "user://conversion_log.txt"
	
	var file = FileAccess.open(log_path, FileAccess.WRITE)
	if file:
		file.store_line("Starting conversion script at " + Time.get_datetime_string_from_system())
		file.store_line("Source: " + source_path)
	else:
		print("Error: Could not open log file at " + log_path)

	if not FileAccess.file_exists(source_path):
		var msg = "Error: Source file does not exist!"
		print(msg)
		if file: file.store_line(msg)
		cleanup(file, 1)
		return

	# Load the scene
	var scene = load(source_path)
	if scene == null:
		var msg = "Error: Could not load scene at " + source_path
		print(msg)
		if file: file.store_line(msg)
		cleanup(file, 1)
		return
	
	if file: file.store_line("Scene loaded successfully.")
	print("Scene loaded successfully.")

	# Save as binary
	var error = ResourceSaver.save(scene, target_path)
	if error != OK:
		var msg = "Error saving scene: " + str(error)
		print(msg)
		if file: file.store_line(msg)
		cleanup(file, 1)
	else:
		var msg = "Successfully saved binary scene to: " + target_path
		print(msg)
		if file: file.store_line(msg)
		cleanup(file, 0)

func cleanup(file, exit_code):
	if file:
		file.close()
	print("Waiting before quit...")
	await get_tree().create_timer(2.0).timeout
	print("Quitting now.")
	get_tree().quit(exit_code)
