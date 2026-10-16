extends Node

# A small local named-pipe companion runs invisibly, bound to the game's PID.
# It reconnects when Discord starts and stops when the game process exits.
const COMPANION = "res://native/EYAZ-Discord.exe"
var helper_pid = -1

func _ready():
	if OS.get_name() != "Windows": return
	var args = OS.get_cmdline_user_args()
	if "--smoke-test" in args or "--capture" in args: return
	if DisplayServer.get_name() == "headless" and "--discord-test" not in args: return
	var folder = "user://discord"
	if DirAccess.make_dir_recursive_absolute(folder) != OK: return
	var destination = folder + "/EYAZ-Discord-v3.exe"
	if not FileAccess.file_exists(COMPANION): return
	var bytes = FileAccess.get_file_as_bytes(COMPANION)
	if bytes.is_empty(): return
	if not FileAccess.file_exists(destination) or FileAccess.get_file_as_bytes(destination) != bytes:
		var output = FileAccess.open(destination,FileAccess.WRITE)
		if output == null: return
		output.store_buffer(bytes)
		output.close()
	helper_pid = OS.create_process(ProjectSettings.globalize_path(destination),PackedStringArray([
		str(OS.get_process_id()),
		ProjectSettings.globalize_path(folder + "/presence-status.txt")
	]),false)
	if helper_pid < 0: push_warning("Discord presence could not start; the game remains playable.")
