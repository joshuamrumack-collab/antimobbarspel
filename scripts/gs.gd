extends Node
## GS = Game State (autoload). Håller spelarens värden, referenser till
## alla system och hjälpfunktioner som delas av hela spelet.

signal stats_changed
signal toast_requested(text: String, kind: String, secs: float)

const T := 40
const RED := Color("c8102e")
const DARK_RED := Color("8a0c1e")
const GOLD := Color("ffd23f")
const VEST := Color("f5e300")

const SKINS := [Color("f8d9bd"), Color("eab88f"), Color("d09a6a"), Color("a8703f"), Color("7a4a27"), Color("4e2f1a")]
const HAIRS := [Color("151515"), Color("4a2f1c"), Color("8a5428"), Color("e2c06c"), Color("c8102e"), Color("e6e6e6"), Color("2b4fa0")]
const STYLES := ["kort", "lang", "tofs", "lockigt", "keps", "rakad", "bob"]
const STYLE_NAMES := ["Kort", "Långt", "Tofs", "Lockigt", "Keps", "Rakat", "Page"]
const SHIRTS := [Color("c8102e"), Color("111111"), Color("f0f0f0"), Color("5a5a5f"), Color("2b5cb8"), Color("2e8b57"), Color("f0a500"), Color("7b3fa0"), Color("e86aa6"), Color("17a2b8")]
const PANTS := [Color("1b1b1f"), Color("2d3e66"), Color("4a4a4f"), Color("5b3a29"), Color("7a0c1c")]
const ACCS := ["", "glasogon", "pannband", "frakner", "orhangen"]
const ACC_NAMES := ["Inget", "Glasögon", "Pannband", "Fräknar", "Örhängen"]

# --- referenser (sätts av Main) ---
var main: Node
var map: Node
var player: Node
var hud: Node
var cm: Node
var sched: Node
var wheel: Node
var dialog: Node
var quiz: Node
var shop: Node
var phone: Node
var help: Node
var overlay: Node
var ball: Node

# --- spelarens värden ---
var t := 0.0
var started := false
var coins := 0
var grade := 55.0      # 0-100 -> betyg F-A
var omdome := 55.0     # 0-100 -> omdöme
var health := 100.0    # 0-100
var absence := 0       # olovlig frånvaro
var stopped := 0
var missed := 0
var day := 0
var rektor_level := 0
var player_name := "Spelaren"
var upgrades := {"rastvakter": 0, "cameras": [], "posters": false, "bench": false}
var ui_block := false
var modal_count := 0
var used_looks := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("move_up", [KEY_W, KEY_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN])
	_add_action("interact", [KEY_E])
	_add_action("shop", [KEY_B])
	_add_action("phone", [KEY_F])
	_add_action("help", [KEY_H])
	_add_action("cancel", [KEY_ESCAPE])


func _process(delta: float) -> void:
	t += delta


func _add_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


# ---------------- betyg / omdöme / hälsa ----------------
func grade_letter() -> String:
	if grade >= 85: return "A"
	if grade >= 70: return "B"
	if grade >= 55: return "C"
	if grade >= 40: return "D"
	if grade >= 20: return "E"
	return "F"


func omdome_text() -> String:
	if omdome >= 80: return "Mycket bra"
	if omdome >= 60: return "Bra"
	if omdome >= 40: return "Godtagbart"
	if omdome >= 20: return "Behöver förbättras"
	return "Oroande"


func change(dg: float, dom: float, dh: float) -> void:
	grade = clampf(grade + dg, 0.0, 100.0)
	omdome = clampf(omdome + dom, 0.0, 100.0)
	health = clampf(health + dh, 0.0, 100.0)
	stats_changed.emit()
	if health <= 0.0 and sched != null:
		sched.call_deferred("health_out")


func add_coins(n: int) -> void:
	coins += n
	stats_changed.emit()
	if overlay != null and player != null:
		overlay.float_text(player.position + Vector2(0, -60), "+%d coins" % n, GOLD)


func spend(n: int) -> bool:
	if coins < n:
		return false
	coins -= n
	stats_changed.emit()
	return true


func friend_count() -> int:
	if main == null:
		return 0
	var c := 0
	for n in main.students:
		if n.is_friend:
			c += 1
	return c


func toast(text: String, kind: String = "info", secs: float = 4.0) -> void:
	toast_requested.emit(text, kind, secs)


# ---------------- paus för dialogrutor ----------------
func push_modal() -> void:
	modal_count += 1
	get_tree().paused = true


func pop_modal() -> void:
	modal_count = maxi(0, modal_count - 1)
	if modal_count == 0 and started:
		get_tree().paused = false


# ---------------- unika utseenden ----------------
func look_key(skin: int, style: int, hair: int, shirt: int) -> String:
	return "%d-%d-%d-%d" % [skin, style, hair, shirt]


func register_look(skin: int, style: int, hair: int, shirt: int) -> void:
	used_looks[look_key(skin, style, hair, shirt)] = true


## Ger ett utseende som ingen annan har (hudfärg + frisyr + hårfärg + tröja är unikt).
func make_look(adult: bool = false) -> Dictionary:
	for i in 600:
		var s := randi() % SKINS.size()
		var hs := randi() % STYLES.size()
		var hc := randi() % HAIRS.size()
		var sh := randi() % SHIRTS.size()
		var key := look_key(s, hs, hc, sh)
		if used_looks.has(key):
			continue
		used_looks[key] = true
		return {
			"skin": SKINS[s], "style": STYLES[hs], "hair": HAIRS[hc], "shirt": SHIRTS[sh],
			"pants": PANTS[randi() % PANTS.size()], "acc": ACCS[randi() % ACCS.size()],
			"beard": adult and randf() < 0.35,
		}
	return {"skin": SKINS[0], "style": "kort", "hair": HAIRS[0], "shirt": SHIRTS[0], "pants": PANTS[0], "acc": "", "beard": false}


# ---------------- gemensamt UI-tema (rött & svart) ----------------
func make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 17
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.03, 0.03, 0.04, 0.95)
	panel.border_color = RED
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(12)
	panel.set_content_margin_all(14)
	th.set_stylebox("panel", "PanelContainer", panel)
	var bn := StyleBoxFlat.new()
	bn.bg_color = RED
	bn.set_corner_radius_all(10)
	bn.content_margin_left = 14
	bn.content_margin_right = 14
	bn.content_margin_top = 8
	bn.content_margin_bottom = 8
	var bh: StyleBoxFlat = bn.duplicate()
	bh.bg_color = Color("e3253f")
	var bp: StyleBoxFlat = bn.duplicate()
	bp.bg_color = DARK_RED
	var bd: StyleBoxFlat = bn.duplicate()
	bd.bg_color = Color("333336")
	th.set_stylebox("normal", "Button", bn)
	th.set_stylebox("hover", "Button", bh)
	th.set_stylebox("pressed", "Button", bp)
	th.set_stylebox("disabled", "Button", bd)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", Color.WHITE)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color(0.7, 0.7, 0.7))
	th.set_color("font_color", "Label", Color.WHITE)
	var le := StyleBoxFlat.new()
	le.bg_color = Color("111114")
	le.border_color = Color("555555")
	le.set_border_width_all(2)
	le.set_corner_radius_all(8)
	le.set_content_margin_all(10)
	var lef: StyleBoxFlat = le.duplicate()
	lef.border_color = RED
	th.set_stylebox("normal", "LineEdit", le)
	th.set_stylebox("focus", "LineEdit", lef)
	th.set_color("font_color", "LineEdit", Color.WHITE)
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color("222226")
	pb_bg.set_corner_radius_all(6)
	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = Color("2ecc71")
	pb_fill.set_corner_radius_all(6)
	th.set_stylebox("background", "ProgressBar", pb_bg)
	th.set_stylebox("fill", "ProgressBar", pb_fill)
	th.set_color("font_color", "ProgressBar", Color.WHITE)
	return th
