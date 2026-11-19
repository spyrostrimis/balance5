extends RefCounted
## Guard for generator scripts that overwrite committed scenes and resources.
## Their outputs are now baselines that other scenes inherit from or hand-edited files, so a casual
## rerun could silently break the comparison chain. Pass --force after `--` to run anyway:
##   Godot --path . --headless --script res://tools/godot/<tool>.gd -- --force


static func confirm(tree: SceneTree, outputs: PackedStringArray) -> bool:
	if "--force" in OS.get_cmdline_user_args():
		return true
	push_error("Refusing to overwrite %s.\nThese files are committed baselines. Rerun with `-- --force` if you really mean to regenerate them, then check every scene that inherits from them." % ", ".join(outputs))
	tree.quit(1)
	return false
