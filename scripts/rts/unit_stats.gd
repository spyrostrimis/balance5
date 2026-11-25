class_name UnitStats
extends Resource
## One unit type's numbers, saved as a .tres file in scenes/rts/units/ and edited in the Inspector.
## Values are placeholders until balancing (docs/GAME_DESIGN.md §9). Ranges are in tiles:
## range 1 means "touching", including diagonally.

enum Faction { BLUE, RED, GREEN, PALATINATE }
enum Kind { TROOP, COMMANDER }

const FACTION_COLORS := {
	Faction.BLUE: Color(0.22, 0.45, 0.92),
	Faction.RED: Color(0.86, 0.20, 0.17),
	Faction.GREEN: Color(0.22, 0.58, 0.27),
	Faction.PALATINATE: Color(0.53, 0.24, 0.68),
}

const FACTION_PALETTES := {
	Faction.BLUE: {
		"dark": Color(0.086, 0.165, 0.471),
		"mid": Color(0.180, 0.376, 0.871),
		"light": Color(0.510, 0.686, 1.000),
		"trim": Color(0.925, 0.894, 0.808),
		"emblem": Color(0.431, 0.941, 0.941),
	},
	Faction.RED: {
		"dark": Color(0.439, 0.086, 0.063),
		"mid": Color(0.800, 0.173, 0.125),
		"light": Color(1.000, 0.502, 0.408),
		"trim": Color(0.886, 0.667, 0.235),
		"emblem": Color(1.000, 0.871, 0.471),
	},
	Faction.GREEN: {
		"dark": Color(0.090, 0.271, 0.129),
		"mid": Color(0.200, 0.561, 0.259),
		"light": Color(0.522, 0.839, 0.459),
		"trim": Color(0.761, 0.639, 0.380),
		"emblem": Color(0.922, 0.780, 0.341),
	},
	Faction.PALATINATE: {
		"dark": Color(0.239, 0.102, 0.329),
		"mid": Color(0.510, 0.220, 0.659),
		"light": Color(0.820, 0.561, 0.961),
		"trim": Color(0.922, 0.890, 0.831),
		"emblem": Color(0.949, 0.878, 0.678),
	},
}

@export var display_name := "Trooper"
@export var faction: Faction = Faction.BLUE
@export var kind: Kind = Kind.TROOP
@export_group("Combat")
@export var max_health := 60
## Damage per hit before armour.
@export var attack := 12
## Taken off every hit received. A hit always does at least 1 damage.
@export var armour := 4
## How far this unit can hit, in tiles.
@export_range(1, 10) var attack_range := 1
## Seconds between hits.
@export var attack_cooldown := 1.0
## An idle unit goes after enemies this close, in tiles. Set it to the attack range to make
## units only shoot what they can already reach.
@export_range(1, 12) var guard_range := 5
@export_group("Movement")
## Tiles per second.
@export var move_speed := 2.5
@export_group("Look")
## Optional picture. Empty means the placeholder disc is drawn.
@export var sprite: Texture2D
## Optional 2x density sprite sheet for the "hd_painted" visual profile.
@export var sprite_hd: Texture2D
## Optional team-colour mask texture (R = team paint, G = shading value, B = trim/emblem).
@export var team_mask: Texture2D
## Optional 2x density team-colour mask texture for "hd_painted".
@export var team_mask_hd: Texture2D
## 1 = one picture, mirrored when moving left; 8 = a sheet with one column per facing
## (S, SW, W, NW, N, NE, E, SE), like the Balance4 tank.
@export_enum("1:1", "8:8") var sprite_directions: int = 1
## Rows of animation frames in the sheet (played while moving).
@export_range(1, 8) var sprite_frames := 1
## Vehicles leave tracks and dust; infantry leaves footprints and bobs as it walks.
@export var vehicle := false
## Draw scale of the sprite.
@export var sprite_scale := 1.0


func color() -> Color:
	return FACTION_COLORS.get(faction, FACTION_COLORS[Faction.BLUE])


func palette() -> Dictionary:
	return FACTION_PALETTES.get(faction, FACTION_PALETTES[Faction.BLUE])


func damage_against(target: UnitStats) -> int:
	return maxi(1, attack - target.armour)
