extends Control
signal voyage_finished(arrived: bool)
var game: Node
var islands: Array=[]
var ship=Vector2(16,335)
var route=PackedVector2Array()
var route_index=0
var sailing=false
var time=0.0
var wake: Array=[]
var wake_tick=0.0

func _ready():
	layout_direction=Control.LAYOUT_DIRECTION_LTR
	custom_minimum_size=Vector2(872,355)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	if game.island_layout.is_empty(): generate_layout()
	for i in range(10):
		var tile=preload("res://scripts/island_button.gd").new()
		tile.name="Island%d" % i
		tile.game=game; tile.island=i; tile.disabled=i>game.unlocked
		tile.layout_direction=Control.LAYOUT_DIRECTION_LTR
		tile.pressed.connect(func(): game.sail_to(i))
		add_child(tile)
		tile.position=game.island_layout[i]; tile.scale=Vector2(.78,.78)
		islands.append(tile)
	if game.ship_island>=0: ship=dock(game.ship_island)
	# Keep directional controller navigation predictable despite the scattered layout.
	for tile in islands:
		if tile.disabled: continue
		for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
			var direction=[Vector2.LEFT,Vector2.UP,Vector2.RIGHT,Vector2.DOWN][side]
			var best=null; var score=INF
			for other in islands:
				if other==tile or other.disabled: continue
				var delta=other.position-tile.position
				var forward=delta.dot(direction)
				if forward<=4: continue
				var sideways=absf(delta.cross(direction))
				var value=delta.length()+sideways*1.5
				if value<score: best=other; score=value
			if best: tile.set_focus_neighbor(side,tile.get_path_to(best))

func generate_layout():
	var rng=RandomNumberGenerator.new(); rng.randomize()
	# Scatter without overlap; retain the chart for this game session.
	for attempt in range(30):
		var points: Array=[]
		for trial in range(1200):
			var point=Vector2(rng.randf_range(4,740),rng.randf_range(0,232)).snapped(Vector2(2,2))
			var box=Rect2(point,Vector2(125,117)).grow(5)
			if points.any(func(p): return box.intersects(Rect2(p,Vector2(125,117)).grow(5))): continue
			points.append(point)
			if points.size()==10:
				game.island_layout=points
				return
	var fallback=[Vector2(24,140),Vector2(165,8),Vector2(310,165),Vector2(445,0),Vector2(600,130),Vector2(740,0),Vector2(26,0),Vector2(185,230),Vector2(460,230),Vector2(737,230)]
	fallback.shuffle(); game.island_layout=fallback

func dock(index):
	return game.island_layout[index]+Vector2(62,100)

func build_route(destination):
	var grid=AStarGrid2D.new()
	grid.region=Rect2i(0,0,110,45); grid.cell_size=Vector2(8,8)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for tile in islands:
		var center=tile.position+Vector2(62,60)
		for y in range(45):
			for x in range(110):
				var d=(Vector2(x*8,y*8)-center)/Vector2(55,31)
				if d.length()<1: grid.set_point_solid(Vector2i(x,y))
	var start=Vector2i((ship/8).round()); var end=Vector2i((destination/8).round())
	start=start.clamp(Vector2i.ZERO,Vector2i(109,44)); end=end.clamp(Vector2i.ZERO,Vector2i(109,44))
	grid.set_point_solid(start,false); grid.set_point_solid(end,false)
	var result=grid.get_point_path(start,end)
	if result.is_empty(): return PackedVector2Array()
	result.append(destination)
	return result

func travel_to(index):
	if sailing: return false
	route=build_route(dock(index))
	if route.is_empty(): return false
	route_index=0; sailing=true
	return await voyage_finished

func _process(dt):
	time+=dt
	for w in wake: w.life-=dt
	wake=wake.filter(func(w): return w.life>0)
	if sailing:
		if game.mode!="sailing":
			sailing=false; voyage_finished.emit(false)
		else:
			var distance=190*dt
			while distance>0 and route_index<route.size():
				var gap=ship.distance_to(route[route_index])
				if gap<=distance:
					ship=route[route_index]; route_index+=1; distance-=gap
				else:
					ship=ship.move_toward(route[route_index],distance); distance=0
			wake_tick+=dt
			if wake_tick>.07:
				wake_tick=0; wake.append({"p":ship,"life":.6})
			if route_index>=route.size():
				sailing=false; voyage_finished.emit(true)
	queue_redraw()

func _exit_tree():
	if sailing:
		sailing=false; voyage_finished.emit(false)

func _draw():
	# Dotted route and a small lava-ready vessel are drawn above the chart.
	if sailing:
		for i in range(route_index,route.size(),3):
			draw_rect(Rect2(route[i],Vector2(2,2)),Color(1,.82,.5,.3))
	for w in wake:
		draw_rect(Rect2(w.p+Vector2(-7,8),Vector2(14,2)),Color(1,.65,.3,w.life*.5))
	var p=ship+Vector2(-15,-18+round(sin(time*3)*2))
	draw_rect(Rect2(p+Vector2(-2,22),Vector2(35,4)),Color("d68d45"))
	draw_rect(Rect2(p+Vector2(2,16),Vector2(28,7)),Color("311e29"))
	draw_rect(Rect2(p+Vector2(5,23),Vector2(22,4)),Color("754437"))
	draw_rect(Rect2(p+Vector2(0,15),Vector2(32,3)),Color("d79a58"))
	draw_rect(Rect2(p+Vector2(14,-10),Vector2(3,27)),Color("503c36"))
	for row in range(0,21,3):
		var width=18-row*.55
		draw_rect(Rect2(p+Vector2(17,-8+row),Vector2(width,3)),Color("ffe2a0"))
	draw_rect(Rect2(p+Vector2(21,-1),Vector2(4,6)),Color("77bdb0"))
