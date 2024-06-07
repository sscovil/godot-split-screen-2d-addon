<h1 align="center">
	SplitScreen2D
</h1>

<p align="center">
  Easily add a split-screen interface to your 2D game in Godot, with support for up to 8 players.
</p>

<p align="center">
  <a href="https://godotengine.org/download/" target="_blank" style="text-decoration:none"><img alt="Godot v4.2+" src="https://img.shields.io/badge/Godot-v4.2+-%23478cbf?logo=godot-engine&logoColor=cyian&labelColor=CFC9C8" /></a>
  <a href="https://github.com/sscovil/godot-split-screen-2d-addon/releases"  target="_blank" style="text-decoration:none"><img alt="Latest SplitScreen2D Release" src="https://img.shields.io/github/v/release/sscovil/godot-split-screen-2d-addon?include_prereleases&labelColor=CFC9C8"></a>
  <a href="https://github.com/sscovil/godot-split-screen-2d-addon/" target="_blank" style="text-decoration:none"><img alt="GitHub Repo Stars" src="https://img.shields.io/github/stars/sscovil/godot-split-screen-2d-addon"></a>
</p>

## Table of Contents

- [Pre-Release Notice](#pre-release-notice)
- [Version](#version)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Pre-Release Notice

This add-on is currently in a pre-release state. It has been tested and is working as expected, but it has not yet been
used in a production environment. Please report any issues you encounter.

## Version

SplitScreen2D **requires at least Godot 4.2**.

## Installation

Let's install SplitScreen2D into your Godot project:

- Download the `.zip` or `tar.gz` file for your desired SplitScreen2D version [here](https://github.com/sscovil/godot-split-screen-2d-addon/releases).
- Extract the `addons` folder from this file.
- Move the `addons` folder to your Godot project folder.

Now, let's verify you have correctly installed SplitScreen2D:

- You have this folder path `res://addons/split_screen_2d`.
- Head to `Project > Project Settings`.
- Click the `Plugins` tab.
- Tick the `enabled` button next to SplitScreen2D.
- Restart Godot.

## Usage

To get started, add a `SplitScreen2D` node to your scene tree. Then, add a node that represents your 2D play area,
as well as any nodes that represents your players, as children of the `SplitScreen2D` node in the scene tree.

![Example Scene Tree](./screenshots/screenshot_04.png)

Typically, the play area will be a `TileMap` (or an instance of a scene containing a `TileMap`); and players will be
`CharacterBody2D` instances, but that is not required. They can be of any node type that is derived from `Node2D`.

Finally, you'll need to configure the `SplitScreen2D` by assigning it a `Play Area`, as described in the
[Configuration](#configuration) section below.

## Configuration

Configure the `SplitScreen2D` node by selecting it in the scene tree and assigning the `Play Area`, `Min Players`, and
`Max Players` properties in the inspector. 

![Example Configuration](./screenshots/screenshot_05.png)

Alternatively, you can set these properties in code:

```gdscript
class_name Example
extends Node2D

@onready var split_screen_2d: SplitScreen2D = $SplitScreen2D
@onready var level: TileMap = $SplitScreen2D/TileMap

func _ready():
	# The play area can be any Node2D that is a child of SplitScreen2D, such as a TileMap.
	split_screen_2d.play_area = level
	# Set the minimum and maximum number of players (default is 1 to 8).
	split_screen_2d.min_players = 2
	split_screen_2d.max_players = 4
```

Likewise, you can add player nodes in code:

```gdscript
class_name Example
extends Node2D

@onready var split_screen_2d: SplitScreen2D = $SplitScreen2D

func _input():
	if Input.is_action_just_pressed("ui_accept"):
		# Assuming `Player` is a class you created for your players.
		var player = Player.new()
		# Code to configure player goes here.
		
		# Add the player to the split screen.
		split_screen_2d.add_player(player)
```

### Performance Optimization

The `SplitScreen2D` node will automatically rebuild its viewport tree whenever a player is added or removed, or when
the screen size changes. This should be fine, but if you need to disable it for performance reasons, you can adjust the
Performance Optimization settings.

![Performance Optimization](./screenshots/screenshot_06.png)

If you need to manually rebuild the viewport tree, you can call the `rebuild()` method:

```gdscript
class_name Example
extends Node2D

@onready var split_screen_2d: SplitScreen2D = $SplitScreen2D

func _ready():
	# Disable automatic rebuilding of the viewport tree.
	split_screen_2d.rebuild_when_player_added = false
	split_screen_2d.rebuild_when_player_removed = false
	split_screen_2d.rebuild_when_screen_resized = false

func add_player(new_player: Player):
	# Add the player to the split screen.
	split_screen_2d.add_player(new_player)
	# Rebuild the viewport tree.
	split_screen_2d.rebuild()

func remove_player(player: Player):
	# Set to true (default) if the player node should be deleted; otherwise, set to false.
	var should_queue_free: bool = false
	# Remove the player from the split screen.
	split_screen_2d.remove_player(player, should_queue_free)
	# Rebuild the viewport tree.
	split_screen_2d.rebuild()
	# Optionally, do something with the player node if you kept it.
	player.reparent(inactive_players)  # Assuming `inactive_players` is a Node2D in your scene.
```

Again, this should not be necessary for most projects, but it is available if you need it—or if you're  just a control
freak.

## Signals

The `SplitScreen2D` node emits the following signals:

- `max_players_reached(player_count: int)`: Emitted when the maximum number of players is reached or exceeded.
- `min_players_reached(player_count: int)`: Emitted when the minimum number of players is reached or exceeded.
- `player_added(player: Node2D)`: Emitted when a player is added to the split screen.
- `player_removed(player: Node2D)`: Emitted when a player is removed from the split screen.
- `split_screen_rebuilt(reason: RebuildReason)`: Emitted when the `SplitScreen2D` tree is rebuilt.

For an example of how to connect to these signals, see the [example project](./example/example.gd).

## Troubleshooting

### Play Area Is Not Visible

If your play area is not visible, ensure that it is a child of the `SplitScreen2D` node in the scene tree and that it
is assigned to the `Play Area` property in the inspector (or the `play_area` property in code).

### Players Are Not Visible

If your players are not visible, ensure that they are children of the `SplitScreen2D` node in the scene tree.

### Players Fly Off Screen

If your players fly off the screen, ensure that you have placed them in unique positions within the play area. This is
not an issue with SplitScreen2D, but it's easy to overlook when setting up your scene and is definitely a mistake that
was made while developing this add-on. 😆

### Unexpected Behavior With Players

One thing to be aware of is that, under the hood, SplitScreen2D will reparent the play area and player nodes to be
children of the primary viewport. This is necessary to achieve the split-screen effect, but in theory it could cause
issues if you are doing something unusual with your nodes. If you encounter unexpected behavior, try to simplify your
scene and isolate the issue.

### Split Screen Not Rebuilding On Player Add/Remove

Ensure that the `rebuild_when_player_added` and `rebuild_when_player_removed` properties are set to `true` (default) in
the inspector or in code.

### Split Screen Not Rebuilding On Screen Resize

Ensure that the `rebuild_when_screen_resized` property is set to `true` (default) in the inspector or in code.

### I Can't Change The Color Of Split Screen Borders

The split screen borders are not drawn; they are just transparent empty space between the viewports. You can place a
`ColorRect` node above the `SplitScreen2D` node in your scene tree to colorize to the spacers, as was done in the
[example project](./example/example.gd).

## License

This project is licensed under the terms of the [MIT license](https://github.com/sscovil/godot-split-screen-2d-addon/blob/main/LICENSE).