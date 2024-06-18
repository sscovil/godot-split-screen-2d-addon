class_name Example
extends Node2D

const PlayerAvatar = Player.PlayerAvatar

var PlayerScene: PackedScene = preload("res://example/players/player.tscn")

@onready var background: ColorRect = $Background
@onready var split_screen: SplitScreen2D


func _ready():
	split_screen = $SplitScreen2D  # Assign this value here, so Example2 can extend this class.
	_connect_signals()


func _unhandled_key_input(event: InputEvent) -> void:
	if _is_action_just_pressed(event, "change_border_color"):
		change_background_color()
	elif _is_action_just_pressed(event, "add_player"):
		add_player()
	elif _is_action_just_pressed(event, "remove_player"):
		remove_player()


func add_player() -> void:
	var player: Player = PlayerScene.instantiate()
	player.player_id = _get_random_player_id()  # This determines which input actions are used.
	player.avatar = _get_random_player_avatar()  # This determines which sprite is used.
	player.position += _get_random_offset()  # This spawns the player in a unique position.
	
	if !split_screen.add_player(player):  ## The add_player() method returns false if player is not added.
		player.queue_free()  # If the player was not added to the scene tree, free it from memory.


func change_background_color() -> void:
	var color = _get_random_color()
	background.set_color(color)


func remove_player() -> void:
	var player: Player = split_screen.players[-1]
	split_screen.remove_player(player)


func _connect_signals() -> void:
	split_screen.max_players_reached.connect(_on_max_players_reached)
	split_screen.min_players_reached.connect(_on_max_players_reached)
	split_screen.player_added.connect(_on_player_added)
	split_screen.player_removed.connect(_on_player_removed)
	split_screen.split_screen_rebuilt.connect(_on_split_screen_rebuilt)


func _get_random_color() -> Color:
	return Color(randf(), randf(), randf(), 1.0)


func _get_random_offset() -> Vector2:
	var x: float = randf_range(1.0, 100.0)
	var y: float = randf_range(1.0, 30.0)
	
	return Vector2(x, y)


func _get_random_player_avatar() -> PlayerAvatar:
	return randi_range(0, 2) as PlayerAvatar


func _get_random_player_id() -> String:
	return ["p1", "p2", "p3", "p4"].pick_random()


func _is_action_just_pressed(event: InputEvent, action: StringName) -> bool:
	return event.is_action(action) and Input.is_action_just_pressed(action)


func _on_max_players_reached(player_count):
	var verb = "exceeded" if player_count > split_screen.max_players else "reached"
	print("Max players %s: %d" % [verb, player_count])


func _on_min_players_reached(player_count):
	var verb = "exceeded" if player_count < split_screen.min_players else "reached"
	print("Min players %s: %d" % [verb, player_count])


func _on_player_added(player):
	print("Player added: %s" % player.player_id)


func _on_player_removed(player):
	print("Player removed: %s" % player.player_id)


func _on_split_screen_rebuilt(reason: SplitScreen2D.RebuildReason):
	var trigger: String
	
	# Resize background node when splitscreen is rebuilt.
	background.set_size(split_screen.screen_size)
	
	match reason:
		SplitScreen2D.RebuildReason.PLAYER_ADDED:
			trigger = "player added"
		
		SplitScreen2D.RebuildReason.PLAYER_REMOVED:
			trigger = "player removed"
		
		SplitScreen2D.RebuildReason.SCREEN_SIZE_CHANGED:
			trigger = "screen size changed"
		
		_:
			trigger = "external request"
	
	print("Split screen rebuilt after %s." % trigger)
