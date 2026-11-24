extends Node2D
## Skolan: rutnät med rum, dörrar och möbler. Ritas med _draw() och har
## en AStarGrid2D så att elever och vuxna kan hitta vägen.

const T := 40
const COLS := 90
const ROWS := 46
const WW := COLS * T
const WH := ROWS * T

const F_CORR := 0
const F_WOOD := 1
const F_CHECK := 2
const F_GYM := 3
const F_DOOR := 4
const F_GRASS := 5
const F_OFFICE := 6

const ROOM_7A := 0
const ROOM_8B := 1
const ROOM_MAT := 2
const ROOM_GYM := 3
const ROOM_CV := 4
const ROOM_CH := 5
const ROOM_YARD := 6
const ROOM_REKTOR := 7

var rooms := [
	{"name": "Klassrum 7A", "r": Rect2i(1, 1, 25, 15), "f": F_WOOD},
	{"name": "Klassrum 8B", "r": Rect2i(34, 1, 25, 15), "f": F_WOOD},
	{"name": "Matsalen", "r": Rect2i(1, 24, 25, 15), "f": F_CHECK},
	{"name": "Idrottssalen", "r": Rect2i(34, 24, 25, 15), "f": F_GYM},
	{"name": "Korridoren", "r": Rect2i(27, 1, 6, 38), "f": F_CORR},
	{"name": "Korridoren", "r": Rect2i(1, 17, 58, 6), "f": F_CORR},
	{"name": "Skolgården", "r": Rect2i(60, 1, 29, 44), "f": F_GRASS},
	{"name": "Rektorns kontor", "r": Rect2i(27, 40, 6, 5), "f": F_OFFICE},
]
const CAMERA_ROOMS := ["Korridoren", "Matsalen", "Idrottssalen", "Skolgården"]

var grid := PackedByteArray()      # 0 vägg, 1 golv, 2 möbel
var ftype := PackedByteArray()
var room_of := PackedInt32Array()
var furn: Array = []
var seats := {0: [], 1: []}
var teacher_spot := {}
var class_door := {}
var lunch_spots: Array = []
var counter_spot := Vector2()
var bench_spot := Vector2()
var office_spot := Vector2()
var rektor_spot := Vector2()
var exp_spot := Vector2()
var pitch := Rect2()
var cam_spots := {}
var trees: Array = []
var astar := AStarGrid2D.new()


func _ready() -> void:
	build()


func build() -> void:
	grid.resize(COLS * ROWS)
	grid.fill(0)
	ftype.resize(COLS * ROWS)
	ftype.fill(0)
	room_of.resize(COLS * ROWS)
	room_of.fill(-1)
	for ri in rooms.size():
		var r: Rect2i = rooms[ri]["r"]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var i := y * COLS + x
				grid[i] = 1
				ftype[i] = rooms[ri]["f"]
				room_of[i] = ri
	var doors := [[11, 16], [12, 16], [13, 16], [26, 7], [26, 8], [26, 9], [45, 16], [46, 16], [47, 16], [33, 7], [33, 8], [33, 9],
		[11, 23], [12, 23], [13, 23], [26, 30], [26, 31], [26, 32], [45, 23], [46, 23], [47, 23], [33, 30], [33, 31], [33, 32],
		[59, 18], [59, 19], [59, 20], [59, 21], [59, 7], [59, 8], [59, 30], [59, 31], [29, 39], [30, 39]]
	for d in doors:
		var i: int = d[1] * COLS + d[0]
		grid[i] = 1
		ftype[i] = F_DOOR
		room_of[i] = ROOM_CH if d[0] == 59 else ROOM_CV
	# klassrum: bänkar och platser (platsen ligger precis ovanför bänken)
	for r in [5, 8, 11]:
		for x in [4, 8, 12, 16, 20]:
			_furn(x, r, 2, 1, "desk")
			seats[0].append(Vector2((x + 1) * T, r * T - 12))
		for x in [37, 41, 45, 49, 53]:
			_furn(x, r, 2, 1, "desk")
			seats[1].append(Vector2((x + 1) * T, r * T - 12))
	_furn(11, 2, 3, 1, "tdesk")
	_furn(44, 2, 3, 1, "tdesk")
	teacher_spot[ROOM_7A] = Vector2(12.5 * T, 3 * T + 16)
	teacher_spot[ROOM_8B] = Vector2(45.5 * T, 3 * T + 16)
	teacher_spot[ROOM_GYM] = Vector2(46 * T, 26 * T)
	class_door[ROOM_7A] = Vector2(12.5 * T, 15 * T + 20)
	class_door[ROOM_8B] = Vector2(46.5 * T, 15 * T + 20)
	class_door[ROOM_GYM] = Vector2(46.5 * T, 24 * T + 20)
	# matsal
	for r in [28, 32, 36]:
		for x in [4, 14]:
			_furn(x, r, 7, 1, "table")
			for k in 3:
				lunch_spots.append(Vector2((x + 1 + k * 2) * T + 20, r * T - 12))
	_furn(16, 24, 7, 1, "counter")
	counter_spot = Vector2(19.5 * T, 25 * T + 20)
	# idrottssal
	_furn(36, 37, 5, 1, "bench")
	_furn(52, 37, 5, 1, "bench")
	# expedition & rektor
	_furn(28, 1, 4, 1, "exp")
	exp_spot = Vector2(30 * T, 2 * T + 22)
	_furn(28, 42, 4, 1, "rdesk")
	rektor_spot = Vector2(30 * T, 43 * T + 18)
	office_spot = Vector2(30 * T, 40 * T + 26)
	# skolgård
	pitch = Rect2(63 * T, 3 * T, 24 * T, 17 * T)
	_furn(66, 24, 4, 1, "bench")
	_furn(78, 24, 4, 1, "bench")
	for tr in [[62, 28], [87, 28], [62, 42], [87, 42], [70, 39], [80, 39]]:
		_furn(tr[0], tr[1], 1, 1, "tree")
		trees.append(Vector2(tr[0] * T + 20, tr[1] * T + 20))
	bench_spot = Vector2(75 * T, 33 * T - 6)
	cam_spots = {
		"Korridoren": [Vector2(28 * T + 6, 17 * T - 10), Vector2(8 * T, 17 * T - 10), Vector2(50 * T, 17 * T - 10)],
		"Matsalen": [Vector2(2 * T, 24 * T - 10)],
		"Idrottssalen": [Vector2(35 * T, 24 * T - 10)],
		"Skolgården": [Vector2(60 * T + 10, 2 * T)],
	}
	# A*
	astar.region = Rect2i(0, 0, COLS, ROWS)
	astar.cell_size = Vector2(T, T)
	astar.offset = Vector2(T / 2.0, T / 2.0)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in ROWS:
		for x in COLS:
			if grid[y * COLS + x] != 1:
				astar.set_point_solid(Vector2i(x, y), true)
	queue_redraw()


func _furn(x: int, y: int, w: int, h: int, kind: String) -> void:
	furn.append({"x": x, "y": y, "w": w, "h": h, "k": kind})
	for j in range(y, y + h):
		for i in range(x, x + w):
			grid[j * COLS + i] = 2


# ---------------- frågor om kartan ----------------
func walkable(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < COLS and y < ROWS and grid[y * COLS + x] == 1


func tile_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(floor(p.x / T)), 0, COLS - 1), clampi(int(floor(p.y / T)), 0, ROWS - 1))


func walkable_pos(p: Vector2) -> bool:
	if p.x < 0 or p.y < 0 or p.x >= WW or p.y >= WH:
		return false
	var t := tile_of(p)
	return walkable(t.x, t.y)


func nearest_walkable(t: Vector2i) -> Vector2i:
	if walkable(t.x, t.y):
		return t
	for r in range(1, 5):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if walkable(t.x + dx, t.y + dy):
					return Vector2i(t.x + dx, t.y + dy)
	return Vector2i(-1, -1)


func find_path(from: Vector2, to: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var a := nearest_walkable(tile_of(from))
	var b := nearest_walkable(tile_of(to))
	if a.x < 0 or b.x < 0:
		return out
	var pts := astar.get_point_path(a, b)
	for i in pts.size():
		if i == 0 and pts.size() > 1:
			continue
		out.append(pts[i])
	if walkable_pos(to):
		out.append(to)
	return out


func room_at(p: Vector2) -> int:
	var t := tile_of(p)
	return room_of[t.y * COLS + t.x]


func room_name(ri: int) -> String:
	if ri < 0 or ri >= rooms.size():
		return "Korridoren"
	return rooms[ri]["name"]


func random_point(ri: int) -> Vector2:
	var r: Rect2i = rooms[ri]["r"]
	for k in 80:
		var x := r.position.x + randi() % r.size.x
		var y := r.position.y + randi() % r.size.y
		if walkable(x, y):
			return Vector2(x * T + T / 2.0, y * T + T / 2.0)
	return Vector2(30 * T, 19 * T)


func has_camera(ri: int) -> bool:
	return GS.upgrades["cameras"].has(room_name(ri))


# ---------------- ritning ----------------
func _draw() -> void:
	var font := ThemeDB.fallback_font
	for y in ROWS:
		for x in COLS:
			var i := y * COLS + x
			var px := x * T
			var py := y * T
			if grid[i] == 0:
				_draw_wall(x, y, px, py)
				continue
			match ftype[i]:
				F_CORR:
					draw_rect(Rect2(px, py, T, T), Color("1f1f23"))
					draw_rect(Rect2(px + 1, py + 1, T - 2, T - 2), Color("151518"), false, 2.0)
				F_WOOD:
					draw_rect(Rect2(px, py, T, T), Color("3b2822"))
					for k in 4:
						draw_rect(Rect2(px, py + k * 10 + 9, T, 1), Color("2e1e19"))
					draw_rect(Rect2(px + ((x * 13 + y * 7) % T), py, 1, T), Color("2e1e19"))
				F_CHECK:
					draw_rect(Rect2(px, py, T, T), Color("2c2c31") if (x + y) % 2 == 1 else Color("1e1e22"))
				F_GYM:
					draw_rect(Rect2(px, py, T, T), Color("6a4028"))
					for k in 4:
						draw_rect(Rect2(px, py + k * 10, T, 1), Color("5a351f"))
				F_GRASS:
					draw_rect(Rect2(px, py, T, T), Color("2f6b2a") if (x * 7 + y * 3) % 5 != 0 else Color("2a6026"))
				F_OFFICE:
					draw_rect(Rect2(px, py, T, T), Color("4a1018"))
				_:
					draw_rect(Rect2(px, py, T, T), Color("2a2a2f"))
	# korridorens röda linjer
	draw_rect(Rect2(T, 20 * T - 3, 58 * T, 6), Color(0.78, 0.06, 0.18, 0.35))
	draw_rect(Rect2(30 * T - 3, T, 6, 38 * T), Color(0.78, 0.06, 0.18, 0.35))
	# idrottssal-linjer
	var g := Rect2(34 * T, 24 * T, 25 * T, 15 * T)
	draw_rect(g.grow(-30), Color(1, 1, 1, 0.35), false, 3.0)
	draw_line(Vector2(g.get_center().x, g.position.y + 30), Vector2(g.get_center().x, g.end.y - 30), Color(1, 1, 1, 0.35), 3.0)
	draw_arc(g.get_center(), 70, 0, TAU, 40, Color(1, 1, 1, 0.35), 3.0)
	# fotbollsplan
	draw_rect(pitch, Color(1, 1, 1, 0.8), false, 4.0)
	draw_line(Vector2(pitch.get_center().x, pitch.position.y), Vector2(pitch.get_center().x, pitch.end.y), Color(1, 1, 1, 0.8), 3.0)
	draw_arc(pitch.get_center(), 60, 0, TAU, 40, Color(1, 1, 1, 0.8), 3.0)
	var cy := pitch.get_center().y
	draw_rect(Rect2(pitch.position.x - 18, cy - 60, 18, 120), Color(1, 1, 1, 0.9), false, 4.0)
	draw_rect(Rect2(pitch.end.x, cy - 60, 18, 120), Color(1, 1, 1, 0.9), false, 4.0)
	draw_rect(Rect2(pitch.position.x - 18, cy - 60, 18, 120), Color(1, 1, 1, 0.15))
	draw_rect(Rect2(pitch.end.x, cy - 60, 18, 120), Color(1, 1, 1, 0.15))
	# rumsnamn på golvet
	for ri in [0, 1, 2, 3, 6]:
		var r: Rect2i = rooms[ri]["r"]
		var c := Vector2((r.position.x + r.size.x / 2.0) * T, (r.position.y + r.size.y / 2.0) * T)
		if ri == ROOM_YARD:
			c.y = 31 * T
		var name_up: String = String(rooms[ri]["name"]).to_upper()
		draw_string(font, Vector2(c.x - 600, c.y + 20 + (90 if ri < 2 else 0)), name_up, HORIZONTAL_ALIGNMENT_CENTER, 1200, 60, Color(1, 1, 1, 0.07))
	# tavlor och skyltar
	_board(Vector2(6 * T, 8), 13 * T, "VI MOBBAR INTE")
	_board(Vector2(39 * T, 8), 13 * T, "VAR EN SCHYSST KOMPIS")
	_sign(Vector2(28 * T, 12), 4 * T, "EXPEDITION")
	_sign(Vector2(3 * T, 23 * T + 14), 6 * T, "MATSALEN")
	_sign(Vector2(51 * T, 23 * T + 14), 6 * T, "IDROTTSSALEN")
	_sign(Vector2(18 * T, 16 * T + 14), 6 * T, "KLASSRUM 7A")
	_sign(Vector2(36 * T, 16 * T + 14), 6 * T, "KLASSRUM 8B")
	_sign(Vector2(27 * T, 39 * T + 14), 6 * T, "REKTOR")
	for f in furn:
		_draw_furn(f)
	if GS.upgrades["bench"]:
		draw_rect(Rect2(bench_spot.x - 70, bench_spot.y + 10, 140, 16), Color("3a2414"))
		draw_rect(Rect2(bench_spot.x - 70, bench_spot.y + 4, 140, 10), Color("c8102e"))
		draw_string(font, Vector2(bench_spot.x - 70, bench_spot.y + 44), "KOMPISBÄNK", HORIZONTAL_ALIGNMENT_CENTER, 140, 14, Color.WHITE)


func _draw_wall(x: int, y: int, px: int, py: int) -> void:
	draw_rect(Rect2(px, py, T, T), Color("0a0a0c"))
	if x >= 60 and y > 0 and y < ROWS - 1 and x < COLS - 1:
		draw_rect(Rect2(px, py, T, T), Color("1a1a1a"))
	if y + 1 < ROWS and grid[(y + 1) * COLS + x] != 0:
		var fb := ftype[(y + 1) * COLS + x]
		if fb == F_GRASS:
			draw_rect(Rect2(px, py + T - 14, T, 14), Color("555559"))
			return
		draw_rect(Rect2(px, py + T - 16, T, 16), Color("1c1c21"))
		draw_rect(Rect2(px, py + T - 18, T, 2), GS.RED)
		if fb == F_CORR:
			for k in 2:
				draw_rect(Rect2(px + 2 + k * 19, py + T - 15, 17, 14), Color("8a0c1e") if k == 1 else Color("a50f25"))
				draw_rect(Rect2(px + 4 + k * 19, py + T - 13, 13, 1), Color(0, 0, 0, 0.4))
				draw_rect(Rect2(px + 15 + k * 19, py + T - 8, 2, 3), Color("dddddd"))
	if x + 1 < COLS and grid[y * COLS + x + 1] != 0 and ftype[y * COLS + x + 1] == F_CORR:
		draw_rect(Rect2(px + T - 7, py, 7, T), Color("8a0c1e"))
	if x > 0 and grid[y * COLS + x - 1] != 0 and ftype[y * COLS + x - 1] == F_CORR:
		draw_rect(Rect2(px, py, 7, T), Color("8a0c1e"))


func _board(pos: Vector2, w: float, txt: String) -> void:
	draw_rect(Rect2(pos.x - 3, pos.y - 3, w + 6, 32), Color("777777"))
	draw_rect(Rect2(pos.x, pos.y, w, 26), Color("eeeeee"))
	draw_string(ThemeDB.fallback_font, Vector2(pos.x, pos.y + 20), txt, HORIZONTAL_ALIGNMENT_CENTER, w, 17, GS.RED)


func _sign(pos: Vector2, w: float, txt: String) -> void:
	draw_rect(Rect2(pos.x, pos.y, w, 24), GS.RED)
	draw_string(ThemeDB.fallback_font, Vector2(pos.x, pos.y + 18), txt, HORIZONTAL_ALIGNMENT_CENTER, w, 14, Color.WHITE)


func _draw_furn(f: Dictionary) -> void:
	var x: float = f["x"] * T
	var y: float = f["y"] * T
	var w: float = f["w"] * T
	var h: float = f["h"] * T
	match f["k"]:
		"desk":
			draw_rect(Rect2(x + 3, y + 8, w - 6, h - 10), Color("4a3022"))
			draw_rect(Rect2(x + 3, y + 4, w - 6, h - 14), Color("7a5440"))
			draw_rect(Rect2(x + 12, y + 10, 14, 10), Color("eeeeee"))
			draw_rect(Rect2(x + 50, y + 12, 12, 3), GS.GOLD)
		"tdesk", "exp", "rdesk":
			draw_rect(Rect2(x + 2, y + 8, w - 4, h - 8), Color("2a1a12"))
			draw_rect(Rect2(x + 2, y + 4, w - 4, h - 14), Color("5a3a2a"))
			draw_rect(Rect2(x + w / 2 - 14, y + 8, 28, 16), Color("333333"))
			draw_rect(Rect2(x + w / 2 - 12, y + 10, 24, 10), Color("66ccff"))
		"table":
			draw_rect(Rect2(x + 2, y + 6, w - 4, h - 4), Color("2b2b30"))
			draw_rect(Rect2(x + 2, y + 3, w - 4, h - 12), Color("55555c"))
			for k in int(f["w"]):
				draw_rect(Rect2(x + k * T + 8, y + 8, 24, 14), GS.RED)
				draw_circle(Vector2(x + k * T + 20, y + 15), 5, Color.WHITE)
				draw_circle(Vector2(x + k * T + 20, y + 15), 3, [Color("f2a03d"), Color("6ab04c"), Color("e0d080")][k % 3])
		"counter":
			draw_rect(Rect2(x, y + 4, w, h - 4), Color("2b2b2f"))
			draw_rect(Rect2(x, y + 2, w, 12), Color("8d8d95"))
			for k in int(f["w"]):
				draw_rect(Rect2(x + k * T + 6, y + 16, 28, 16), [Color("e0a040"), Color("d84040"), Color("60b050"), Color("e8d070")][k % 4])
		"bench":
			draw_rect(Rect2(x + 2, y + 18, w - 4, 16), Color("3a2414"))
			draw_rect(Rect2(x + 2, y + 12, w - 4, 10), Color("8a5a34"))
		"tree":
			draw_circle(Vector2(x + 20, y + 30), 10, Color(0, 0, 0, 0.3))
			draw_rect(Rect2(x + 16, y + 18, 8, 18), Color("5a3a1a"))
			draw_circle(Vector2(x + 20, y + 10), 22, Color("1f5a1c"))
			draw_circle(Vector2(x + 14, y + 4), 12, Color("2f7a2a"))
