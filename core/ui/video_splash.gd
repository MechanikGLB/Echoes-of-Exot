extends CanvasLayer
# VideoSplash.gd

@export var video_files: Array[String] = [
	"res://Assets/intros/8c5efb7b-5385-46e5-ae39-1f412a8fa41d.ogv",
	"res://Assets/intros/Эхо1.ogv"
]

var current_video_index = 0
var is_skipping = false
@onready var video_player = $VideoStreamPlayer

func _ready():
	if video_files.is_empty():
		push_error("VideoSplash: No video files specified")
		transition_to_main_menu()
		return
	
	video_player.paused = false
	play_next_video()

func play_next_video():
	if current_video_index >= video_files.size():
		transition_to_main_menu()
		return
	
	var video_path = video_files[current_video_index]
	
	if not FileAccess.file_exists(video_path):
		push_error("VideoSplash: Video file not found: " + video_path)
		skip_to_next()
		return
	
	var video_stream = load(video_path)
	if video_stream and video_stream is VideoStream:
		video_player.stream = video_stream
		video_player.play()
	else:
		push_error("VideoSplash: Failed to load video: " + video_path)
		skip_to_next()

func _on_video_stream_player_finished():
	if not is_skipping:
		current_video_index += 1
		play_next_video()

func _input(event):
	if event.is_pressed() and not event.is_echo():
		if (event is InputEventKey and event.keycode != KEY_UNKNOWN) or \
		   (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
			skip_to_next()

func skip_to_next():
	if is_skipping:
		return
	
	is_skipping = true
	video_player.stop()
	current_video_index += 1
	play_next_video()
	is_skipping = false

func transition_to_main_menu():
	set_process_input(false)
	
	var error = get_tree().change_scene_to_file("res://Scenes/parts/main_menu.tscn")
	if error != OK:
		push_error("VideoSplash: Failed to transition to main menu. Error code: " + str(error))
		get_tree().reload_current_scene()
