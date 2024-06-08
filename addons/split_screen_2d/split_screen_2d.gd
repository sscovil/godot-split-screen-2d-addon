class_name SplitScreen2D
extends Node2D

## Emitted when the maximum number of players has been reached or exceeded.
## 
## This signal is emitted _after_ the `player_added` signal, but before `split_screen_rebuilt`.
signal max_players_reached(player_count: int)

## Emitted when the minimum number of players has been reached or exceeded.
## 
## This signal is emitted _after_ the `player_removed` signal, but before `split_screen_rebuilt`
## and before `queue_free()` is called (if applicable).
signal min_players_reached(player_count: int)

## Emitted when a player has been added to the `players` list.
## 
## This signal is emitted _before_ the `player_added` and `split_screen_rebuilt` signals.
signal player_added(player: Node2D)

## Emitted when a player has been removed from the `players` list.
## 
## This signal is emitted _before_ the `player_added` and `split_screen_rebuilt` signals, and
## before `queue_free()` is called (if applicable).
signal player_removed(player: Node2D)

## Emitted when the `SplitScreen2D` tree is finished rebuilding. The `reason` parameter indicates
## wheter `rebuild()` was called after adding or removing a player, resizing the screen, or from
## an external script.
signal split_screen_rebuilt(reason: RebuildReason)

## Default delay (in seconds) before rebuilding the `SplitScreen2D` tree, recommended to avoid
## a performance hit when calling the `rebuild()` too many times in rapid succession (i.e. when
## the window is being resized).
const DEFAULT_REBUILD_DELAY: float = 0.2

## Minimum number of player screens supported by this plugin.
const MIN_PLAYERS: int = 1

## Maximum number of player screens supported by this plugin.
const MAX_PLAYERS: int = 8

## Used to indicate wheter `rebuild()` was called after adding or removing a player, resizing the
## screen, or from an external script.
enum RebuildReason {
	EXTERNAL_REQUEST,
	PLAYER_ADDED,
	PLAYER_REMOVED,
	SCREEN_SIZE_CHANGED,
}

## One child node must be designated as the play area. This will be reparented and become a child
## node of the primary viewport. Typically, this is a `TileMap` (or an instance of a scene that
## contains a `TileMap`), but it can be of any type derived from `Node2D`.
@export var play_area: Node2D

## The minimum number of player screens intended to be displayed; default is 1.
@export_range(MIN_PLAYERS, MAX_PLAYERS) var min_players: int = MIN_PLAYERS

## The maximum number of player screens allowed; default is 8.
@export_range(MIN_PLAYERS, MAX_PLAYERS) var max_players: int = MAX_PLAYERS

@export_group("Performance Optimization")

## If set to `true` (default), the `SplitScreen2D` tree will be rebuilt each time a new player is
## added.
@export var rebuild_when_player_added: bool = true

## If set to `true` (default), the `SplitScreen2D` tree will be rebuilt each time a player is
## removed.
@export var rebuild_when_player_removed: bool = true

## If set to `true` (default), the `SplitScreen2D` tree will be rebuilt each time the screen is
## resized, up to a maximum of once per `rebuild_delay` seconds.
@export var rebuild_when_screen_resized: bool = true

## Used to adjust the mandatory delay between calls to `rebuild()`; default is 0.2 seconds. Calls
## made during the delay will be consolidated into a single call after the delay.
@export var rebuild_deleay: float = DEFAULT_REBUILD_DELAY

## Calculated field that is equivalent to `get_viewport().get_visible_rect().size`.
var screen_size: Vector2: get = get_screen_size

## An array of `Camera2D` nodes, each corresponding to the player in `players` at the same index.
var cameras: Array[Camera2D] = []

## An array of nodes that represent each player. This list is populated with the child nodes of
## `SplitScreen2D` (excluding `play_area`), and is automatically updated when children are added or
## removed. 
var players: Array[Node2D] = []

## An array of `SubViewport` nodes, each corresponding to the player in `players` at the same index.
var viewports: Array[SubViewport] = []

## The outermost `HBoxContainer` or `VBoxContainer` that contains all of the viewports and cameras.
## This becomes the only child of `SplitScreen2D` after `_ready()` is called, because `play_area`
## is moved inside the primary viewport, and each of the player nodes are moved inside `play_area`.
var viewport_container: BoxContainer

## Used to determine if `rebuild()` has already been called within the `rebuild_deleay` period.
var _is_rebuilding: bool = false


func _ready() -> void:
	_auto_detect_player_nodes()
	_build()
	_connect_signals()


func add_player(player: Node2D) -> void:
	if players.size() >= max_players:
		var hint: String = "Adjust max_players setting to allow more than %d." % max_players
		if max_players >= MAX_PLAYERS:
			hint = "Maximum number of players is %d." % MAX_PLAYERS
		push_warning("Cannot add player. %s" % hint)
		return
	
	players.append(player)
	player_added.emit(player)
	
	if players.size() <= min_players:
		min_players_reached.emit(players.size())
	
	if rebuild_when_player_added:
		rebuild(RebuildReason.PLAYER_ADDED)


func get_screen_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func rebuild(reason: RebuildReason = RebuildReason.EXTERNAL_REQUEST) -> void:
	if _is_rebuilding:
		return
	
	_is_rebuilding = true
	await get_tree().create_timer(rebuild_deleay).timeout
	_is_rebuilding = false
	
	_clear_viewport_container()
	_build()
	
	split_screen_rebuilt.emit(reason)


func remove_player(player: Node2D, should_queue_free: bool = true) -> void:
	if players.size() <= min_players or player not in players:
		var hint: String = "Adjust min_players setting to allow fewer than %d." % min_players
		if max_players >= MIN_PLAYERS:
			hint = "Minimum number of players is %d." % MIN_PLAYERS
		push_warning("Cannot remove player. %s" % hint)
		return
	
	players.pop_at(players.find(player))
	player_removed.emit(player)
	
	if players.size() >= max_players:
		max_players_reached.emit(players.size())
	
	if should_queue_free:
		player.queue_free()
	
	if rebuild_when_player_removed:
		rebuild(RebuildReason.PLAYER_REMOVED)


func _auto_detect_player_nodes() -> void:
	for child in get_children():
		if players.size() >= max_players:
			max_players_reached.emit()
			break  # Stop adding players.
		
		if child == play_area:
			continue  # Ignore this node.
		
		if is_instance_of(child, Node2D) and child not in players:
			players.append(child)  # Assume this node is a player.


func _build() -> void:
	var player_count: int = players.size()
	
	viewport_container = BoxContainer.new()
	viewport_container.set_alignment(BoxContainer.ALIGNMENT_CENTER)
	
	if player_count == 1:
		viewport_container.add_child(_build_viewport(screen_size))
		viewport_container.set_vertical(true)
		
	elif player_count < 4:
		var size := Vector2(screen_size.x / player_count, screen_size.y)
		
		for i in range(player_count):
			viewport_container.add_child(_build_viewport(size))
		viewport_container.set_vertical(false)
		
	else:
		var top := BoxContainer.new()
		var bottom := BoxContainer.new()
		var top_half_player_count: int = floor(player_count / 2)
		var bottom_half_player_count: int = top_half_player_count + (player_count % 2)
		var top_size := Vector2(screen_size.x / top_half_player_count, screen_size.y / 2)
		var bottom_size := Vector2(screen_size.x / bottom_half_player_count, screen_size.y / 2)
		
		top.set_alignment(BoxContainer.ALIGNMENT_CENTER)
		top.set_vertical(false)
		
		bottom.set_alignment(BoxContainer.ALIGNMENT_CENTER)
		bottom.set_vertical(false)
		
		for i in range(top_half_player_count):
			top.add_child(_build_viewport(top_size))
		
		for i in range(bottom_half_player_count):
			bottom.add_child(_build_viewport(bottom_size))
		
		viewport_container.add_child(top)
		viewport_container.add_child(bottom)
		viewport_container.set_vertical(true)
	
	add_child(viewport_container)
	_build_play_area()


func _build_play_area() -> void:
	var world_2d: World2D
	
	play_area.reparent(viewports[0])
	
	for i in range(players.size()):
		var player := players[i]
		var camera := cameras[i]
		var viewport := viewports[i]
		var remote_transform := RemoteTransform2D.new()
		
		remote_transform.set_remote_node(camera.get_path())
		player.add_child(remote_transform)
		
		if player.get_parent():
			player.reparent(play_area)
		else:
			play_area.add_child(player)
		
		if i == 0:
			world_2d = viewport.get_world_2d()
		else:
			viewport.set_world_2d(world_2d)


func _build_viewport(size: Vector2 = screen_size) -> SubViewportContainer:
	var container := SubViewportContainer.new()
	var viewport := SubViewport.new()
	var camera := Camera2D.new()
	
	container.add_child(viewport)
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	viewport.add_child(camera)
	viewport.set_disable_3d(true)
	viewport.set_handle_input_locally(false)
	viewport.set_size(size)
	viewport.set_update_mode(SubViewport.UPDATE_ALWAYS)
	
	cameras.append(camera)
	viewports.append(viewport)
	
	return container


func _clear_viewport_container() -> void:
	if not viewport_container:
		push_warning("Cannot clear viewport container before it is defined.")
		return
	
	play_area.reparent(self)
	
	cameras = []
	viewports = []
	viewport_container.queue_free()


func _connect_signals() -> void:
	get_viewport().size_changed.connect(_on_screen_size_changed)
	self.child_entered_tree.connect(_on_child_entered_tree)
	self.child_exiting_tree.connect(_on_child_exiting_tree)


func _on_child_entered_tree(node: Node) -> void:
	if node == play_area:
		return
	
	if node in get_children() and is_instance_of(node, Node2D) and node not in players:
		# Assume this node is a new player and add it.
		add_player(node)


func _on_child_exiting_tree(node: Node) -> void:
	if node == play_area:
		return
	
	if node in get_children() and is_instance_of(node, Node2D) and node in players:
		# Remove this player node, but don't call queue_free() since it's already exiting.
		remove_player(node, false)


func _on_screen_size_changed() -> void:
	if rebuild_when_screen_resized:
		rebuild(RebuildReason.SCREEN_SIZE_CHANGED)
