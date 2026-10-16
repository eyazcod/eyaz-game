extends Button
var game: Node
var island=0
var time=0.0
var caption: Label
var boss_caption: Label

func _ready():
	layout_direction=Control.LAYOUT_DIRECTION_LTR
	custom_minimum_size=Vector2(160,150)
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND if not disabled else Control.CURSOR_FORBIDDEN
	for state in ["normal","hover","pressed","focus","disabled"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	text=""
	tooltip_text=game.tr_ui(game.data.maps[island].name+" — "+(game.data.boss_names[island] if island>0 else game.data.mini_names[0]))
	caption=Label.new()
	caption.layout_direction=Control.LAYOUT_DIRECTION_LTR
	caption.text=game.tr_ui(str(island+1)+" · "+game.data.biomes[island][0]+("  ✓" if island in game.cleared else ""))
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size",14)
	caption.add_theme_color_override("font_color",Color("ffe2b8") if not disabled else Color("8f8285"))
	caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	caption.position=Vector2(0,113); caption.size=Vector2(160,23)
	boss_caption=Label.new()
	boss_caption.layout_direction=Control.LAYOUT_DIRECTION_LTR
	boss_caption.text=game.tr_ui(game.data.boss_names[island] if island>0 else game.data.mini_names[0])
	boss_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	boss_caption.add_theme_font_size_override("font_size",10)
	boss_caption.add_theme_color_override("font_color",Color("bd9d91"))
	boss_caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(boss_caption)
	boss_caption.position=Vector2(0,135); boss_caption.size=Vector2(160,15)

func _process(dt):
	time+=dt
	queue_redraw()

func slab(center, rx, ry, color):
	for row in range(-ry,ry+1,3):
		var half=floor(sqrt(maxf(0,1-pow(float(row)/ry,2)))*rx/3)*3
		draw_rect(Rect2(center+Vector2(-half,row),Vector2(half*2,3)),color)

func tree(p, color, snow=false):
	draw_rect(Rect2(p+Vector2(-2,-13),Vector2(5,17)),Color("59473c"))
	for level in range(3):
		var w=18-level*4
		draw_rect(Rect2(p+Vector2(-w/2.0,-18-level*7),Vector2(w,10)),color.lightened(level*.06))
		if snow: draw_rect(Rect2(p+Vector2(-w/2.0,-18-level*7),Vector2(w,3)),Color("e6f7ed"))

func _draw():
	if not is_instance_valid(game): return
	var surface=Color(game.data.biomes[island][2])
	var accent=Color(game.data.biomes[island][3])
	if disabled:
		surface=surface.darkened(.45); accent=accent.darkened(.45)
	var bob=round(sin(time*1.5+island*1.1)*3)
	var center=Vector2(80,77+bob)
	var selected=has_focus() or is_hovered() and not disabled
	# Each island has a stone underside and an elliptical, stepped top surface.
	slab(Vector2(80,104),67,10,Color("7e3227"))
	if selected: slab(center+Vector2(0,5),72,30,Color("f5b965"))
	for depth in range(18,0,-3):
		slab(center+Vector2(0,depth),64-depth*.6,22,Color("46303a").lightened(depth*.004))
	slab(center,65,25,surface.darkened(.28))
	slab(center-Vector2(0,3),60,21,surface)
	# Rocky shores, broken paths and biome details use the same palette as gameplay.
	for i in range(9):
		var a=i*TAU/9
		var p=center+Vector2(cos(a)*53,sin(a)*19)
		draw_rect(Rect2(p.snapped(Vector2(3,3)),Vector2(9,6)),surface.darkened(.34))
	for i in range(6):
		draw_rect(Rect2(center+Vector2(-36+i*12,9+sin(i)*3),Vector2(8,3)),accent.darkened(.2))
	match island:
		0,7:
			tree(center+Vector2(-36,-8),Color("6c9495"),true)
			tree(center+Vector2(36,-4),Color("557c8e"),true)
		1:
			for i in range(3): draw_rect(Rect2(center+Vector2(-45+i*31,0),Vector2(17,3)),accent)
			draw_rect(Rect2(center+Vector2(-39,-18),Vector2(13,25)),Color("8a6951"))
		2:
			tree(center+Vector2(-34,-6),Color("496969"))
			for i in range(6): draw_rect(Rect2(center+Vector2(-45+i*17,-36+fposmod(time*22+i*7,23)),Vector2(1,6)),accent)
		3,5:
			for i in range(3):
				var p=center+Vector2(-43+i*40,-8)
				draw_rect(Rect2(p,Vector2(10,11)),Color("56313b"))
				draw_rect(Rect2(p+Vector2(2,-8-abs(sin(time*5+i))*8),Vector2(6,16)),accent)
		4,9:
			for i in range(3):
				var p=center+Vector2(-42+i*42,-13)
				draw_rect(Rect2(p,Vector2(8,18)),surface.darkened(.5))
				draw_rect(Rect2(p+Vector2(2,-8),Vector2(4,16)),accent)
		6:
			draw_rect(Rect2(center+Vector2(-38,-17),Vector2(5,22)),Color("6a8858"))
			draw_rect(Rect2(center+Vector2(-44,-13),Vector2(17,4)),Color("6a8858"))
			draw_rect(Rect2(center+Vector2(25,-4),Vector2(19,5)),accent)
		8:
			tree(center+Vector2(-37,-8),Color("375c3e"))
			tree(center+Vector2(34,-7),Color("467f49"))
			tree(center+Vector2(48,5),Color("375c3e"))
	# A miniature of the actual island guardian stands at its center.
	var p=center+Vector2(-16,-39)
	var body=accent.darkened(.15)
	draw_rect(Rect2(p+Vector2(2,5),Vector2(28,25)),body)
	draw_rect(Rect2(p+Vector2(0,10),Vector2(32,14)),accent)
	draw_rect(Rect2(p+Vector2(4,0),Vector2(5,9)),accent.lightened(.2))
	draw_rect(Rect2(p+Vector2(23,0),Vector2(5,9)),accent.lightened(.2))
	draw_rect(Rect2(p+Vector2(7,13),Vector2(4,4)),Color("152333"))
	draw_rect(Rect2(p+Vector2(21,13),Vector2(4,4)),Color("152333"))
	if selected:
		draw_rect(Rect2(76,11,8,4),Color("ffd598"))
		draw_rect(Rect2(78,15,4,4),Color("ffd598"))
	if disabled:
		var lock=Vector2(126,26)
		draw_rect(Rect2(lock+Vector2(3,-4),Vector2(8,8)),Color("94736c"))
		draw_rect(Rect2(lock+Vector2(5,-2),Vector2(4,5)),Color("251d29"))
		draw_rect(Rect2(lock,Vector2(14,11)),Color("b89b83"))
		draw_rect(Rect2(lock+Vector2(6,3),Vector2(2,5)),Color("251d29"))
