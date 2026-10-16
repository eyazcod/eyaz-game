extends Control

var game: Node
var ammo_flash=0.0
var bomb_flash=0.0
var ammo_from=20
const GAIN_DURATION=0.85
const INK = Color("102632")
const EDGE = Color("467475")
const LIGHT = Color("d5f4be")
const MINT = Color("8adbc5")
const GOLD = Color("efcf8a")
const HEAD = ["..gg.gg..", ".ggggggg.", "...ggg...", ".ooooooo.", "osssssso", "osskssko", ".osssso.", "..oooo.."]
const CRYSTAL = ["...x...", "..xxx..", ".xxxxx.", "xxxxxxx", ".xxxxx.", "..xxx..", "...x..."]

func _ready():
	layout_direction=Control.LAYOUT_DIRECTION_LTR
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func resource_gain(kind, previous=0):
	if kind=="ammo":
		ammo_from=previous
		ammo_flash=GAIN_DURATION
	elif kind=="bomb": bomb_flash=GAIN_DURATION
	queue_redraw()

func _process(dt):
	ammo_flash=maxf(0,ammo_flash-dt)
	bomb_flash=maxf(0,bomb_flash-dt)
	visible=is_instance_valid(game) and game.hud.visible
	if visible:
		queue_redraw()

func sprite(rows, origin, pixel, palette):
	for y in range(rows.size()):
		for x in range(rows[y].length()):
			var key=rows[y][x]
			if palette.has(key): draw_rect(Rect2(origin+Vector2(x,y)*pixel,Vector2.ONE*pixel),palette[key])

func disk(center, radius, color):
	# Horizontal pixel strips preserve hard, stepped edges at every scale.
	for y in range(-radius,radius+1):
		var half=int(sqrt(maxf(0,radius*radius-y*y)))
		draw_rect(Rect2(center+Vector2(-half,y)*2,Vector2(half*2+1,1)*2),color)

func _draw():
	if not is_instance_valid(game): return
	draw_map_icon()
	var center=Vector2(48,43)
	# Crystal compass, with a segmented energy ring.
	draw_rect(Rect2(45,3,8,80),INK)
	draw_rect(Rect2(8,40,80,8),INK)
	disk(center+Vector2(2,3),19,INK)
	disk(center,18,EDGE)
	disk(center,15,INK)
	for i in range(16):
		var a=-PI/2+i*TAU/16
		var point=(center+Vector2.from_angle(a)*32).snapped(Vector2(2,2))
		draw_rect(Rect2(point-Vector2(2,2),Vector2(4,4)),MINT if i<ceil(game.stamina/100.0*16) else Color("29434b"))
	var filled=int(round(clampf(game.stamina,0,100)/100.0*19))
	draw_rect(Rect2(29,62-filled*2,38,filled*2),Color("285960"))
	sprite(CRYSTAL,Vector2(34,28),4,{"x":MINT})
	draw_rect(Rect2(46,34,4,16),LIGHT)
	# Five original sprout-head icons, each worth twenty health.
	draw_rect(Rect2(89,39,182,6),INK)
	for i in range(5):
		var amount=clampf((game.health-i*20)/20.0,0,1)
		var colors={"g":Color("b8ec82"),"o":INK,"s":LIGHT,"k":Color("234252")}
		if amount<=0: colors={"g":EDGE.darkened(0.4),"o":INK,"s":Color("304b50"),"k":INK}
		elif amount<1: colors["s"]=Color("8cbb9e")
		sprite(HEAD,Vector2(94+i*36,23),3,colors)
	# A short bounce and a left-to-right fill acknowledge ammo pickups.
	var progress=1-ammo_flash/GAIN_DURATION
	var bounce=-roundf(sin(progress*PI)*3) if ammo_flash>0 else 0.0
	draw_set_transform(Vector2(0,bounce))
	var shown_ammo=game.ammo
	if ammo_flash>0:
		shown_ammo=mini(game.ammo,int(ceil(lerpf(float(ammo_from),float(game.ammo),minf(1,progress*2)))))
	# Twenty ammunition cells, with a small pixel bullet at the left.
	draw_rect(Rect2(94,59,6,4),GOLD)
	draw_rect(Rect2(92,63,10,11),GOLD)
	draw_rect(Rect2(90,74,14,3),EDGE)
	for i in range(20):
		draw_rect(Rect2(111+i*7,62,5,12),INK)
		draw_rect(Rect2(112+i*7,63,3,9),LIGHT if ammo_flash>0 and i<shown_ammo and absf(i-progress*30)<3 else GOLD if i<shown_ammo else Color("29434b"))
	if ammo_flash>0: gain_sparks(Vector2(171,66),progress,GOLD)
	draw_set_transform(Vector2.ZERO)
	# Compact round bomb below the ammunition row, with a red fuse and stock bar.
	var bomb_progress=1-bomb_flash/GAIN_DURATION
	var bomb_y=85-roundf(sin(bomb_progress*PI)*2) if bomb_flash>0 else 85.0
	var red=Color("ff6b6b") if bomb_flash>0 else Color("dc535e")
	var palette={"o":INK,"b":Color("7e999e"),"h":LIGHT,"f":red}
	var bomb_rows=["........ff..",".......ff...",".....oof....","....obbo....","...obbbbo...","..obhbbbbo..",".obhbbbbbbo.",".obbbbbbbbo.",".obbbbbbbbo.","..obbbbbbo..","...oooooo..."]
	sprite(bomb_rows,Vector2(92,bomb_y),1,palette)
	for i in range(9):
		draw_rect(Rect2(111+i*7,bomb_y+4,5,7),INK)
		draw_rect(Rect2(112+i*7,bomb_y+5,3,5),red if i<game.bombs else Color("402e39"))
	if bomb_flash>0: gain_sparks(Vector2(130,bomb_y+5),bomb_progress,red)
	# Three ability groups share a compact segmented bar above ammunition.
	draw_rect(Rect2(109,51,143,8),INK)
	for i in range(3):
		var unlocked=game.stage>=[1,2,5][i]
		var action=["dash","shield","pulse"][i]
		var ready=clampf(1-game.cooldowns[action]/[55.0/60,6.0,4.0][i],0,1) if unlocked else 0.0
		var filled_cells=int(floor(ready*6+0.001))
		var color=[Color("80c5cb"),Color("aedbd4"),Color("a6edb6")][i]
		for cell in range(6):
			draw_rect(Rect2(111+i*47+cell*7,53,5,4),color if cell<filled_cells else Color("28424b") if unlocked else Color("1b303b"))
		if i<2: draw_rect(Rect2(153+i*47,51,3,8),EDGE)

func draw_map_icon():
	# Folded map and a crystal marker; its terrain follows the current biome.
	var origin=Vector2(894,18)
	var accent=Color(game.data.biomes[game.stage][3])
	var terrain=Color(game.data.biomes[game.stage][2]).lightened(0.12)
	var rows=[
		"..............",
		".oooo.........",
		".opppoo..oooo.",
		".opppqqooqppo.",
		".opttqqqqpppo.",
		".optpqqqqptpo.",
		".opppqqqtptpo.",
		".optpqqtqpppo.",
		".opttqtqqptpo.",
		".opppqqqqpppo.",
		".opppqqqqpppo.",
		".oooo..ooqqpo.",
		".........oooo.",
		".............."]
	sprite(rows,origin+Vector2(2,3),3,{"o":INK,"p":INK,"q":INK,"t":INK})
	sprite(rows,origin,3,{"o":INK,"p":Color("c7d6b1"),"q":Color("92b9a7"),"t":terrain})
	sprite(CRYSTAL,origin+Vector2(19,6),2,{"x":accent})
	draw_rect(Rect2(origin+Vector2(25,10),Vector2(2,6)),LIGHT)

func gain_sparks(center, progress, color):
	color.a=1-progress
	for i in range(5):
		var point=(center+Vector2(-30+i*21,-7-progress*(12+i%2*8))).snapped(Vector2(2,2))
		draw_rect(Rect2(point,Vector2(6,2)),color)
		draw_rect(Rect2(point+Vector2(2,-2),Vector2(2,6)),color)
