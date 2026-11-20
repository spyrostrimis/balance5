@tool
class_name DeveloperBuild
extends Resource

@export var listed := true
@export var section := "Canyon builds"
@export var title: String
@export var summary: String
@export_file("*.tscn") var scene_path: String
@export var credit: String
## Build time in UTC (YYYY-MM-DD HH:MM[:SS]). Optional for newly registered scenes.
@export var built_utc: String
## Publication time in UTC (YYYY-MM-DD HH:MM). Leave blank for a local study.
@export var milestone_utc: String
@export_enum("Play", "View") var action: String = "Play"


func is_available() -> bool:
	return listed and not scene_path.is_empty() and ResourceLoader.exists(scene_path, "PackedScene")


func build_time(packaged_time: int = 0) -> int:
	var date := built_utc if not built_utc.is_empty() else milestone_utc
	if not date.is_empty():
		# Existing catalog dates often omit seconds. Godot's parser requires them.
		if date.length() == 16:
			date += ":00"
		return Time.get_unix_time_from_datetime_string(date)
	if packaged_time > 0:
		return packaged_time
	return FileAccess.get_modified_time(scene_path)
