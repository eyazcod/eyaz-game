extends Control
var game: Node
var time=0.0

func _ready():
	layout_direction=Control.LAYOUT_DIRECTION_LTR
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _process(dt):
	visible=game.is_menu_scene()
	if visible:
		time+=dt
		queue_redraw()

func _draw():
	if game.mode in ["map","intro","sailing"]:
		draw_lava_sea()
		return
	draw_rect(Rect2(0,0,960,540),Color("100e18"))
	# Warm horizon glow built from quiet bands behind the pixel fire.
	for i in range(32):
		var y=220+i*10
		var strength=pow(float(i)/32,2)
		draw_rect(Rect2(0,y,960,10),Color(0.30,0.07,0.025,strength*0.6))
	# A small crystal seal connects the warm title to the game's identity.
	for side in [-1,1]:
		draw_rect(Rect2(480+side*38-(26 if side<0 else 0),170,26,1),Color("704a3e"))
	for row in range(9):
		var width=mini(row,8-row)*2+2
		draw_rect(Rect2(480-width/2.0,166+row,width,1),Color("e9ac70"))
	# Distant black silhouettes frame the title without showing the game map.
	for side in [0,1]:
		var x=side*850
		draw_rect(Rect2(x,220,110,320),Color("151018"))
		for i in range(5):
			draw_rect(Rect2(x+i*22,200+(i%3)*16,18,40),Color("151018"))
	# Layered tongues of fire; stepped columns animate on a twelve-fps rhythm.
	var tick=floor(time*12)/12
	for layer in range(3):
		var colors=[Color("5b2226"),Color("c24a2c"),Color("f19a4b")]
		for x in range(0,960,8):
			var h=25+24*sin(x*.034+tick*3.2)+17*sin(x*.079-tick*4.4)+12*sin(x*.14+tick*6)
			h=maxf(8,h)*(1.7-layer*.48)
			var y=540-floor(h/4)*4
			draw_rect(Rect2(x,y,8,540-y),colors[layer])
	# Ember motes rise from the flames and fade into the dark.
	for i in range(48):
		var age=fposmod(time*(18+i%7*3)+i*47,510)
		var x=fposmod(i*137+sin(time*.7+i)*16,960)
		var col=Color("ffc37b"); col.a=(1-age/540)*(.3+float(i%3)*.2)
		draw_rect(Rect2(floor(x/3)*3,540-floor(age/3)*3,3 if i%3 else 2,3 if i%3 else 5),col)
	# Fine ornamental corners, leaving generous negative space.
	for side in [0,1]:
		var x=30 if side==0 else 902
		draw_rect(Rect2(x,28,28,2),Color("875746"))
		draw_rect(Rect2(x if side==0 else x+26,28,2,28),Color("875746"))

func draw_lava_sea():
	draw_rect(Rect2(0,0,960,540),Color("25121c"))
	# Slow molten currents pass beneath the islands, with bright pixel fissures.
	for row in range(0,540,6):
		var wave=sin(row*.034+time*.6)
		var color=Color("54232a").lerp(Color("843029"),(wave+1)*.35)
		draw_rect(Rect2(0,row,960,6),color)
	# Bright molten seams distinguish the ocean from ordinary red water.
	for seam in range(5):
		var points=PackedVector2Array()
		for x in range(-12,984,12):
			var y=116+seam*92+sin(x*.013+seam*2+time*.18)*14+sin(x*.037+seam)*5
			points.append(Vector2(x,round(y/3)*3))
		draw_polyline(points,Color("8d3426"),8)
		draw_polyline(points,Color("c6582d"),3)
	for i in range(18):
		var p=Vector2(fposmod(i*157+time*2,960),110+fposmod(i*83,360))
		var pulse=sin(time*1.4+i)
		if pulse>.1:
			draw_rect(Rect2(p.snapped(Vector2(3,3)),Vector2(9,3)),Color("ed9953"))
			draw_rect(Rect2(p.snapped(Vector2(3,3))+Vector2(3,-3),Vector2(3,9)),Color("d96735"))
	for i in range(110):
		var x=fposmod(i*113+time*(4+i%3),980)-20
		var y=fposmod(i*71,540)
		var length=8+i%5*8
		var color=Color("d15c37") if i%3 else Color("ed9953")
		color.a=.18+sin(time+i)*.09
		draw_rect(Rect2(floor(x/3)*3,y,length,2),color)
	for i in range(22):
		var age=fposmod(time*13+i*37,540)
		draw_rect(Rect2(fposmod(i*139+sin(time+i)*8,960),540-age,2,3),Color(1,.65,.25,.35))
	# Dark edges keep controls readable over the glowing ocean.
	draw_rect(Rect2(0,0,960,95),Color(.05,.035,.065,.88))
	draw_rect(Rect2(0,472,960,68),Color(.05,.035,.065,.85))
