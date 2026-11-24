class_name RtsVisualProfile
extends Resource
## Scene-local display and rendering policy for RTS maps (pixel 1x vs hd_painted 2x).
## Both profiles run on the exact same 32x32 logical tile grid (960x540 logical world view)
## without editing global project.godot settings. Window properties are snapshotted on entry
## and restored cleanly in _exit_tree().

const ID_PIXEL := "pixel"
const ID_HD_PAINTED := "hd_painted"
const LOGICAL_VIEW_SIZE := Vector2i(960, 540)
const HD_VIEW_SIZE := Vector2i(1920, 1080)

@export var id: String = ID_PIXEL
@export var display_name: String = "Pixel (1x · 960×540 integer)"
@export var logical_view_size: Vector2i = LOGICAL_VIEW_SIZE
@export var content_scale_size: Vector2i = LOGICAL_VIEW_SIZE
@export var density: float = 1.0
@export var integer_stretch: bool = true
@export var snap_pixels: bool = true
@export var canvas_texture_filter: CanvasItem.TextureFilter = CanvasItem.TEXTURE_FILTER_NEAREST
@export var soft_effects: bool = false
@export var atmosphere_enabled: bool = false


static func create_pixel() -> RtsVisualProfile:
	var p := RtsVisualProfile.new()
	p.id = ID_PIXEL
	p.display_name = "Pixel (1x · 960×540 integer)"
	p.logical_view_size = LOGICAL_VIEW_SIZE
	p.content_scale_size = LOGICAL_VIEW_SIZE
	p.density = 1.0
	p.integer_stretch = true
	p.snap_pixels = true
	p.canvas_texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.soft_effects = false
	p.atmosphere_enabled = false
	return p


static func create_hd_painted() -> RtsVisualProfile:
	var p := RtsVisualProfile.new()
	p.id = ID_HD_PAINTED
	p.display_name = "HD Painted (2x · 1920×1080 smooth)"
	p.logical_view_size = LOGICAL_VIEW_SIZE
	p.content_scale_size = HD_VIEW_SIZE
	p.density = 2.0
	p.integer_stretch = false
	p.snap_pixels = false
	p.canvas_texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	p.soft_effects = true
	p.atmosphere_enabled = true
	return p


static func by_id(profile_id: String) -> RtsVisualProfile:
	var clean := profile_id.strip_edges().to_lower()
	if clean == ID_HD_PAINTED or clean == "hd" or clean == "painted":
		return create_hd_painted()
	return create_pixel()


static func from_cmdline(default_id: String = ID_PIXEL) -> RtsVisualProfile:
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):
			return by_id(arg.trim_prefix("--profile="))
	return by_id(default_id)


func is_pixel() -> bool:
	return id == ID_PIXEL


func is_hd_painted() -> bool:
	return id == ID_HD_PAINTED


func toggled() -> RtsVisualProfile:
	return create_hd_painted() if is_pixel() else create_pixel()


static func capture_window_state(window: Window) -> Dictionary:
	if window == null:
		return {}
	return {
		"content_scale_mode": window.content_scale_mode,
		"content_scale_size": window.content_scale_size,
		"content_scale_aspect": window.content_scale_aspect,
		"content_scale_stretch": window.content_scale_stretch,
		"snap_2d_transforms_to_pixel": window.snap_2d_transforms_to_pixel,
		"snap_2d_vertices_to_pixel": window.snap_2d_vertices_to_pixel,
		"size": window.size,
		"size_touched": false,
	}


static func restore_window_state(window: Window, state: Dictionary) -> void:
	if window == null or state.is_empty():
		return
	window.content_scale_mode = state["content_scale_mode"]
	window.content_scale_size = state["content_scale_size"]
	window.content_scale_aspect = state["content_scale_aspect"]
	window.content_scale_stretch = state["content_scale_stretch"]
	window.snap_2d_transforms_to_pixel = state["snap_2d_transforms_to_pixel"]
	window.snap_2d_vertices_to_pixel = state["snap_2d_vertices_to_pixel"]
	if state.get("size_touched", false):
		window.size = state["size"]


func apply_to_window(window: Window) -> void:
	if window == null:
		return
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_size = content_scale_size
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.content_scale_stretch = (
		Window.CONTENT_SCALE_STRETCH_INTEGER if integer_stretch
		else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	)
	window.snap_2d_transforms_to_pixel = snap_pixels
	window.snap_2d_vertices_to_pixel = snap_pixels


func effective_scale_info(window: Window) -> Dictionary:
	if window == null:
		return {
			"window_size": LOGICAL_VIEW_SIZE,
			"viewport_size": Vector2(LOGICAL_VIEW_SIZE),
			"scale": Vector2.ONE,
			"art_pixel_scale": 1.0,
			"is_integer": true,
			"margin": Vector2.ZERO,
		}
	var win_size := window.size
	var vp_size := window.get_visible_rect().size
	var xform := window.get_final_transform()
	var sc := xform.get_scale()
	var rounded := roundf(sc.x)
	var is_int := absf(sc.x - rounded) < 0.005 and rounded >= 1.0
	return {
		"window_size": win_size,
		"viewport_size": vp_size,
		"scale": sc,
		"logical_pixel_scale": sc.x * density,
		"is_integer": is_int,
		"margin": xform.origin,
	}
