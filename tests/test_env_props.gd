@tool
extends SceneTree

func _init():
	var env = Environment.new()
	print("Environment has volumetric fog: ", "volumetric_fog_enabled" in env)
	var cam_attr = CameraAttributesPractical.new()
	print("CameraAttributesPractical dof_blur_far: ", "dof_blur_far_enabled" in cam_attr)
	print("CameraAttributesPractical dof_blur_near: ", "dof_blur_near_enabled" in cam_attr)
	quit(0)
