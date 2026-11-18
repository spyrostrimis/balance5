@tool
extends Resource
## One module placed relative to the canyon route.

@export var label := ""
@export var scene: PackedScene
## World Z of the module origin.
@export var z := 0.0
## Signed distance from the route centre in metres. Negative is left of the walker.
@export var lateral := 0.0
@export var height := 0.0
## Turn with the route heading. Leave off for camera-facing sprites.
@export var align_to_route := true
@export var yaw_offset_deg := 0.0
@export var scale := Vector3.ONE
## Sprite modulate and flip. Ignored by non-sprite modules.
@export var tint := Color.WHITE
@export var flip_h := false
