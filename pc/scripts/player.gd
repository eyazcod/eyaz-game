extends CharacterBody2D

var face = 1
var jumps = 0
var coyote = 0.0
var invincible = 0.0
var dash = 0.0
var game: Node
var locked = false
var jump_buffer = 0.0
const PIXELS = ["....LL..LL......","...LLLLLLL......","....LLGLL.......",".....GG.........","...OOOOOOOO.....","..OSSSSSSSSO....","..OSSSSSKSSO....","..OSSSSSKSSO....","...OSSSSSSO.....","..YYYYYYYYYY....",".SYGGGGGGGGYS...",".SSGGGHGGGGSS...","...GGGHGGGG.....","...GGGGGGGG.....","...GG..GG.......","..OOO..OOO......"]
const PALETTE = {"L":"c4ee86","G":"6da454","H":"a5cf6b","O":"263d39","S":"efd6a0","K":"18283b","Y":"d7a35e"}

func _ready():
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(30, 44)
	shape.shape = rect
	shape.position = Vector2(16, 22)
	add_child(shape)
	floor_snap_length = 5
	collision_layer = 2
	collision_mask = 1

func step(dt):
	invincible = maxf(0, invincible - dt)
	if is_on_floor():
		coyote = 0.1
		jumps = 0
	else:
		coyote -= dt
	jump_buffer=maxf(0,jump_buffer-dt)
	if Input.is_action_just_pressed("jump") and game.input_grace<=0:
		jump_buffer=0.12
	var axis = game.Controller.movement(game.settings.pad_sensitivity)
	velocity.x = move_toward(velocity.x, axis * 306.0, (2600 if axis else 3300) * dt)
	if absf(axis) > 0.1:
		face = 1 if axis > 0 else -1
	if jump_buffer>0 and (coyote > 0 or jumps < (3 if game.stage >= 3 else 2)):
		jump_buffer=0
		if coyote <= 0 and jumps == 0:
			jumps = 1
		jumps += 1
		velocity.y = -756
		coyote = 0
		game.sfx("jump")
		game.burst(position + Vector2(16, 44), Color("a5efc6"), 8)
	if Input.is_action_just_released("jump") and velocity.y < -300:
		velocity.y = -300
	velocity.y = minf(840, velocity.y + 2016 * dt)
	if game.stage >= 4 and Input.is_action_pressed("jump") and velocity.y > 150:
		velocity.y = 150
	if dash > 0:
		dash -= dt
		velocity = Vector2(face * 780, 0)
	if game.slow > 0:
		velocity.x *= 0.72
	move_and_slide()
	position.x = clampf(position.x, 0, game.world_width - 32)
	queue_redraw()

func _draw():
	draw_set_transform(Vector2(-roundf(game.camera_x),0))
	if invincible > 0 and int(Time.get_ticks_msec() / 80) % 2 == 0:
		return
	var bob = sin(Time.get_ticks_msec() * 0.025) * 1.4 if absf(velocity.x) > 30 and is_on_floor() else 0.0
	for y in range(16):
		for x in range(16):
			var c = PIXELS[y][x]
			if PALETTE.has(c):
				draw_rect(Rect2((x if face > 0 else 15-x)*3-8, y*3-4+bob, 3, 3), Color(PALETTE[c]))
