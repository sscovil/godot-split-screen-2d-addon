class_name SplitScreen2D
extends Node2D

const MIN_PLAYERS: int = 1
const MAX_PLAYERS: int = 8

@export var play_area: Node2D
@export_range(MIN_PLAYERS, MAX_PLAYERS) var min_players: int = MIN_PLAYERS
@export_range(MIN_PLAYERS, MAX_PLAYERS) var max_players: int = MAX_PLAYERS

@export_group("Performance Optimization")
@export var rebuild_when_player_added: bool = true
@export var rebuild_when_player_removed: bool = true
@export var rebuild_when_screen_resized: bool = true

var screen_size: Vector2: get = get_screen_size

var cameras: Array[Camera2D] = []
var players: Array[Node2D] = []
var viewports: Array[SubViewport] = []
var viewport_container: BoxContainer


func _ready() -> void:
	_auto_detect_player_nodes()
	_build()
	_connect_signals()


func _on_screen_size_changed() -> void:
	if rebuild_when_screen_resized:
		rebuild()


func add_player(player: Node2D) -> void:
	if players.size() >= max_players:
		var hint: String = "Adjust max_players setting to allow more than %d." % max_players
		if max_players >= MAX_PLAYERS:
			hint = "Maximum number of players is %d." % MAX_PLAYERS
		push_warning("Cannot add player. %s" % hint)
		return
	
	players.append(player)
	
	if rebuild_when_player_added:
		rebuild()


func get_screen_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func rebuild() -> void:
	_clear_viewport_container()
	_build()


func remove_player(player: Node2D, should_queue_free: bool = true) -> void:
	if players.size() <= min_players or player not in players:
		var hint: String = "Adjust min_players setting to allow fewer than %d." % min_players
		if max_players >= MIN_PLAYERS:
			hint = "Minimum number of players is %d." % MIN_PLAYERS
		push_warning("Cannot remove player. %s" % hint)
		return
	
	players.pop_at(players.find(player))
	
	if should_queue_free:
		player.queue_free()
	
	if rebuild_when_player_removed:
		rebuild()


func _auto_detect_player_nodes() -> void:
	for child in get_children():
		if players.size() >= max_players:
			break  # Stop adding players.
		
		if child == play_area:
			continue  # Ignore this node.
		
		if is_instance_of(child, Node2D):
			players.append(child)  # Assume this node is a player.


func _build() -> void:
	var player_count: int = players.size()
	
	match player_count:
		1, 2:
			viewport_container = _build_1x(player_count)
		3, 4:
			viewport_container = _build_2x2()
		5, 6:
			viewport_container = _build_3x2()
		7, 8:
			viewport_container = _build_4x4()
	
	viewport_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	add_child(viewport_container)
	_build_level()


func _build_1x(viewport_count: int, size: Vector2 = screen_size) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	
	for i in range(viewport_count):
		var viewport_size := Vector2(size.x / viewport_count, size.y)
		var viewport := _build_viewport(viewport_size)
		hbox.add_child(viewport)
	
	return hbox


func _build_2x2(size: Vector2 = screen_size) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	var row_size := Vector2(size.x, size.y / 2)
	
	vbox.add_child(_build_1x(2, row_size))
	vbox.add_child(_build_1x(2, row_size))
	
	return vbox


func _build_3x2(size: Vector2 = screen_size) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	var row_size := Vector2(size.x, size.y / 2)
	
	vbox.add_child(_build_1x(3, row_size))
	vbox.add_child(_build_1x(3, row_size))
	
	return vbox


func _build_4x4(size: Vector2 = screen_size) -> BoxContainer:
	var vbox := VBoxContainer.new()
	var row_size := Vector2(size.x, size.y / 2)
	
	vbox.add_child(_build_2x2(row_size))
	vbox.add_child(_build_2x2(row_size))
	
	return vbox


func _build_level() -> void:
	var world_2d: World2D
	
	play_area.reparent(viewports[0])
	
	for i in range(players.size()):
		var player := players[i]
		var camera := cameras[i]
		var viewport := viewports[i]
		var remote_transform := RemoteTransform2D.new()
		
		remote_transform.set_remote_node(camera.get_path())
		player.add_child(remote_transform)
		player.reparent(play_area)
		
		if i == 0:
			world_2d = viewport.get_world_2d()
		else:
			viewport.set_world_2d(world_2d)


func _build_viewport(size: Vector2) -> SubViewportContainer:
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
