class_name Example2
extends Example

## Note that this class extends the Example class (res://example/example.gd).


func _ready():
	var config := SplitScreen2DConfig.new()
	config.play_area = load_level(1)
	config.max_players = 4
	
	split_screen = SplitScreen2D.from_config(config)
	
	var players = [
		load_player("p1", PlayerAvatar.ALIEN_A),
		load_player("p2", PlayerAvatar.ALIEN_B),
		load_player("p3", PlayerAvatar.ALIEN_C),
	]
	
	for player in players:
		split_screen.add_player(player)
	
	add_child(split_screen)
	
	_connect_signals()


func load_level(level_number: int) -> TileMap:
	var level = load("res://example/level.tscn").instantiate()
	
	return level


func load_player(player_id: String, avatar: PlayerAvatar) -> Player:
	var player = load("res://example/players/player.tscn").instantiate()
	
	player.player_id = player_id
	player.avatar = avatar
	player.position += _get_random_offset()  # This spawns the player in a unique position.
	
	return player
