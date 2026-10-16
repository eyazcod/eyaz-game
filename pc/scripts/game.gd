extends Node2D

const Player = preload("res://scripts/player.gd")
const Controller = preload("res://scripts/controller.gd")
const SAVE_PATH = "user://campaign.json"
const PREFS_PATH = "user://settings.cfg"
var ui_english: Dictionary={}
var translation_keys: Array=[]
var data: Dictionary
var stage = 0
var unlocked = 0
var cleared: Array = []
var island_layout: Array=[]
var ship_island=-1
var archipelago: Control
var mode = "map"
var platforms: Array = []
var enemies: Array = []
var gems: Array = []
var pickups: Array = []
var traps: Array = []
var shots: Array = []
var hazards: Array = []
var bullets: Array = []
var grenades: Array = []
var beams: Array = []
var particles: Array = []
var checkpoints: Array = []
var boss: Dictionary = {}
var miniboss: Dictionary = {}
var terrain: Node2D
var player: CharacterBody2D
var camera_x = 0.0
var world_width = 3500.0
var arena = 2990.0
var gate = 3390.0
var health = 100
var lives = 4
const MAX_AMMO = 20
var ammo = MAX_AMMO
var bombs = 0
var stamina = 100.0
var active_checkpoint = -1
var heal_used = false
var clock = 0.0
var autosave = 0.0
var slow = 0.0
var cooldowns = {"fire":0.0,"dash":0.0,"shield":0.0,"pulse":0.0,"melee":0.0,"parry":0.0}
var shield = 0.0
var parry_time = 0.0
var slash = 0.0
var combo = 0
var combo_window = 0.0
var combo_buffer = 0.0
var melee_hits: Array = []
var freeze = 0.0
var ui: CanvasLayer
var screen: Control
var hud: Label
var pixel_hud: Control
var toast: Label
var toast_left = 0.0
var overlay: PanelContainer
var menu: VBoxContainer
var pending_binding = ""
var settings = {"language":"ar","volume":0.55,"music":true,"sfx":true,"fullscreen":false,"fire_left":false,"pad_deadzone":0.18,"pad_trigger":0.15,"pad_sensitivity":1.0,"pad_rumble":0.6,"pad_combat":false}
var active_pad = -1
var using_pad = false
var input_grace = 0.0
var pad_hint: Label
var pad_diagnostic: Label
var pad_last_input = "اضغط أي زر في اليد للاختبار"
var pad_settings_return = "map"
var menu_music: AudioStreamPlayer
var music: AudioStreamPlayer
var effects: Dictionary = {}
var saved: Dictionary = {}
var save_ok = true
var debug_mode = false
var test_mode = false
var test_frames = 0
var actions = {"left":KEY_A,"right":KEY_D,"jump":KEY_SPACE,"dash":KEY_SHIFT,"shield":KEY_C,"pulse":KEY_Q,"heal":KEY_H,"pause":KEY_P,"bomb":KEY_B,"melee":KEY_J,"parry":KEY_R,"interact":KEY_ENTER}
var action_names = {"left":"يسار","right":"يمين","jump":"قفز","dash":"اندفاع","shield":"درع","pulse":"موجة طاقة","heal":"علاج","pause":"توقف","bomb":"قنبلة","melee":"ضربة قريبة","parry":"صدّ","interact":"دخول / متابعة"}

func _ready():
	if DisplayServer.get_name() != "headless":
		DisplayServer.set_icon(preload("res://assets/eyaz-icon.png").get_image())
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign.json"))
	test_mode = "--smoke-test" in OS.get_cmdline_user_args()
	debug_mode = "--dev" in OS.get_cmdline_user_args()
	if test_mode:
		SAVE_PATH_OVERRIDE = "user://smoke-test.json"
	load_settings()
	ui_english=JSON.parse_string(FileAccess.get_file_as_string("res://data/english.json"))
	translation_keys=ui_english.keys()
	translation_keys.sort_custom(func(a,b): return a.length()>b.length())
	apply_language()
	settings.fullscreen=true
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	setup_input()
	Input.joy_connection_changed.connect(pad_connection_changed)
	Input.ignore_joypad_on_unfocused_application = true
	build_ui()
	setup_audio()
	read_save()
	load_stage(0)
	show_main_menu()
	if test_mode:
		run_smoke.call_deferred()
	elif "--capture" in OS.get_cmdline_user_args():
		capture_preview.call_deferred()
	elif "--preview" in OS.get_cmdline_user_args():
		load_stage(0)
		begin()
		mode = "preview"

var SAVE_PATH_OVERRIDE = ""
func save_path():
	return SAVE_PATH if SAVE_PATH_OVERRIDE.is_empty() else SAVE_PATH_OVERRIDE

func setup_input():
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event = InputEventKey.new()
		event.physical_keycode = actions[action]
		InputMap.action_add_event(action, event)
	for pair in [["left",KEY_LEFT],["right",KEY_RIGHT]]:
		var event = InputEventKey.new()
		event.physical_keycode = pair[1]
		InputMap.action_add_event(pair[0],event)
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
	InputMap.action_erase_events("fire")
	var mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT if settings.fire_left else MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("fire", mouse)
	for pair in [["jump",JOY_BUTTON_A],["dash",JOY_BUTTON_B],["bomb",JOY_BUTTON_X],["pulse",JOY_BUTTON_Y],["shield",JOY_BUTTON_LEFT_SHOULDER],["heal",JOY_BUTTON_RIGHT_SHOULDER],["pause",JOY_BUTTON_START],["parry",JOY_BUTTON_LEFT_STICK],["left",JOY_BUTTON_DPAD_LEFT],["right",JOY_BUTTON_DPAD_RIGHT],["interact",JOY_BUTTON_DPAD_UP]]:
		var event = InputEventJoypadButton.new()
		event.button_index = pair[1]
		InputMap.action_add_event(pair[0], event)
	for pair in [["left",JOY_AXIS_LEFT_X,-1.0],["right",JOY_AXIS_LEFT_X,1.0],["fire",JOY_AXIS_TRIGGER_RIGHT,1.0],["melee",JOY_AXIS_TRIGGER_LEFT,1.0]]:
		var event = InputEventJoypadMotion.new()
		event.axis = pair[1]
		event.axis_value = pair[2]
		InputMap.action_add_event(pair[0],event)

	Controller.configure(settings)

func build_ui():
	ui = CanvasLayer.new()
	add_child(ui)
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(screen)
	var backdrop=preload("res://scripts/menu_backdrop.gd").new()
	backdrop.game=self
	screen.add_child(backdrop)
	var theme = Theme.new()
	theme.default_font_size = 16
	theme.default_font = ui_font("thmanyahsans-Medium.otf")
	for kind in ["normal","hover","pressed","focus","disabled"]:
		var style = StyleBoxFlat.new()
		style.bg_color = Color("271d25") if kind == "normal" else Color("573630")
		if kind == "disabled": style.bg_color = Color("1c1a23")
		style.border_color = Color("ffd398") if kind == "focus" else Color("855646")
		style.set_border_width_all(1)
		style.border_width_left=3
		style.shadow_color=Color(0.02,0.01,0.03,0.5)
		style.shadow_size=4
		style.content_margin_top = 9
		style.content_margin_bottom = 9
		style.content_margin_left = 14
		style.content_margin_right = 14
		theme.set_stylebox(kind,"Button",style)
	screen.theme = theme
	apply_language()
	hud = Label.new()
	hud.position = Vector2(610,16)
	hud.size = Vector2(330,48)
	hud.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_theme_font_size_override("font_size",14)
	hud.add_theme_color_override("font_color",Color("edffe1"))
	hud.add_theme_color_override("font_shadow_color",Color("0d1a29"))
	hud.add_theme_constant_override("shadow_offset_x",2)
	hud.add_theme_constant_override("shadow_offset_y",2)
	screen.add_child(hud)
	pixel_hud=preload("res://scripts/pixel_hud.gd").new()
	pixel_hud.game=self
	screen.add_child(pixel_hud)
	toast = Label.new()
	toast.position = Vector2(180,473)
	toast.size = Vector2(600,40)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_font_size_override("font_size",18)
	screen.add_child(toast)
	pad_hint=Label.new()
	pad_hint.position=Vector2(18,512)
	pad_hint.size=Vector2(924,25)
	pad_hint.add_theme_font_size_override("font_size",12)
	pad_hint.add_theme_color_override("font_color",Color("a5c4c9"))
	screen.add_child(pad_hint)
	overlay = PanelContainer.new()
	overlay.position = Vector2(100,22)
	overlay.size = Vector2(760,496)
	var panel = StyleBoxFlat.new()
	panel.bg_color = Color(0.035,0.09,0.15,0.97)
	panel.border_color = Color("4e8c91")
	panel.set_border_width_all(2)
	panel.set_content_margin_all(22)
	overlay.add_theme_stylebox_override("panel",panel)
	screen.add_child(overlay)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	overlay.add_child(scroll)
	menu = VBoxContainer.new()
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.add_theme_constant_override("separation",10)
	scroll.add_child(menu)

func ui_font(filename):
	# Font files are installed by the developer from the official Thmanyah source.
	var path="res://assets/"+filename
	if ResourceLoader.exists(path): return load(path)
	var fallback=SystemFont.new()
	fallback.font_names=PackedStringArray(["Thmanyah Sans","Tahoma","Segoe UI","Arial"])
	return fallback

func tr_ui(text):
	if settings.get("language","ar")!="en": return text
	var translated=String(text)
	for key in translation_keys: translated=translated.replace(key,ui_english[key])
	for i in range(10): translated=translated.replace("٠١٢٣٤٥٦٧٨٩"[i],str(i))
	return translated

func apply_language():
	if settings.get("language","ar") not in ["ar","en"]: settings.language="ar"
	TranslationServer.set_locale(settings.language)
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_title("Eyaz Adventures" if settings.language=="en" else "مغامرات إياز")
	if is_instance_valid(screen):
		screen.layout_direction=Control.LAYOUT_DIRECTION_LTR if settings.language=="en" else Control.LAYOUT_DIRECTION_RTL
		if screen.theme:
			screen.theme.default_font=ui_font("thmanyahseriftext-Medium.otf") if settings.language=="ar" else ui_font("thmanyahsans-Medium.otf")

func set_language(language):
	settings.language=language
	apply_language()
	save_settings()

func is_menu_scene():
	return is_front_menu() or mode in ["map","intro","sailing"]

func is_front_menu():
	return mode=="main_menu" or (mode in ["settings","pad_settings","help"] and settings_return=="main_menu")

func clear_menu(title, subtitle=""):
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	overlay.position=Vector2(100,22)
	overlay.size=Vector2(760,496)
	for child in menu.get_children():
		menu.remove_child(child)
		child.queue_free()
	var panel=StyleBoxFlat.new()
	panel.bg_color=Color(0.055,0.045,0.075,0.96)
	panel.border_color=Color("855646")
	panel.set_border_width_all(1)
	panel.set_content_margin_all(22)
	if mode in ["main_menu","map"]:
		panel.bg_color=Color.TRANSPARENT
		panel.set_border_width_all(0)
	overlay.add_theme_stylebox_override("panel",panel)
	overlay.show()
	if is_instance_valid(player): player.visible=not is_menu_scene()
	hud.visible = mode in ["paused","settings","lost"] and not is_front_menu()
	label(title,64 if mode=="main_menu" else 28,Color("ffd398"))
	if subtitle: label(subtitle,18 if mode=="main_menu" else 14,Color("c8a894"))

func label(text, size=16, color=Color("ecf6ed"), parent=null):
	var node = Label.new()
	node.text = tr_ui(text)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size",size)
	if settings.language=="ar" and size>=28:
		node.add_theme_font_override("font",ui_font("thmanyahserifdisplay-Bold.otf"))
	node.add_theme_color_override("font_color",color)
	(parent if parent else menu).add_child(node)
	return node

func button(text, callback: Callable, parent=null, disabled=false):
	var node = Button.new()
	node.text = tr_ui(text)
	node.custom_minimum_size.y = 40
	node.disabled = disabled
	node.pressed.connect(callback)
	(parent if parent else menu).add_child(node)
	return node

func focus_first():
	for node in menu.find_children("*","Button",true,false):
		if not node.disabled:
			node.grab_focus()
			break

func show_main_menu():
	mode="main_menu"
	clear_menu("مغامرات إياز","استكشف واجمع المعادن")
	var space=Control.new()
	space.custom_minimum_size.y=18
	menu.add_child(space)
	var choices=VBoxContainer.new()
	choices.custom_minimum_size.x=290
	choices.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	choices.add_theme_constant_override("separation",12)
	menu.add_child(choices)
	var start=button("ابدأ اللعبة",show_map,choices)
	start.custom_minimum_size.y=54
	start.add_theme_font_size_override("font_size",24)
	button("الإعدادات",func(): show_settings("main_menu"),choices)
	button("خروج",quit_game,choices)
	focus_first()
	queue_redraw()

func show_map():
	mode="map"
	clear_menu("مغامرات إياز")
	overlay.position=Vector2(22,8)
	overlay.size=Vector2(916,524)
	archipelago=preload("res://scripts/archipelago_map.gd").new()
	archipelago.game=self
	menu.add_child(archipelago)
	var row=HBoxContainer.new()
	row.alignment=BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",12)
	menu.add_child(row)
	if not saved.is_empty(): button("متابعة الرحلة",func(): sail_to(int(saved.stage),true),row)
	button("الإعدادات",func(): show_settings("map"),row)
	button("القائمة الرئيسية",show_main_menu,row)
	focus_first()
	queue_redraw()

func sail_to(index, resume_campaign=false):
	if index>unlocked or mode!="map" or not is_instance_valid(archipelago): return
	mode="sailing"
	var chart=archipelago
	var arrived=await chart.travel_to(index)
	if arrived and mode=="sailing":
		ship_island=index
		if resume_campaign: resume_saved()
		else: show_intro(index)
	elif mode=="sailing": mode="map"

func show_intro(index):
	if index > unlocked: return
	stage=index; mode="intro"
	clear_menu("الجزيرة %d — %s" % [stage+1,data.level_names[stage]],data.maps[stage].name)
	overlay.set_deferred("size",Vector2(760,496))
	var card=PanelContainer.new()
	var style=StyleBoxFlat.new()
	style.bg_color=Color("1d1923")
	style.border_color=Color(data.biomes[stage][3]).darkened(.3)
	style.set_border_width_all(1); style.border_width_bottom=3
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel",style)
	menu.add_child(card)
	var body=HBoxContainer.new()
	body.layout_direction=Control.LAYOUT_DIRECTION_LTR
	body.add_theme_constant_override("separation",18)
	card.add_child(body)
	var preview=Control.new()
	preview.layout_direction=Control.LAYOUT_DIRECTION_LTR
	preview.custom_minimum_size=Vector2(244,202)
	preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
	body.add_child(preview)
	var island=preload("res://scripts/island_button.gd").new()
	island.game=self; island.island=stage
	island.layout_direction=Control.LAYOUT_DIRECTION_LTR
	preview.add_child(island)
	island.position=Vector2(10,5); island.scale=Vector2(1.4,1.4)
	island.focus_mode=Control.FOCUS_NONE; island.mouse_filter=Control.MOUSE_FILTER_IGNORE
	island.caption.hide(); island.boss_caption.hide()
	var details=VBoxContainer.new()
	details.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	details.alignment=BoxContainer.ALIGNMENT_CENTER
	details.add_theme_constant_override("separation",8)
	body.add_child(details)
	label("حارس الجزيرة" if stage>0 else "حارس الطريق",13,Color("b79c8d"),details)
	label(data.boss_names[stage] if stage>0 else data.mini_names[stage],26,Color(data.biomes[stage][3]),details)
	if stage>0: label("الميني بوس: "+data.mini_names[stage],14,Color("dac5b2"),details)
	label("٤ أرواح  ·  ٢٠ طلقة",15,Color("ffd398"),details)
	var abilities=["قفز"]
	for pair in [[1,"اندفاع"],[2,"درع"],[5,"موجة طاقة"],[6,"علاج"]]:
		if stage>=pair[0]: abilities.append(pair[1])
	label("  ·  ".join(abilities),13,Color("9fcbc1"),details)
	label("اهزم الحارس ثم المس البوابة للعبور تلقائيًا",14,Color("c8a894"))
	var row=HBoxContainer.new()
	row.alignment=BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",14)
	menu.add_child(row)
	var enter=button("دخول الجزيرة",func(): load_stage(index); begin(),row)
	enter.custom_minimum_size=Vector2(280,48)
	enter.add_theme_font_size_override("font_size",20)
	var back=button("خريطة الجزر",show_map,row)
	back.custom_minimum_size=Vector2(180,48)
	enter.grab_focus()

func begin():
	mode = "playing"
	player.show()
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	input_grace = 0.15
	overlay.hide()
	hud.show()
	get_viewport().gui_release_focus()
	save_game()

func make_platform(x,y,w,h,moving=false,phase=0):
	var rect = Rect2(x,y,w,h)
	var body = AnimatableBody2D.new() if moving else StaticBody2D.new()
	body.position = rect.position
	body.collision_layer = 1
	body.collision_mask = 0
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	collision.position = rect.size/2
	collision.one_way_collision = true
	collision.one_way_collision_margin = 8
	body.add_child(collision)
	terrain.add_child(body)
	platforms.append({"rect":rect,"body":body,"moving":moving,"base":x,"phase":phase})

func load_stage(index):
	stage = index
	if is_instance_valid(terrain):
		remove_child(terrain)
		terrain.free()
	if is_instance_valid(player):
		remove_child(player)
		player.free()
	terrain = Node2D.new()
	add_child(terrain)
	platforms.clear(); enemies.clear(); gems.clear(); pickups.clear(); traps.clear()
	shots.clear(); hazards.clear(); bullets.clear(); grenades.clear(); beams.clear(); particles.clear(); checkpoints.clear()
	var design = data.maps[stage]
	make_platform(0,450,320,90)
	var cursor = 410.0
	var section = 0
	for section_name in design.sections:
		var ys = data.heights[section_name]
		for j in range(4):
			var w = float(design.width)+(20 if j == 2 else 0)
			var y = float(ys[j])
			make_platform(cursor,y,w,24)
			gems.append({"p":Vector2(cursor+w/2,y-34),"taken":false})
			if section % 3 == 1 and j == 1:
				var sy = maxf(80,y-130)
				make_platform(cursor+30,sy,110,24,stage in [1,4,9],section*17)
				gems.append({"p":Vector2(cursor+85,sy-32),"taken":false})
			if (section+stage)%3 == 1 and j == 2:
				traps.append({"p":Vector2(cursor+w+24,y+45),"base":y+45,"phase":section*31})
			cursor += w+float(design.gap)+(12 if j%2 else 0)
		make_platform(cursor,450,260,90)
		if section%2 == 1:
			enemies.append({"p":Vector2(cursor+90,422),"min":cursor+65,"max":cursor+180,"dir":1,"dead":false})
		cursor += 350
		section += 1
	arena = cursor
	world_width = arena+760
	gate = world_width-110
	make_platform(arena,450,760,90)
	make_platform(arena+110,330,110,24)
	make_platform(arena+330,265,110,24)
	for p in [Vector2(arena+165,296),Vector2(arena+385,231),Vector2(gate,415)]:
		gems.append({"p":p,"taken":false})
	var rests = platforms.filter(func(p): return p.rect.size.y == 90 and p.rect.position.x > 0 and p.rect.position.x < arena)
	rests.sort_custom(func(a,b): return absf(a.rect.position.x-world_width/2) < absf(b.rect.position.x-world_width/2))
	var mid = rests[0].rect
	checkpoints.append(Vector2(mid.position.x+30,450))
	for p in platforms:
		if p.rect.size.y == 90 and p.rect.position.x < arena:
			pickups.append({"p":p.rect.position+Vector2(150 if p.rect.position.x==0 else 30,-20),"type":"gun" if pickups.size()%2==0 else "bomb","taken":false})
	enemies = enemies.filter(func(e): return e.p.x < mid.position.x or e.p.x > mid.end.x)
	miniboss = {"p":Vector2(mid.position.x+145,404),"home":mid.position.x+145,"min":mid.position.x+80,"max":mid.position.x+190,"hp":6+stage/3,"max_hp":6+stage/3,"dir":-1,"timer":0.0,"inv":0.0,"active":false,"dead":false,"size":Vector2(46,46),"stun":0.0,"posture":0}
	boss = {} if stage == 0 else {"p":Vector2(world_width-310,388),"hp":11+stage,"max_hp":11+stage,"dir":-1,"timer":0.0,"inv":0.0,"active":false,"dead":false,"size":Vector2(64,62),"phase":0,"dash":0.0,"dash_dir":1,"stun":0.0,"posture":0}
	player = Player.new()
	player.game = self
	player.position = Vector2(70,406)
	add_child(player)
	camera_x = 0
	health=100; lives=4; ammo=MAX_AMMO; bombs=0; stamina=100; active_checkpoint=-1; heal_used=false
	shield=0; parry_time=0; slash=0; combo=0; combo_window=0; combo_buffer=0; slow=0; freeze=0
	for key in cooldowns: cooldowns[key]=0.0
	clock=0; autosave=0
	queue_redraw()

func _physics_process(dt):
	if is_instance_valid(overlay) and overlay.visible:
		overlay.position.x=roundf((get_viewport().get_visible_rect().size.x-overlay.size.x)/2.0)
	clock += dt
	if is_instance_valid(pad_diagnostic): pad_diagnostic.text=tr_ui(pad_last_input)
	input_grace=maxf(0,input_grace-dt)
	if pad_hint:
		pad_hint.visible=using_pad and mode=="playing"
		pad_hint.text=tr_ui("A/✕ قفز   B/○ اندفاع   RT/R2 إطلاق   بوابة تلقائية   Start توقف" if not settings.pad_combat else "A/✕ قفز   X/□ ضرب   LT/L2 صدّ   RT/R2 إطلاق   RB/R1 قنبلة   بوابة تلقائية")
	if mode == "playing":
		if freeze > 0:
			freeze -= dt
		else:
			step(dt)
		camera_x = clampf(player.position.x-345,0,world_width-960)
		player.position = player.position.round() if player.is_on_floor() and absf(player.velocity.x)<0.1 else player.position
		autosave += dt
		if autosave > 3:
			autosave=0
			save_game()
	for p in particles:
		p.life -= dt
		p.p += p.v*dt
		p.v.y += 250*dt
	particles = particles.filter(func(p): return p.life>0)
	toast_left -= dt
	toast.visible = toast_left>0 and mode=="playing"
	if is_instance_valid(player): player.visible=not is_menu_scene()
	if menu_music:
		menu_music.volume_db=linear_to_db(maxf(0.001,float(settings.volume)))-9
		menu_music.stream_paused=not settings.music or not is_menu_scene()
	if music:
		music.volume_db = linear_to_db(maxf(0.001,float(settings.volume))) - 13
		music.stream_paused = not settings.music or mode != "playing"
		music.pitch_scale = 1.12 if not boss.is_empty() and boss.active and not boss.dead else 1.0
	queue_redraw()
	if test_mode: smoke_tick()

func step(dt):
	for key in cooldowns: cooldowns[key] = maxf(0,cooldowns[key]-dt)
	shield=maxf(0,shield-dt); parry_time=maxf(0,parry_time-dt); slash=maxf(0,slash-dt); slow=maxf(0,slow-dt)
	combo_window=maxf(0,combo_window-dt); combo_buffer=maxf(0,combo_buffer-dt)
	stamina=minf(100,stamina+28.8*dt)
	for p in platforms:
		if p.moving:
			p.body.position.x = p.base+sin((clock*60+p.phase)*0.025)*32
			p.rect.position.x = p.body.position.x
	var old_y = player.position.y
	player.step(dt)
	if player.position.y > 620: hurt("fall")
	if mode != "playing": return
	if Input.is_action_pressed("fire"): fire()
	for action in ["dash","shield","pulse","heal"]:
		if Input.is_action_just_pressed(action): ability(action)
	if Input.is_action_just_pressed("melee"): melee()
	if Input.is_action_just_pressed("parry"): parry()
	if Input.is_action_just_pressed("bomb"): throw_bomb()
	if combo_buffer>0 and cooldowns.melee<=0: melee()
	for gem in gems:
		if not gem.taken and player.position.distance_to(gem.p-Vector2(16,22))<33:
			gem.taken=true; burst(gem.p,Color("b8ec82"),10); sfx("gem")
	for p in pickups:
		if not p.taken and player_rect().intersects(Rect2(p.p-Vector2(20,16),Vector2(40,32))):
			p.taken=true
			if p.type=="gun":
				var previous_ammo=ammo
				ammo=MAX_AMMO
				pixel_hud.resource_gain("ammo",previous_ammo)
			else:
				bombs+=3
				pixel_hud.resource_gain("bomb")
			sfx("gem")
	for i in range(checkpoints.size()):
		if i>active_checkpoint and absf(player.position.x-checkpoints[i].x)<45 and absf(player.position.y+44-checkpoints[i].y)<65:
			active_checkpoint=i; save_game(); sfx("gem"); notify("تم الحفظ عند نقطة آمنة")
	for e in enemies:
		if e.dead: continue
		e.p.x += e.dir*(105+stage*12)*dt
		if e.p.x<e.min or e.p.x>e.max: e.dir *= -1
		if player_rect().intersects(Rect2(e.p,Vector2(32,28))):
			if old_y+44<=e.p.y+14 and player.velocity.y>0:
				e.dead=true; player.velocity.y=-650; sfx("stomp")
			else: hurt("contact")
	for trap in traps:
		trap.p.y=trap.base+sin((clock*60+trap.phase)*0.045)*64
		if player_rect().intersects(Rect2(trap.p-Vector2(6,6),Vector2(32,32))): hurt("hazard")
	for p in platforms:
		if p.rect.size.y==90 and p.rect.position.x>0 and p.rect.position.x<arena:
			if player_rect().intersects(Rect2(p.rect.end.x-32,431,26,19)): hurt("hazard")
	update_guard(miniboss,dt,true,old_y)
	if not boss.is_empty(): update_guard(boss,dt,false,old_y)
	update_weapons(dt)
	if slash>0.1: apply_melee()
	for beam in beams: beam.life-=dt
	beams=beams.filter(func(b): return b.life>0)
	if player_rect().intersects(Rect2(gate-20,354,52,96)):
		if boss.is_empty() or boss.dead:
			complete_island()
		else: notify("اهزم حارس الجزيرة لفتح البوابة",0.2)

func player_rect():
	return Rect2(player.position,Vector2(32,44))

func ability(kind):
	var unlock={"dash":1,"shield":2,"pulse":5,"heal":6}
	if stage<int(unlock[kind]):
		notify("القدرة تفتح في الجزيرة "+str(int(unlock[kind])+1))
		return
	if kind=="dash" and stage>=1 and cooldowns.dash==0:
		player.dash=10.0/60; player.invincible=maxf(player.invincible,0.2); cooldowns.dash=55.0/60; sfx("laser")
	if kind=="shield" and stage>=2 and cooldowns.shield==0:
		shield=110.0/60; cooldowns.shield=6; sfx("gem")
	if kind=="pulse" and stage>=5 and cooldowns.pulse==0:
		cooldowns.pulse=4; burst(player.position,Color("91f8e3"),50); shots.clear()
		for e in enemies:
			if absf(e.p.x-player.position.x)<240: e.dead=true
		for g in [miniboss,boss]:
			if not g.is_empty() and absf(g.p.x-player.position.x)<240: damage_guard(g,2)
		sfx("laser")
	if kind=="heal" and stage>=6 and not heal_used and health<100:
		health=100; heal_used=true; sfx("gem"); save_game()

func fire():
	if cooldowns.fire>0: return
	sfx("laser")
	var origin=player.position+Vector2(16+player.face*20,25)
	if ammo>0:
		ammo-=1; cooldowns.fire=7.0/60
		bullets.append({"p":origin,"v":Vector2(player.face*720,0),"life":1.25})
		return
	cooldowns.fire=20.0/60 if stage>=7 else 42.0/60
	var end=clampf(origin.x+player.face*650,0,world_width)
	var target: Dictionary={}
	var closest=absf(end-origin.x)
	for e in enemies:
		if e.dead: continue
		if Rect2(minf(origin.x,end),origin.y-5,absf(end-origin.x),10).intersects(Rect2(e.p,Vector2(32,28))) and absf(e.p.x-origin.x)<closest:
			target=e; closest=absf(e.p.x-origin.x)
	for g in [miniboss,boss]:
		if g.is_empty() or g.dead: continue
		if Rect2(minf(origin.x,end),origin.y-5,absf(end-origin.x),10).intersects(Rect2(g.p,g.size)) and absf(g.p.x-origin.x)<closest:
			target=g; closest=absf(g.p.x-origin.x)
	if not target.is_empty():
		end=target.p.x+16
		if target.has("hp"): damage_guard(target,1)
		else: target.dead=true
		burst(Vector2(end,origin.y),Color("9df7ff"),15)
	beams.append({"from":origin,"end":Vector2(end,origin.y),"life":0.16})
	shots=shots.filter(func(s): return not Rect2(minf(origin.x,end),origin.y-8,absf(end-origin.x),16).intersects(Rect2(s.p,s.size)))

func melee():
	if cooldowns.melee>0:
		if cooldowns.melee<0.17: combo_buffer=0.2
		return
	if stamina<18: return
	stamina-=18
	combo=combo%3+1 if combo_window>0 else 1
	combo_window=65.0/60
	cooldowns.melee=0.6 if combo==3 else 0.4
	slash=14.0/60; combo_buffer=0; melee_hits.clear()
	apply_melee(); sfx("laser")

func apply_melee():
	var reach=100 if combo==3 else 78
	var box=Rect2(player.position+Vector2(20 if player.face>0 else -reach+12,-8),Vector2(reach,64))
	for e in enemies:
		if not e.dead and box.intersects(Rect2(e.p,Vector2(32,28))):
			e.dead=true; burst(e.p,Color("cbf8c0"),12)
	for g in [miniboss,boss]:
		if g.is_empty() or g.dead or g in melee_hits: continue
		if box.intersects(Rect2(g.p,g.size)):
			melee_hits.append(g)
			damage_guard(g,2 if combo==3 else 1)
			g.posture+=2 if combo==3 else 1
			stagger(g)
			freeze=0.04

func parry():
	if cooldowns.parry>0 or stamina<24: return
	stamina-=24; parry_time=11.0/60; cooldowns.parry=0.8

func hurt(kind):
	if mode!="playing" or (debug_mode and Input.is_physical_key_pressed(KEY_F2)): return
	if kind!="fall" and (player.invincible>0 or shield>0): return
	if kind not in ["fall","hazard"] and parry_time>0:
		parry_time=0; player.invincible=0.4; stamina=minf(100,stamina+18); freeze=0.08
		shots=shots.filter(func(s): return s.p.distance_to(player.position)>140)
		for g in [miniboss,boss]:
			if not g.is_empty() and not g.dead and absf(g.p.x-player.position.x)<150:
				g.posture+=2; stagger(g)
		notify("صدّ مثالي!"); burst(player.position,Color("9af8ef"),26); sfx("gem"); return
	health=0 if kind=="fall" else maxi(0,health-40)
	combo_window=0; combo_buffer=0; combo=0; sfx("hurt")
	burst(player.position,Color("ff969f"),16)
	if health<=0:
		lives-=1; shots.clear(); hazards.clear()
		if lives<=0:
			health=0; mode="restarting"; saved={}; save_game()
			restart_current_island.call_deferred()
			return
		health=100; safe_spawn(); save_game()
	else:
		player.invincible=85.0/60
		player.velocity=Vector2(-player.face*210,-120)

func restart_current_island():
	# Rebuild outside the physics callback; checkpoints belong to the old attempt.
	load_stage(stage)
	begin()
	safe_spawn()
	notify("انتهت الأرواح — رجعت لبداية الجزيرة",3)

func stagger(g):
	if g.posture>=5:
		g.posture=0; g.stun=65.0/60; shots.clear(); notify("اختل توازن الحارس!")

func damage_guard(g, amount):
	if g.dead or g.inv>0: return
	g.hp=maxi(0,int(g.hp)-amount); g.inv=0.4; g.active=true
	burst(g.p+g.size/2,Color("ffd58a"),16)
	if g.hp==0:
		g.dead=true
		if g==miniboss:
			var previous_ammo=ammo
			ammo=MAX_AMMO; bombs+=2; health=mini(100,health+34)
			pixel_hud.resource_gain("ammo",previous_ammo)
			pixel_hud.resource_gain("bomb")
		else:
			shots.clear(); hazards.clear()
		sfx("win"); save_game()

func update_guard(g,dt,is_mini,old_y):
	if g.dead: return
	g.inv=maxf(0,g.inv-dt); g.stun=maxf(0,g.stun-dt)
	if is_mini:
		if absf(player.position.x-g.home)<520: g.active=true
	else:
		if player.position.x>arena+110: g.active=true
	if not g.active: return
	if g.stun<=0:
		g.timer+=dt
		var speed=(66+stage*3.6) if is_mini else (72 if stage==6 else 90 if stage==9 else 126)
		g.p.x+=g.dir*speed*dt
		var low=g.min if is_mini else arena+10
		var high=g.max if is_mini else world_width-180
		if g.p.x<low: g.p.x=low; g.dir=1
		if g.p.x>high: g.p.x=high; g.dir=-1
		if not is_mini:
			g.p.y=388-maxf(0,sin(g.timer*1.92))*75 if stage==3 else 340+sin(g.timer*1.5)*35 if stage==9 else 388
			if g.dash>0:
				g.dash-=dt; g.p.x=clampf(g.p.x+g.dash_dir*540*dt,arena+10,world_width-180)
		var period=(130 if stage%3==1 else 110)/60.0 if is_mini else (145 if stage==9 else 130 if stage==2 else 135 if stage==6 else 115)/60.0
		period*=0.88
		if g.hp<=g.max_hp/2.0 and not is_mini: period*=0.8
		g["warning"]=fmod(g.timer,period)>period-0.6
		if int((g.timer-dt)/period)<int(g.timer/period):
			if is_mini: mini_attack(g)
			else: boss_attack(g)
	if player_rect().intersects(Rect2(g.p,g.size)):
		if old_y+44<=g.p.y+18 and player.velocity.y>0:
			player.velocity.y=-690; damage_guard(g,1)
		else: hurt("contact")

func shot(p,v,kind="normal",size=Vector2(16,16),gravity=0.0):
	shots.append({"p":p,"v":v,"kind":kind,"size":size,"gravity":gravity,"age":0.0,"life":3.8,"base":p.y})

func mini_attack(g):
	var origin=g.p+Vector2(23,18)
	var angle=(player.position+Vector2(16,22)-origin).angle()
	if stage%3==0:
		for offset in [-0.2,0.2]: shot(origin,Vector2.from_angle(angle+offset)*210,"miniboss",Vector2(12,12))
	elif stage%3==1:
		shot(origin,Vector2(-198 if player.position.x<g.p.x else 198,-330),"miniboss",Vector2(16,16),504)
	else: shot(origin,Vector2(-228 if player.position.x<g.p.x else 228,0),"miniboss",Vector2(20,18))

func warning(x,w,kind,delay=0.75,duration=0.92):
	hazards.append({"rect":Rect2(clampf(x,0,world_width-w),0 if kind in ["lightning","beam"] else 412,w,450 if kind in ["lightning","beam"] else 38),"kind":kind,"delay":delay,"life":duration})

func boss_attack(g):
	var origin=g.p+Vector2(32,20)
	var angle=(player.position+Vector2(16,22)-origin).angle()
	var dir=-1 if player.position.x<g.p.x else 1
	var rage=g.hp<=g.max_hp/2.0
	match stage:
		1:
			for i in range(3 if rage else 2): shot(origin+Vector2(0,i*30),Vector2(dir*(240+i*21),0),"water")
		2:
			warning(player.position.x-12,54,"lightning")
			if rage: warning(player.position.x+125,48,"lightning",1.03,0.58)
		3:
			for i in range(4 if rage else 3): shot(origin,Vector2(dir*(180+i*39),-420-i*33),"fire",Vector2(16,16),684)
		4:
			for i in range(5 if rage else 3): warning(player.position.x-170+i*100,28,"meteor",0.75+i*0.15,0.02)
		5:
			if g.phase%2==0: g.dash=32.0/60; g.dash_dir=dir
			else:
				for i in range(3): warning(player.position.x-110+i*100,45,"lava",0.75+i*0.13,1.08)
		6:
			for i in range(3 if rage else 2): shot(Vector2(origin.x,398-i*36),Vector2(dir*(156+i*24),0),"sand",Vector2(30,50))
		7:
			for i in range(-2,3): shot(origin,Vector2.from_angle(angle+i*0.28)*306,"ice")
		8:
			if g.phase%2==0:
				for i in range(4 if rage else 3): warning(player.position.x-100+i*90,36,"vine",0.83+i*0.1,1.33)
			else:
				for i in range(-1,2): shot(origin,Vector2.from_angle(angle+i*0.3)*270,"seed")
		9:
			if g.phase%2==0:
				var count=12 if rage else 8
				for i in range(count): shot(origin,Vector2.from_angle(i*TAU/count+g.phase*0.17)*228,"star")
			else:
				warning(player.position.x-20,48,"beam",0.97,0.75)
				warning(player.position.x+160,48,"beam",1.25,0.67)
	g.phase+=1; sfx("stomp")

func throw_bomb():
	if bombs<=0: return
	bombs-=1
	grenades.append({"p":player.position+Vector2(12,8),"v":Vector2(player.face*360,-420),"fuse":1.25})
	sfx("stomp")

func update_weapons(dt):
	for s in shots:
		s.age+=dt; s.life-=dt; s.v.y+=s.gravity*dt; s.p+=s.v*dt
		if s.kind=="water": s.p.y=s.base+sin(s.age*4.8)*32
		if s.kind=="fire" and s.p.y>=430:
			warning(s.p.x-12,38,"ember",0.3,1.25); s.life=0
		if player_rect().intersects(Rect2(s.p,s.size)):
			var hp=health
			hurt("projectile")
			if s.kind=="ice" and health<hp: slow=100.0/60
			s.life=0
	shots=shots.filter(func(s): return s.life>0 and s.p.y<650 and s.p.y>-120 and s.p.x>0 and s.p.x<world_width).slice(-90)
	for h in hazards:
		if h.delay>0:
			h.delay-=dt
			if h.delay<=0 and h.kind=="meteor": shot(Vector2(h.rect.position.x,-30),Vector2(0,420),"meteor",Vector2(28,28),162); h.life=0
		else:
			h.life-=dt
			if player_rect().intersects(h.rect): hurt("hazard")
	hazards=hazards.filter(func(h): return h.life>0).slice(-24)
	for b in bullets:
		var previous=b.p
		b.p+=b.v*dt; b.life-=dt
		var swept=Rect2(Vector2(minf(previous.x,b.p.x),b.p.y),Vector2(absf(b.p.x-previous.x)+12,6))
		for e in enemies:
			if not e.dead and swept.intersects(Rect2(e.p,Vector2(32,28))): e.dead=true; b.life=0
		for g in [miniboss,boss]:
			if not g.is_empty() and not g.dead and swept.intersects(Rect2(g.p,g.size)): damage_guard(g,1); b.life=0
	bullets=bullets.filter(func(b): return b.life>0)
	for b in grenades:
		var previous=b.p
		b.v.y+=1620*dt; b.p+=b.v*dt; b.fuse-=dt
		for p in platforms:
			if b.v.y>0 and previous.y+14<=p.rect.position.y+3 and b.p.y+14>=p.rect.position.y and b.p.x>p.rect.position.x and b.p.x<p.rect.end.x:
				b.p.y=p.rect.position.y-14; b.v.y*=-0.45; b.v.x*=0.7
		if b.fuse<=0:
			burst(b.p,Color("ffcb77"),45); sfx("stomp")
			for e in enemies:
				if e.p.distance_to(b.p)<140: e.dead=true
			for g in [miniboss,boss]:
				if not g.is_empty() and g.p.distance_to(b.p)<160: damage_guard(g,3)
	grenades=grenades.filter(func(b): return b.fuse>0 and b.p.y<700)

func safe_spawn():
	player.position=checkpoints[active_checkpoint]-Vector2(16,44) if active_checkpoint>=0 else Vector2(70,406)
	player.velocity=Vector2.ZERO; player.jumps=0; player.coyote=0.1; player.invincible=100.0/60
	camera_x=clampf(player.position.x-345,0,world_width-960)

func complete_island():
	if stage not in cleared: cleared.append(stage)
	unlocked=maxi(unlocked,mini(9,stage+1)); saved={}
	mode="map"; save_game(); sfx("win"); show_map()

func notify(text,duration=2.4):
	toast.text=tr_ui(text); toast_left=duration

func burst(p,color,count):
	for i in range(count):
		particles.append({"p":p,"v":Vector2(randf_range(-150,150),randf_range(-240,0)),"life":randf_range(0.3,0.65),"color":color})

func _input(event):
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadButton or absf(event.axis_value)>0.25:
			active_pad=event.device
			pad_last_input=("استجابة من اليد %d — زر %d" % [event.device,event.button_index]) if event is InputEventJoypadButton else ("استجابة من اليد %d — عصا / زناد %d" % [event.device,event.axis])
			if not using_pad:
				using_pad=true
				if overlay.visible: focus_first()
		if event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_B and mode!="playing":
			if mode=="paused": begin()
			elif mode in ["settings","help"]: return_from_settings()
			elif mode=="pad_settings": return_from_pad_settings()
			elif mode=="intro": show_map()
			elif mode in ["map","sailing"]: show_main_menu()
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventKey or (event is InputEventMouseMotion and event.relative.length()>2):
		using_pad=false
	if event is InputEventKey and event.pressed and not event.echo:
		if not pending_binding.is_empty():
			var key=event.physical_keycode
			get_viewport().set_input_as_handled()
			if key==KEY_ESCAPE: pending_binding=""; show_settings(settings_return); return
			if key in [KEY_ENTER,KEY_TAB,KEY_F11,KEY_ESCAPE]: return
			for action in actions:
				if action!=pending_binding and actions[action]==key: notify("الزر مستخدم بالفعل"); return
			actions[pending_binding]=key; pending_binding=""; setup_input(); save_settings(); show_settings(settings_return); return
		if event.keycode==KEY_F11:
			toggle_fullscreen(); return
		if event.keycode==KEY_F3 and debug_mode:
			unlocked=9; show_map(); return
		if event.keycode==KEY_F4 and debug_mode and mode=="playing":
			player.position=Vector2(arena+130,360); return
		if event.keycode==KEY_F5 and debug_mode and mode=="playing":
			if not boss.is_empty(): boss.inv=0; damage_guard(boss,999)
			return
	if event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE):
		if mode=="playing": show_pause()
		elif mode=="paused": begin()
		elif mode=="settings" or mode=="help": return_from_settings()
		elif mode=="pad_settings": return_from_pad_settings()
		elif mode=="intro": show_map()
		elif mode in ["map","sailing"]: show_main_menu()
		get_viewport().set_input_as_handled()

func _notification(what):
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		if mode=="playing": show_pause()
	if what==NOTIFICATION_WM_CLOSE_REQUEST: quit_game()

func _exit_tree():
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	stop_pad_rumble()
	if is_instance_valid(music):
		music.stream_paused=false
		music.stop()
		music.stream=null
	effects.clear()

func show_pause():
	stop_pad_rumble()
	mode="paused"; save_game(); clear_menu("استراحة قصيرة","التقدم محفوظ عند آخر نقطة آمنة")
	button("استئناف",begin)
	button("الإعدادات",func(): show_settings("paused"))
	button("التحكم",func(): show_help("paused"))
	button("خريطة الجزر",show_map)
	button("حفظ وخروج",quit_game)
	focus_first()

var settings_return="map"
func show_settings(return_to):
	settings_return=return_to; mode="settings"
	clear_menu("الإعدادات","F11 — نافذة / ملء الشاشة")
	button("Language: English" if settings.language=="ar" else "اللغة: العربية",func(): set_language("en" if settings.language=="ar" else "ar"); show_settings(return_to))
	button("إعدادات الكنترول",func(): show_pad_settings(return_to))
	button("ملء الشاشة: "+("نعم" if settings.fullscreen else "لا"),func(): toggle_fullscreen(); show_settings(return_to))
	button("الموسيقى: "+("تعمل" if settings.music else "متوقفة"),func(): settings.music=not settings.music; save_settings(); show_settings(return_to))
	button("المؤثرات: "+("تعمل" if settings.sfx else "متوقفة"),func(): settings.sfx=not settings.sfx; save_settings(); show_settings(return_to))
	button("الإطلاق بالماوس: "+("يسار" if settings.fire_left else "يمين"),func(): settings.fire_left=not settings.fire_left; setup_input(); save_settings(); show_settings(return_to))
	var volume=HSlider.new()
	volume.min_value=0; volume.max_value=1; volume.step=0.05; volume.value=settings.volume
	volume.custom_minimum_size.y=25
	volume.value_changed.connect(func(v): settings.volume=v; save_settings())
	menu.add_child(volume)
	label("اضغط لتغيير زر الكيبورد — Escape للإلغاء",14)
	var grid=GridContainer.new(); grid.columns=3; menu.add_child(grid)
	for action in actions:
		if action=="interact": continue
		var text=action_names[action]+": "+OS.get_keycode_string(actions[action])
		var b=button(text,func(): pending_binding=action; label("اضغط الزر الجديد لـ "+action_names[action]),grid)
		b.custom_minimum_size.x=210
	button("رجوع",return_from_settings)
	focus_first()

func return_from_settings():
	pending_binding=""; save_settings()
	if settings_return=="main_menu": show_main_menu()
	elif settings_return=="paused": show_pause()
	else: show_map()

func show_help(return_to):
	settings_return=return_to; mode="help"
	clear_menu("التحكم","يمكن تخصيص الكيبورد من الإعدادات")
	label("A / D أو الأسهم — حركة\nSpace — قفز مزدوج / ثلاثي\nكلك يمين — ليزر / رشاش\nJ — كومبو من ثلاث ضربات    R — صدّ لحظي\nShift — اندفاع    C — درع    Q — موجة    H — علاج\nB — قنبلة    P / Escape — توقف    البوابة — دخول تلقائي",18)
	label(Controller.guide(settings.pad_combat),16)
	button("رجوع",return_from_settings); focus_first()

func toggle_fullscreen():
	settings.fullscreen=not settings.fullscreen
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	save_settings()

func save_settings():
	if test_mode: return
	var cfg=ConfigFile.new()
	for key in settings: cfg.set_value("preferences",key,settings[key])
	for key in actions: cfg.set_value("keys",key,actions[key])
	cfg.save(PREFS_PATH)

func load_settings():
	if test_mode: return
	var cfg=ConfigFile.new()
	if cfg.load(PREFS_PATH)!=OK: return
	for key in settings: settings[key]=cfg.get_value("preferences",key,settings[key])
	for key in actions: actions[key]=cfg.get_value("keys",key,actions[key])
	if settings.fullscreen: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func read_save():
	if not FileAccess.file_exists(save_path()): return
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(save_path()))
	if not parsed is Dictionary or parsed.get("schema",0)!=1: return
	unlocked=clampi(int(parsed.get("unlocked",0)),0,9)
	for index in parsed.get("cleared",[]):
		if index is float and index==int(index) and index>=0 and index<10 and int(index) not in cleared: cleared.append(int(index))
	var c=parsed.get("campaign",{})
	if c is Dictionary and not c.is_empty() and int(c.get("stage",-1)) in range(10) and int(c.get("lives",0)) in range(1,5): saved=c

func save_game():
	if mode in ["playing","paused"]:
		saved={"stage":stage,"health":health,"lives":lives,"checkpoint":active_checkpoint,"ammo":ammo,"bombs":bombs,"heal_used":heal_used,"gems":gems.map(func(g): return g.taken),"pickups":pickups.map(func(p): return p.taken),"mini_hp":miniboss.hp,"mini_dead":miniboss.dead,"boss_hp":boss.get("hp",0),"boss_dead":boss.get("dead",true)}
	var payload={"schema":1,"unlocked":unlocked,"cleared":cleared,"campaign":saved}
	var path=save_path()
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: save_ok=false; notify("تعذر الحفظ — تحقق من مساحة الجهاز"); return
	file.store_string(JSON.stringify(payload)); file.close()
	var error=DirAccess.rename_absolute(path+".tmp",path)
	save_ok=error==OK
	if not save_ok: notify("تعذر حفظ التقدم")

func resume_saved():
	if saved.is_empty(): return
	var s=saved.duplicate(true)
	load_stage(clampi(int(s.stage),0,9))
	lives=clampi(int(s.lives),1,4); health=clampi(int(s.get("health",100)),1,100)
	active_checkpoint=clampi(int(s.get("checkpoint",-1)),-1,checkpoints.size()-1)
	ammo=clampi(int(s.get("ammo",MAX_AMMO)),0,MAX_AMMO); bombs=clampi(int(s.get("bombs",0)),0,999)
	heal_used=s.get("heal_used",false)
	for i in range(mini(gems.size(),s.get("gems",[]).size())): gems[i].taken=s.gems[i]==true
	for i in range(mini(pickups.size(),s.get("pickups",[]).size())): pickups[i].taken=s.pickups[i]==true
	miniboss.hp=clampi(int(s.get("mini_hp",miniboss.max_hp)),0,int(miniboss.max_hp)); miniboss.dead=miniboss.hp==0 and s.get("mini_dead",false)
	if not miniboss.dead: miniboss.hp=maxi(1,int(miniboss.hp))
	if not boss.is_empty():
		boss.hp=clampi(int(s.get("boss_hp",boss.max_hp)),0,int(boss.max_hp)); boss.dead=boss.hp==0 and s.get("boss_dead",false)
		if not boss.dead: boss.hp=maxi(1,int(boss.hp))
	safe_spawn(); begin()

func quit_game():
	save_game(); save_settings(); shutdown()

func shutdown():
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	mode="closing"
	if is_instance_valid(music):
		music.stream_paused=false
		music.stop()
		music.stream=null
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream=null
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()

func setup_audio():
	if DisplayServer.get_name()=="headless": return
	menu_music=AudioStreamPlayer.new(); add_child(menu_music)
	menu_music.stream=preload("res://audio/embers-menu.wav")
	menu_music.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	menu_music.stream.loop_end=int(menu_music.stream.get_length()*menu_music.stream.mix_rate)
	menu_music.stream_paused=not settings.music
	menu_music.play()
	music=AudioStreamPlayer.new(); add_child(music)
	if ResourceLoader.exists("res://audio/voyage.wav"):
		music.stream=load("res://audio/voyage.wav")
		music.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		music.stream.loop_end=int(music.stream.get_length()*music.stream.mix_rate)
		music.play()
	for name in ["jump","gem","laser","stomp","hurt","win"]:
		var path="res://audio/"+name+".wav"
		if ResourceLoader.exists(path): effects[name]=load(path)

func sfx(name):
	if name=="hurt": pad_rumble(0.35,0.65,0.18)
	elif name=="stomp": pad_rumble(0.12,0.2,0.07)
	elif name=="win": pad_rumble(0.45,0.25,0.3)
	if not settings.sfx or not effects.has(name): return
	var audio=AudioStreamPlayer.new(); audio.stream=effects[name]
	audio.volume_db=linear_to_db(maxf(0.001,float(settings.volume)))-9
	add_child(audio); audio.finished.connect(audio.queue_free); audio.play()

func _draw():
	if data.is_empty() or is_menu_scene(): return
	var biome=data.biomes[stage]
	var bg=Color(biome[1]); var surface=Color(biome[2]); var accent=Color(biome[3])
	draw_rect(Rect2(0,0,960,540),bg)
	for layer in range(3):
		var col=bg.lightened(0.035+layer*0.025)
		for i in range(-1,10):
			var x=i*180-fmod(camera_x*(0.12+layer*0.12),180)
			var y=210+layer*80+sin(i*1.7+stage)*40
			draw_colored_polygon(PackedVector2Array([Vector2(x,y+150),Vector2(x+85,y),Vector2(x+180,y+150)]),col)
	for i in range(65):
		var x=fposmod(i*131.7-camera_x*0.04,960)
		var y=fposmod(i*79.1,280)
		draw_rect(Rect2(x,y,2,2),accent*Color(1,1,1,0.45))
	if stage in [0,7]:
		for i in range(42):
			var p=Vector2(fposmod(i*123-clock*15,960),fposmod(i*71+clock*28,540))
			draw_rect(Rect2(p,Vector2(3,3)),Color(0.9,0.97,1,0.35))
	elif stage==2:
		for i in range(55):
			var p=Vector2(fposmod(i*93-clock*60,960),fposmod(i*47+clock*370,540))
			draw_line(p,p+Vector2(-4,14),Color(0.65,0.8,0.9,0.32),1)
	elif stage in [3,5]:
		for i in range(35):
			var p=Vector2(fposmod(i*97+sin(clock+i)*20,960),540-fposmod(i*67+clock*30,540))
			draw_rect(Rect2(p,Vector2(3,5)),Color(1,0.5,0.2,0.35))
	elif stage==8:
		for i in range(10):
			var x=fposmod(i*173-camera_x*0.25,1200)-100
			draw_rect(Rect2(x,210,18,330),Color("163329"))
			draw_circle(Vector2(x+8,185),60,Color("244c35"))
	elif stage==1:
		for i in range(7):
			var y=360+i*27
			draw_line(Vector2(0,y+sin(clock+i)*4),Vector2(960,y+sin(clock+i)*4),Color(0.3,0.8,0.85,0.15),4)
	elif stage==9:
		draw_circle(Vector2(770-camera_x*0.002,150),50,Color("473766"))
		draw_arc(Vector2(770-camera_x*0.002,150),75,-0.3,PI+0.3,48,Color("816d9f"),6)
	if mode in ["main_menu","map","intro"]:
		for i in range(15): draw_line(Vector2(0,120+i*30+sin(clock+i)*3),Vector2(960,120+i*30+sin(clock+i)*3),Color(0.3,0.65,0.75,0.07),2)
	if not is_instance_valid(player): return
	draw_set_transform(Vector2(-roundf(camera_x),0))
	for p in platforms:
		var r=p.rect
		if r.end.x<camera_x-60 or r.position.x>camera_x+1020: continue
		draw_rect(r, surface.darkened(0.5))
		draw_rect(Rect2(r.position,Vector2(r.size.x,7)),accent)
		draw_rect(Rect2(r.position+Vector2(0,7),Vector2(r.size.x,8)),surface)
		for i in range(int(r.size.x/25)):
			draw_rect(Rect2(r.position+Vector2(i*25+5,20),Vector2(7,4)),surface.darkened(0.2))
		if r.size.y==90 and r.position.x>0 and r.position.x<arena:
			for i in range(3):
				var x=r.end.x-32+i*9
				draw_colored_polygon(PackedVector2Array([Vector2(x,450),Vector2(x+4,431),Vector2(x+9,450)]),Color("eeb7c3"))
	for gem in gems:
		if gem.taken: continue
		var p=gem.p+Vector2(0,sin(clock*3+gem.p.x)*3)
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-10),p+Vector2(7,0),p+Vector2(0,10),p+Vector2(-7,0)]),Color("b8ef94"))
		draw_line(p+Vector2(0,-7),p+Vector2(0,6),Color("f5ffe4"),2)
	for p in pickups:
		if p.taken: continue
		draw_rect(Rect2(p.p-Vector2(20,16),Vector2(40,30)),Color("453b37"))
		if p.type=="gun":
			draw_rect(Rect2(p.p-Vector2(13,5),Vector2(26,9)),Color("a6dae0"))
			draw_rect(Rect2(p.p-Vector2(3,-2),Vector2(8,9)),Color("d4b878"))
		else: draw_circle(p.p,9,Color("c8df83"))
	for i in range(checkpoints.size()):
		var p=checkpoints[i]
		var color=Color("b8ec82") if i<=active_checkpoint else Color("698a89")
		draw_rect(Rect2(p.x-3,p.y-72,6,72),Color("9daf9e"))
		draw_colored_polygon(PackedVector2Array([p+Vector2(3,-70),p+Vector2(37,-58),p+Vector2(3,-44)]),color)
	for e in enemies:
		if e.dead: continue
		draw_rect(Rect2(e.p,Vector2(32,25)),surface)
		draw_rect(Rect2(e.p+Vector2(5,7),Vector2(6,5)),Color("152638"))
		draw_rect(Rect2(e.p+Vector2(22,7),Vector2(6,5)),Color("152638"))
	for trap in traps:
		draw_circle(trap.p+Vector2(10,10),12,Color("6d344c"))
		for i in range(8):
			var angle=i*TAU/8+clock*4.8
			draw_line(trap.p+Vector2(10,10),trap.p+Vector2(10,10)+Vector2.from_angle(angle)*19,Color("ff8e9e"),5)
	draw_guard(miniboss,accent,true)
	if not boss.is_empty(): draw_guard(boss,accent,false)
	var open=boss.is_empty() or boss.dead
	draw_rect(Rect2(gate-20,354,52,96),Color("16333a"))
	draw_rect(Rect2(gate-14,360,40,90),Color("b8ec82") if open else Color("846580"),false,5)
	if open:
		for i in range(6): draw_rect(Rect2(gate-7+i%3*10,370+i*11+sin(clock*3+i)*4,4,6),Color("d9ffc6"))
	for s in shots: draw_rect(Rect2(s.p,s.size),accent if s.kind!="fire" else Color("ff9c64"))
	for h in hazards:
		var color=accent
		if h.delay>0:
			color.a=0.35+sin(clock*15)*0.2
			draw_rect(Rect2(h.rect.position.x,438,h.rect.size.x,12),color)
			if h.kind in ["beam","lightning","meteor"]: draw_line(Vector2(h.rect.get_center().x,30),Vector2(h.rect.get_center().x,430),color,3)
		else:
			draw_rect(h.rect,color)
			draw_rect(Rect2(h.rect.get_center().x-3,h.rect.position.y,6,h.rect.size.y),Color("fff3d9"))
	for b in bullets: draw_rect(Rect2(b.p,Vector2(12,5)),Color("ffe994"))
	for b in grenades: draw_circle(b.p+Vector2(7,7),7,Color("ff8058") if b.fuse<0.3 else Color("c8df83"))
	for beam in beams:
		draw_line(beam.from,beam.end,Color(0.3,0.85,1,beam.life*6),9)
		draw_line(beam.from,beam.end,Color("e8ffff"),3)
	for p in particles: draw_rect(Rect2(p.p,Vector2(3,3)),p.color)
	if shield>0 or parry_time>0:
		draw_rect(Rect2(player.position-Vector2(8,5),Vector2(48,54)),Color("9afff0"),false,3)
	if slash>0:
		var a=-0.9 if player.face>0 else PI-0.9
		draw_arc(player.position+Vector2(16,20),85 if combo==3 else 65,a,a+1.8,20,Color("ffe49c") if combo==3 else Color("bcfff2"),6)
	draw_set_transform(Vector2.ZERO)
	if mode in ["playing","preview","paused"]:
		if not boss.is_empty() and boss.active and not boss.dead:
			draw_rect(Rect2(350,92,260,8),Color("243447"))
			draw_rect(Rect2(350,92,260*boss.hp/float(boss.max_hp),8),Color("ed8bad"))

func draw_guard(g,color,is_mini):
	if g.dead: return
	var p=g.p; var size=g.size
	if g.inv<=0 or int(clock*20)%2==0:
		draw_rect(Rect2(p+Vector2(4,8),size-Vector2(8,12)),color.darkened(0.15))
		draw_rect(Rect2(p+Vector2(0,16),Vector2(size.x,size.y-26)),color)
		draw_rect(Rect2(p+Vector2(6,0),Vector2(10,15)),color.lightened(0.2))
		draw_rect(Rect2(p+Vector2(size.x-16,0),Vector2(10,15)),color.lightened(0.2))
		draw_rect(Rect2(p+Vector2(10,20),Vector2(7,7)),Color("1a263a"))
		draw_rect(Rect2(p+Vector2(size.x-17,20),Vector2(7,7)),Color("1a263a"))
	if g.active:
		draw_rect(Rect2(p.x-10,p.y-15,size.x+20,6),Color("142338"))
		draw_rect(Rect2(p.x-10,p.y-15,(size.x+20)*g.hp/float(g.max_hp),6),Color("ffbd7b"))
		if g.get("warning",false): draw_circle(p+Vector2(size.x/2,-28),5,Color("fff1a0"))
		if g.stun>0: draw_arc(p+size/2,size.x*0.7,clock*4,clock*4+PI,12,Color("9af8ef"),3)
	if not is_mini:
		draw_rect(Rect2(p.x-5,p.y-6,74,3),Color("314055"))
		draw_rect(Rect2(p.x-5,p.y-6,74*g.posture/5.0,3),Color("a6f2ed"))

var smoke_phase=0
func run_smoke():
	controller_tests()
	# Isolated test save; no user progress is changed.
	unlocked=9
	for i in range(10):
		load_stage(i)
		assert(ammo==20,"New islands must start with 20 rounds")
		assert(miniboss.max_hp>=6,"Stronger miniboss health")
		if i>0: assert(boss.max_hp==11+i,"Stronger boss health")
		assert(platforms.size()>30)
		assert(checkpoints.size()==1,"Only the middle checkpoint should remain")
		assert(checkpoints[0].x<arena,"No checkpoint at the boss arena")
		assert(world_width>7000)
		assert(gems.size()>25)
	load_stage(0); begin()
	Input.action_press("right")

func pad_connection_changed(device,connected):
	if connected:
		if active_pad<0: active_pad=device
		notify("تم توصيل يد التحكم")
	elif device==active_pad:
		active_pad=-1
		if mode=="playing": show_pause()
		notify("انفصلت اليد — يمكنك المتابعة بالكيبورد أو إعادة توصيلها",5)

func pad_rumble(weak,strong,duration):
	if using_pad and active_pad>=0 and settings.pad_rumble>0 and mode=="playing":
		Input.start_joy_vibration(active_pad,weak*settings.pad_rumble,strong*settings.pad_rumble,duration)

func stop_pad_rumble():
	for device in Input.get_connected_joypads(): Input.stop_joy_vibration(device)

func show_pad_settings(return_to):
	pad_settings_return=return_to
	mode="pad_settings"
	clear_menu("إعدادات الكنترول","Xbox / PlayStation · توصيل وفصل أثناء التشغيل")
	var connected=Input.get_connected_joypads()
	label("لم تُوصل يد حاليًا" if connected.is_empty() else "اليد: "+Input.get_joy_name(connected[0]),14)
	pad_diagnostic=label(pad_last_input,14,Color("c2f0a0"))
	button("التوزيع: "+("قتال قريب" if settings.pad_combat else "كلاسيكي"),func(): settings.pad_combat=not settings.pad_combat; Controller.configure(settings); save_settings(); show_pad_settings(return_to))
	label(Controller.guide(settings.pad_combat),14)
	for row in [["pad_deadzone","تجاهل انحراف العصا",0.08,0.4,0.01],["pad_trigger","عتبة ضغط الزناد",0.05,0.6,0.05],["pad_sensitivity","استجابة العصا",0.6,1.8,0.1],["pad_rumble","قوة الاهتزاز",0.0,1.0,0.1]]:
		var key=row[0]
		var title=label(row[1]+": "+str(snappedf(float(settings[key]),0.01)),14)
		var slider=HSlider.new()
		slider.min_value=row[2]; slider.max_value=row[3]; slider.step=row[4]; slider.value=settings[key]
		slider.custom_minimum_size.y=23
		slider.value_changed.connect(func(value): settings[key]=value; title.text=tr_ui(row[1]+": "+str(snappedf(value,0.01))); Controller.configure(settings); save_settings())
		menu.add_child(slider)
	button("رجوع",return_from_pad_settings)
	focus_first()

func return_from_pad_settings():
	show_settings(pad_settings_return)

func controller_tests():
	for device in [0,1,3,7]:
		var press=InputEventJoypadButton.new()
		press.device=device; press.pressed=true; press.button_index=JOY_BUTTON_A
		assert(InputMap.event_is_action(press,"jump"),"Jump ignores controller "+str(device))
		assert(InputMap.event_is_action(press,"ui_accept"),"Menus ignore controller "+str(device))
		var trigger=InputEventJoypadMotion.new()
		trigger.device=device; trigger.axis=JOY_AXIS_TRIGGER_RIGHT; trigger.axis_value=1.0
		assert(InputMap.event_is_action(trigger,"fire"),"Trigger ignores controller "+str(device))
	assert(is_equal_approx(InputMap.action_get_deadzone("left"),0.18))
	assert(is_equal_approx(InputMap.action_get_deadzone("fire"),0.15))
	assert(InputMap.action_get_events("parry").any(func(e): return e is InputEventJoypadButton and e.button_index==JOY_BUTTON_LEFT_STICK))
	settings.pad_combat=true; Controller.configure(settings)
	assert(InputMap.action_get_events("melee").any(func(e): return e is InputEventJoypadButton and e.button_index==JOY_BUTTON_X))
	assert(InputMap.action_get_events("parry").any(func(e): return e is InputEventJoypadMotion and e.axis==JOY_AXIS_TRIGGER_LEFT))
	assert(InputMap.action_get_events("bomb").any(func(e): return e is InputEventJoypadButton and e.button_index==JOY_BUTTON_RIGHT_SHOULDER))
	assert(InputMap.action_get_events("jump").any(func(e): return e is InputEventKey))
	settings.pad_combat=false; Controller.configure(settings)
	load_stage(0); mode="playing"; active_pad=42; pad_connection_changed(42,false)
	assert(mode=="paused" and active_pad==-1)
	print("CONTROLLER_TESTS_OK: deadzones, two layouts, keyboard preserved, disconnect pause")

func smoke_tick():
	test_frames+=1
	if test_frames==20:
		assert(player.position.x>90,"Movement failed")
		Input.action_release("right"); Input.action_press("jump")
	if test_frames==23:
		assert(player.velocity.y<0,"Jump failed")
		Input.action_release("jump")
	if test_frames==35:
		player.invincible=0; hurt("contact"); assert(health==60)
		player.invincible=0; parry(); hurt("contact"); assert(health==60,"Parry failed")
		parry_time=0; player.invincible=0; hurt("fall"); assert(lives==3 and health==100)
		active_checkpoint=0; ammo=17; bombs=4; gems[0].taken=true; save_game()
		health=1; ammo=0; resume_saved()
		assert(lives==3 and ammo==17 and bombs==4 and gems[0].taken,"Save roundtrip failed")
		assert(absf(player.position.x-checkpoints[0].x+16)<1,"Safe checkpoint spawn failed")
	if test_frames==36:
		load_stage(1); mode="playing"; active_checkpoint=0
		save_game(); saved.checkpoint=1; resume_saved()
		assert(active_checkpoint==0,"Old boss checkpoint save must migrate to remaining checkpoint")
		player.position=checkpoints[0]-Vector2(16,44)
		lives=2; hurt("fall")
		assert(lives==1 and active_checkpoint==0,"Checkpoint must survive while lives remain")
		assert(player.position.x<arena,"Respawn must use middle checkpoint, not boss arena")
		hurt("fall")
		assert(mode=="restarting","Last life must restart island automatically")
	if test_frames==37:
		assert(stage==1 and mode=="playing","Must stay on current island")
		assert(lives==4 and health==100 and ammo==20,"New attempt must reset resources")
		assert(active_checkpoint==-1 and player.position.x<100,"Last life must reset boss checkpoint")
		assert(not boss.dead and boss.hp==boss.max_hp,"Boss must reset for new attempt")
		assert(int(saved.stage)==1 and int(saved.checkpoint)==-1,"Restart save must point at island start")
		print("CHECKPOINT_TESTS_OK: no boss checkpoints; legacy saves migrate; last life restarts same map")
	if test_frames==45:
		load_stage(7); mode="playing"
		player.position=miniboss.p-Vector2(50,0); player.face=1
		melee(); assert(stamina==82 and miniboss.hp<miniboss.max_hp,"Melee failed")
		ability("dash"); assert(player.dash>0 and cooldowns.dash>0,"Dash failed")
		ability("shield"); assert(shield>0,"Shield failed")
		health=40; ability("heal"); assert(health==100 and heal_used,"Heal failed")
		bombs=1; throw_bomb(); assert(bombs==0 and grenades.size()==1,"Bomb failed")
		var before=miniboss.hp; miniboss.inv=0; ability("pulse"); assert(miniboss.hp<before,"Pulse failed")
		for i in range(1,10):
			load_stage(i); mode="playing"; boss.active=true
			for phase in range(4): boss_attack(boss)
			assert(shots.size()+hazards.size()>0,"Boss attacks missing")
			boss.inv=0; damage_guard(boss,999); assert(boss.dead)
			miniboss.inv=0; damage_guard(miniboss,999); assert(miniboss.dead)
			complete_island(); assert(i in cleared)
		load_stage(1); begin(); player.position=Vector2(arena+140,300)
	if test_frames>45 and test_frames<210:
		player.invincible=100
		Input.action_press("fire")
	if test_frames==210:
		Input.action_release("fire")
		assert(player.is_on_floor(),"Native platform landing failed")
		assert(save_ok,"Save failed")
		print("EYAZ_SMOKE_OK: 10 maps, movement, jumping, damage, parry, checkpoint save/load, 9 elemental bosses, rewards and unlocks")
		get_tree().quit.call_deferred()

func capture_preview():
	for i in range(12): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../eyaz-godot-map.png")
	load_stage(0); mode="preview"; overlay.hide(); hud.show()
	player.position=Vector2(850,300); camera_x=500
	for i in range(12): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../eyaz-godot-gameplay.png")
	load_stage(9); mode="preview"; overlay.hide(); hud.show()
	player.position=Vector2(arena+180,406); camera_x=world_width-960; boss.active=true
	for i in range(12): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../eyaz-godot-boss.png")
	shutdown()


