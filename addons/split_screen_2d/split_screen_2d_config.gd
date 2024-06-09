class_name SplitScreen2DConfig
extends Node

const DEFAULT_REBUILD_DELAY: float = SplitScreen2D.DEFAULT_REBUILD_DELAY
const MIN_PLAYERS: int = SplitScreen2D.MIN_PLAYERS
const MAX_PLAYERS: int = SplitScreen2D.MAX_PLAYERS

@export var play_area: Node2D
@export_range(MIN_PLAYERS, MAX_PLAYERS) var min_players: int = MIN_PLAYERS
@export_range(MIN_PLAYERS, MAX_PLAYERS) var max_players: int = MAX_PLAYERS
@export var transparent_background: bool = false

@export_group("Performance Optimization")
@export var rebuild_when_player_added: bool = true
@export var rebuild_when_player_removed: bool = true
@export var rebuild_when_screen_resized: bool = true
@export var rebuild_delay: float = DEFAULT_REBUILD_DELAY


func keys() -> Array:
	var keys := get_property_list().map(_get_property_name)
	var invalid_keys := _get_invalid_keys()
	
	return keys.filter(func(p): return p not in invalid_keys)


func _get_invalid_keys() -> Array:
	var node_keys := _get_node_keys()
	
	return node_keys + [
		&"split_screen_2d_config.gd",
		&"Performance Optimization",
	]


func _get_node_keys() -> Array:
	return Node.new().get_property_list().map(_get_property_name)


func _get_property_name(property: Dictionary) -> StringName:
	return property.name
