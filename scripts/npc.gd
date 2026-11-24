extends Character
## Elever och vuxna som styrs av datorn.

var klass := ""                 # "7A" / "8B" för elever
var seat := Vector2.ZERO
var state := "idle"             # idle, walk, seat, eat, lonely, football, conflict, respond, teach, rb, follow, static
var then_state := "idle"
var run := false
var idle_t := 0.0
var zone: Array = []            # rum där vuxna patrullerar
var on_duty := true
var rule_break := ""            # elev: phone/skolk, vuxen: phone/coffee/chat
var conflict = null
var friend_pts := 0
var is_friend := false
var talked := false
var activity := "wander"        # wander, football, lunch, lonely, lesson, gym, follow
var team := 0
var kick_cd := 0.0
var respond_c = null
var cool := 0.0
var lesson_room := -1
var is_static := false
var lonely_say_t := 4.0


func is_adult() -> bool:
	return role != "student"


func walk_to(p: Vector2, st: String, fast: bool = false) -> void:
	go_to(p)
	state = "walk"
	then_state = st
	run = fast


func _process(delta: float) -> void:
	moving = false
	if cool > 0.0:
		cool -= delta
	kick_cd -= delta
	match state:
		"walk":
			if follow_path(delta, speed * (1.6 if run else 1.0)):
				state = then_state
				_arrived()
		"idle":
			idle_t -= delta
			if idle_t <= 0.0:
				_next_idle()
		"football":
			_football(delta)
		"respond":
			if respond_c == null or respond_c.dead:
				respond_c = null
				state = "idle"
				idle_t = 1.0
			elif follow_path(delta, speed * 1.9) or position.distance_to(respond_c.pos) < 44.0:
				path.clear()
				GS.cm.helper_arrived(self)
		"lonely":
			sad = 1.0
			lonely_say_t -= delta
			if lonely_say_t <= 0.0:
				lonely_say_t = randf_range(6.0, 11.0)
				say(Data.LONELY.pick_random(), 2.2)
		"follow":
			var target: Vector2 = GS.player.position + Vector2(-34 * GS.player.facing, 6)
			var d := position.distance_to(target)
			if d > 60.0 and path.is_empty():
				go_to(target)
			if d > 30.0:
				follow_path(delta, 160.0)
			else:
				path.clear()
			happy = 1.0
		"teach":
			facing = 0.0
	sitting = state in ["seat", "eat"]
	tick_base(delta)


func _arrived() -> void:
	match state:
		"seat":
			position = seat
			facing = 0.0
		"eat":
			facing = 0.0
		"lonely":
			facing = 0.0
		"skolk_out":
			GS.sched.on_skolk_escaped(self)
		"rb":
			if rule_break == "phone":
				holding_phone = true
		"teach":
			facing = 0.0
		"idle":
			idle_t = randf_range(2.0, 6.0)


func _next_idle() -> void:
	idle_t = randf_range(2.5, 6.0)
	if is_static:
		return
	var m = GS.map
	if is_adult():
		if zone.is_empty():
			return
		go_to(m.random_point(zone.pick_random()))
		state = "walk"
		then_state = "idle"
		return
	match activity:
		"gym":
			walk_to(m.random_point(m.ROOM_GYM), "idle")
		"wander":
			var rooms: Array = [m.ROOM_CH, m.ROOM_CV, m.ROOM_YARD, m.ROOM_YARD, m.ROOM_MAT]
			walk_to(m.random_point(rooms.pick_random()), "idle")
			if randf() < 0.25 and _visible():
				say(Data.AMB.pick_random().replace("{n}", GS.player_name), 2.4)
		_:
			pass


func _visible() -> bool:
	return GS.player != null and position.distance_to(GS.player.position) < 600.0


func _football(delta: float) -> void:
	var ball = GS.ball
	if ball == null or not ball.visible:
		return
	var pitch: Rect2 = GS.map.pitch
	var spread := Vector2(cos(seed_f) * 70.0, sin(seed_f * 1.7) * 80.0)
	var target: Vector2 = ball.position + Vector2(-16.0 if team == 0 else 16.0, 0)
	if position.distance_to(ball.position) > 110.0 or fmod(seed_f, 3.0) < 1.0:
		target = ball.position + spread * 0.7
	target = target.clamp(pitch.position + Vector2(12, 12), pitch.end - Vector2(12, 12))
	var d := position.distance_to(target)
	if d > 4.0:
		var dir := (target - position) / d
		position += dir * minf(d, 100.0 * delta)
		moving = true
		if absf(dir.x) > 0.2:
			facing = signf(dir.x)
	if position.distance_to(ball.position) < 18.0 and kick_cd <= 0.0:
		kick_cd = 0.7
		var goal := Vector2(pitch.end.x + 10.0 if team == 0 else pitch.position.x - 10.0, pitch.get_center().y)
		ball.kick((goal - ball.position).normalized().rotated(randf_range(-0.5, 0.5)) * randf_range(220.0, 340.0))


func lonely_reset() -> void:
	if activity == "lonely" or activity == "follow":
		activity = "wander"
	sad = 0.0


# ---------------- vuxna ----------------
func go_lesson(p: Dictionary) -> void:
	if is_static:
		return
	if rule_break != "":
		fix_rule_break()
	on_duty = true
	respond_c = null
	var r: int = p["room"]
	if role == "teacher" and (lesson_room == r or lesson_room == GS.map.ROOM_8B):
		var spot: Vector2 = GS.map.teacher_spot[lesson_room]
		if position.distance_to(GS.player.position) > 800.0 and spot.distance_to(GS.player.position) > 800.0:
			path.clear()
			position = spot
			state = "teach"
		else:
			walk_to(spot, "teach", true)
	else:
		state = "idle"
		idle_t = randf_range(0.2, 2.0)


func go_break() -> void:
	if is_static:
		return
	if rule_break != "":
		fix_rule_break()
	on_duty = true
	respond_c = null
	state = "idle"
	idle_t = randf_range(0.2, 2.0)


func start_rule_break() -> void:
	rule_break = ["phone", "coffee", "chat"].pick_random()
	on_duty = false
	match rule_break:
		"phone":
			path.clear()
			state = "rb"
			holding_phone = true
		"coffee":
			walk_to(GS.map.exp_spot + Vector2(randf_range(-40, 40), 34), "rb")
		"chat":
			var others: Array = GS.main.adults.filter(func(a): return a != self and a.role != "rektor")
			var o = others.pick_random()
			walk_to(o.position + Vector2(30, 0), "rb")
	say(Data.RB_ADULT[rule_break], 3.0)


func fix_rule_break() -> void:
	rule_break = ""
	holding_phone = false
	on_duty = true
	state = "idle"
	idle_t = 0.5
