class_name UnitStats
extends Resource
## One unit type's numbers, saved as a .tres file in scenes/rts/units/ and edited in the Inspector.
## Values are placeholders until balancing (docs/GAME_DESIGN.md §9). Ranges are in tiles:
## range 1 means "touching", including diagonally.

enum Faction { BLUE, RED }
enum Kind { TROOP, COMMANDER }

const FACTION_COLORS := {
	Faction.BLUE: Color(0.22, 0.45, 0.92),
	Faction.RED: Color(0.86, 0.2, 0.17),
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


func color() -> Color:
	return FACTION_COLORS[faction]


func damage_against(target: UnitStats) -> int:
	return maxi(1, attack - target.armour)
