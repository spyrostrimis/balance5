extends Resource
## Sinusoidal canyon route shared by movement, camera, ground shader and module layout.
## The defaults reproduce the D4b curve, sin(z * 0.22) * 0.65.

@export var amplitude: float = 0.65
@export var frequency: float = 0.22
@export var phase: float = 0.0


func center_x(z: float) -> float:
	return amplitude * sin(z * frequency + phase)


## Slope of the chord across ±2 m, matching the D4b assembler's sampling.
func chord_slope(z: float) -> float:
	return (center_x(z + 2.0) - center_x(z - 2.0)) / 4.0


## Yaw that aligns a module's local Z axis with the route at z.
func heading(z: float) -> float:
	return atan(chord_slope(z))


func apply_to_ground(material: ShaderMaterial) -> void:
	material.set_shader_parameter("route_amplitude", amplitude)
	material.set_shader_parameter("route_frequency", frequency)
	material.set_shader_parameter("route_phase", phase)
