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

## Used to indicate wheter `rebuild()` was called after adding or removing a player, resizing the
## screen, or from an external script.
enum RebuildReason {
	EXTERNAL_REQUEST,
	PLAYER_ADDED,
	PLAYER_REMOVED,
	SCREEN_SIZE_CHANGED,
}

## Default delay (in seconds) before rebuilding the `SplitScreen2D` tree, recommended to avoid
## a performance hit when calling the `rebuild()` too many times in rapid succession (i.e. when
## the window is being resized).
const DEFAULT_REBUILD_DELAY: float = 0.2

## Minimum number of player screens supported by this plugin.
const MIN_PLAYERS: int = 1

## Maximum number of player screens supported by this plugin.
const MAX_PLAYERS: int = 8

## One child node must be designated as the play area. This will be reparented and become a child
## node of the primary viewport. Typically, this is a `TileMap` (or an instance of a scene that
## contains a `TileMap`), but it can be of any type derived from `Node2D`.
@export var play_area: Node2D

## The minimum number of player screens intended to be displayed; default is 1.
@export_range(MIN_PLAYERS, MAX_PLAYERS) var min_players: int = MIN_PLAYERS

## The maximum number of player screens allowed; default is 8.
@export_range(MIN_PLAYERS, MAX_PLAYERS) var max_players: int = MAX_PLAYERS

## If set to `true`, each viewport will have a transparent background (default value is `false`).
@export var transparent_background: bool = false

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
@export var rebuild_delay: float = DEFAULT_REBUILD_DELAY

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

## Used to determine if `rebuild()` has already been called within the `rebuild_delay` period.
var _is_rebuilding: bool = false


## When added to the scene tree, populate the `players` array with any child nodes that are not the
## `play_area` node. Then, build the `SplitScreen2D` tree and connect signals to the appropriate
## event handlers.
func _ready() -> void:
	_auto_detect_player_nodes()
	_build()
	_connect_signals()


## Create a new `SplitScreen2D` instance from a `SplitScreen2DConfig` object. This is a static
## method that can be called from any script using: `SplitScreen2D.from_config(config)`.
static func from_config(config: SplitScreen2DConfig) -> SplitScreen2D:
	var split_screen = SplitScreen2D.new()
	
	for key in config.keys():
		split_screen.set(key, config.get(key))
	
	split_screen.add_child(config.play_area)
	
	return split_screen


## Add a player to the `players` array, and emit the `player_added` signal. If the maximum number
## of players has been reached, emit the `max_players_reached` signal and return without adding
## the player. If the minimum number of players has been reached, emit the `min_players_reached`
## signal. If `rebuild_when_player_added` is `true`, call `rebuild()` after adding the player.
func add_player(player: Node2D) -> void:
	if players.size() >= max_players:
		var hint: String = "Adjust max_players setting to allow more than %d." % max_players
		if max_players >= MAX_PLAYERS:
			hint = "Maximum number of players is %d." % MAX_PLAYERS
		push_warning("Cannot add player. %s" % hint)
		return

	# Add the player to the players array so it can be accessed later.
	players.append(player)

	# Emit the player_added signal.
	player_added.emit(player)

	# If the minimum number of players has been reached, emit the min_players_reached signal.
	if players.size() <= min_players:
		min_players_reached.emit(players.size())

	# Rebuild the SplitScreen2D tree if configured to do so.
	if rebuild_when_player_added:
		rebuild(RebuildReason.PLAYER_ADDED)


## Get the size of the screen, which is equivalent to `get_viewport().get_visible_rect().size`.
func get_screen_size() -> Vector2:
	return get_viewport().get_visible_rect().size


## Rebuild the `SplitScreen2D` tree after a delay of `rebuild_delay` seconds. This method is used
## to consolidate multiple calls to `rebuild()` into a single call after the delay. If the tree is
## already being rebuilt, or if the `SplitScreen2D` node is not inside the scene tree, return
## without rebuilding the tree.
func rebuild(reason: RebuildReason = RebuildReason.EXTERNAL_REQUEST) -> void:
	if _is_rebuilding or !is_inside_tree():
		return

	# Ensure the tree is only rebuilt once after the configured delay time (in seconds).
	_is_rebuilding = true
	await get_tree().create_timer(rebuild_delay).timeout
	_is_rebuilding = false

	# Clear the viewport container and rebuild the SplitScreen2D tree.
	_clear_viewport_container()
	_build()

	# Emit the split_screen_rebuilt signal.
	split_screen_rebuilt.emit(reason)


## Remove a player from the `players` array, and emit the `player_removed` signal. If the
## minimum number of players has been reached, emit the `min_players_reached` signal. If
## `rebuild_when_player_removed` is `true`, call `rebuild()` after removing the player.
func remove_player(player: Node2D, should_queue_free: bool = true) -> void:
	if players.size() <= min_players or player not in players:
		var hint: String = "Adjust min_players setting to allow fewer than %d." % min_players
		if max_players >= MIN_PLAYERS:
			hint = "Minimum number of players is %d." % MIN_PLAYERS
		push_warning("Cannot remove player. %s" % hint)
		return

	# Remove the player from the players array.
	players.pop_at(players.find(player))

	# Emit the player_removed signal.
	player_removed.emit(player)

	# If the minimum number of players has been reached, emit the min_players_reached signal.
	if players.size() >= max_players:
		max_players_reached.emit(players.size())

	# Release the player node from memory, if `should_queue_free` parameter is `true` (default).
	if should_queue_free:
		player.queue_free()

	# Rebuild the SplitScreen2D tree if configured to do so.
	if rebuild_when_player_removed:
		rebuild(RebuildReason.PLAYER_REMOVED)


## Automatically detect child nodes that are not the `play_area` node, and add them to the
## `players` array. If the maximum number of players has been reached, emit the
## `max_players_reached` signal and stop adding players.
func _auto_detect_player_nodes() -> void:
	for child in get_children():
		if players.size() >= max_players:
			max_players_reached.emit(players.size())
			break  # Stop adding players.
		
		if child == play_area:
			continue  # Ignore this node.
		
		if is_instance_of(child, Node2D) and child not in players:
			players.append(child)  # Assume this node is a player.


## Build the `SplitScreen2D` tree based on the number of players. If there is only one
## player, the viewport container will contain a single viewport. If there are multiple
## players, `_build_multiplayer()` will be called to create a split-screen layout.
func _build() -> void:
	if players.size() > 1:
		return _build_multiplayer()

	# Create a single viewport for one player, and add it to the viewport container.
	viewport_container = BoxContainer.new()
	viewport_container.add_child(_build_viewport(screen_size))

	# Add the viewport container to the scene tree.
	add_child(viewport_container)

	# Add the play area to the first viewport.
	_build_play_area()


## Build the split-screen layout for multiple players. The number of players is divided into two
## groups: the top half and the bottom half. Each group will have its own `BoxContainer` with
## viewports for each player. If the number of players is odd, the bottom half will have one more
## player than the top half. The `play_area` node will be reparented to the first viewport, and
## each player will be reparented to the `play_area` node.
func _build_multiplayer() -> void:
	var player_count: int = players.size()

	# Create containers to hold the viewports for the top and bottom halves of the screen.
	var top := BoxContainer.new()
	var top_player_count: int = floor(player_count / 2)
	var top_size := Vector2(screen_size.x / top_player_count, screen_size.y / 2)

	# If the number of players is odd, the bottom half will have one more player than the top.
	var bottom := BoxContainer.new()
	var bottom_player_count: int = top_player_count + (player_count % 2)
	var bottom_size := Vector2(screen_size.x / bottom_player_count, screen_size.y / 2)

	# Set the orientation of the containers to horizontal, so the viewports are side by side.
	top.set_vertical(false)
	bottom.set_vertical(false)

	# Add viewports to the top container.
	for i in range(top_player_count):
		top.add_child(_build_viewport(top_size))

	# Add viewports to the bottom container.
	for i in range(bottom_player_count):
		bottom.add_child(_build_viewport(bottom_size))

	# Add the top and bottom containers to the viewport container.
	viewport_container = BoxContainer.new()
	viewport_container.add_child(top)
	viewport_container.add_child(bottom)
	viewport_container.set_vertical(true)

	# Add the viewport container to the scene tree.
	add_child(viewport_container)

	# Add the play area to the first viewport.
	_build_play_area()


## Build the play area by reparenting the `play_area` node to the first viewport, and
## reparenting each player to the `play_area` node. Set the `World2D` node of the first
## viewport as the `World2D` node for all viewports, so that all players share the same
## world coordinates and physics space.
func _build_play_area() -> void:
	var world_2d: World2D

	# Reparent the play area to the first viewport.
	play_area.reparent(viewports[0])

	# Reparent each player to the play area.
	for i in range(players.size()):
		var player := players[i]
		var camera := cameras[i]
		var viewport := viewports[i]
		var remote_transform := RemoteTransform2D.new()

		# Make the camera follow the player.
		remote_transform.set_remote_node(camera.get_path())
		player.add_child(remote_transform)

		# Reparent the player to the play area.
		if player.get_parent():
			player.reparent(play_area)
		else:
			# Cannot reparent a node that has no parent.
			play_area.add_child(player)

		# Set the `World2D` node for all viewports to that of the first viewport.
		if i == 0:
			world_2d = viewport.get_world_2d()
		else:
			viewport.set_world_2d(world_2d)


## Create a new `SubViewportContainer` with a `SubViewport` and `Camera2D` node. The
## `SubViewport` will have the specified size, and the `Camera2D` will be added to the
## `SubViewport`. The `SubViewport` will be added to the `SubViewportContainer`, and the
## `SubViewportContainer` will be returned.
func _build_viewport(size: Vector2 = screen_size) -> SubViewportContainer:
	var container := SubViewportContainer.new()
	var viewport := SubViewport.new()
	var camera := Camera2D.new()

	# Add the camera to the viewport.
	container.add_child(viewport)

	# Make the container expand to fill the space allocated to it.
	container.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Add the camera to the viewport.
	viewport.add_child(camera)

	# Configure the viewport.
	viewport.set_disable_3d(true)
	viewport.set_size(size)
	viewport.set_update_mode(SubViewport.UPDATE_ALWAYS)
	viewport.set_transparent_background(transparent_background)

	# Allow the viewport to receive input events.
	viewport.set_handle_input_locally(false)

	# Add the viewport and camera to the arrays, so they can be accessed later.
	cameras.append(camera)
	viewports.append(viewport)
	
	return container


## Clear the viewport container and reparent the `play_area` node to `SplitScreen2D`.
func _clear_viewport_container() -> void:
	if not viewport_container:
		push_warning("Cannot clear viewport container before it is defined.")
		return

	# Reparent the play area to the SplitScreen2D node.
	play_area.reparent(self)

	# Clear the arrays of viewports and cameras.
	cameras = []
	viewports = []

	# Remove the viewport container from the scene tree.
	viewport_container.queue_free()


## Connect signals to the appropriate event handlers.
func _connect_signals() -> void:
	# Handle changes to the screen size.
	get_viewport().size_changed.connect(_on_screen_size_changed)

	# Handle changes to the child nodes of SplitScreen2D.
	self.child_entered_tree.connect(_on_child_entered_tree)
	self.child_exiting_tree.connect(_on_child_exiting_tree)


## Event handler for when a child node enters the scene tree. If the child node is the
## `play_area`, return without adding it to the `players` array. Otherwise, if the child
## node is a `Node2D` and not already in the `players` array, add it as a new player.
func _on_child_entered_tree(node: Node) -> void:
	if node == play_area:
		return
	
	if node in get_children() and is_instance_of(node, Node2D) and node not in players:
		# Assume this node is a new player and add it.
		add_player(node)


## Event handler for when a child node exits the scene tree. If the child node is the
## `play_area`, return without removing it from the `players` array. Otherwise, if the
## child node is a `Node2D` and in the `players` array, remove it as a player.
func _on_child_exiting_tree(node: Node) -> void:
	if node == play_area:
		return
	
	if node in get_children() and is_instance_of(node, Node2D) and node in players:
		# Remove this player node, but don't call queue_free() since it's already exiting.
		remove_player(node, false)


## Event handler for when the screen size changes. If `rebuild_when_screen_resized` is `true`,
## call `rebuild()` with the `SCREEN_SIZE_CHANGED` reason.
func _on_screen_size_changed() -> void:
	if rebuild_when_screen_resized:
		rebuild(RebuildReason.SCREEN_SIZE_CHANGED)
