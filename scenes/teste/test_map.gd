extends Node3D
class_name TestMap

@export var player_scene: PackedScene = preload("res://player/Player.tscn")
@export var camera_scene: PackedScene = preload("res://player/FollowCamera.tscn")
@export var spawn_point_path: NodePath = NodePath("SpawnPoint")

func _ready() -> void:
	# Locate the SpawnPoint marker in the scene.
	var spawn_point: Marker3D = get_node_or_null(spawn_point_path) as Marker3D
	if spawn_point == null:
		push_error("TestMap: Cannot find SpawnPoint at path %s" % spawn_point_path)
		return

	# Instantiate the Player
	var player_instance = player_scene.instantiate() as Player
	add_child(player_instance)
	player_instance.global_transform = spawn_point.global_transform

	# Instantiate the FollowCamera
	var camera_instance = camera_scene.instantiate() as FollowCamera
	add_child(camera_instance)
	# --- A MÁGICA ACONTECE AQUI ---
	# Como o mapa criou os dois, ele mesmo faz a conexão!
	player_instance.movement._follow_camera = camera_instance
	camera_instance._target = player_instance
