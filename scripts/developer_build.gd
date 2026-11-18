class_name DeveloperBuild
extends Resource

@export var listed := true
@export var section := "Canyon builds"
@export var title: String
@export var summary: String
@export_file("*.tscn") var scene_path: String
@export var credit: String
@export var recorded_at: String
@export var action := "Play"


func is_available() -> bool:
	return listed and not scene_path.is_empty() and ResourceLoader.exists(scene_path, "PackedScene")
