extends Node
var main
var step := 0
var frames := 0
var log_lines: Array = []
func L(s): print("[TEST] ", s)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var ss = main.get_node("StartScreen")
	ss.name_in.text = "Testa"
	ss._start()
	await wait(60)
	L("started students=%d adults=%d" % [main.students.size(), main.adults.size()])
	# unique looks check
	var keys := {}
	for n in main.students + main.adults:
		var k = "%s-%s-%s-%s" % [n.look["skin"], n.look["style"], n.look["hair"], n.look["shirt"]]
		if keys.has(k): L("DUPLICATE LOOK " + k)
		keys[k] = true
	L("rastvakter vest roles: %s" % str(main.adults.filter(func(a): return a.role == "rastvakt").size()))
	await wait(200)
	# ---- conflict ----
	GS.sched.running = false
	GS.sched._start_break(false)
	await wait(30)
	var ok = false
	for i in 20:
		if GS.cm.spawn(): ok = true; break
	L("spawned conflict: %s" % ok)
	var c = GS.cm.conflicts[0]
	for i in 3000:
		await get_tree().process_frame
		if c.state == "active": break
	L("conflict state after gather: %s" % c.state)
	main.player.position = c.pos + Vector2(-90, 0)
	await wait(5)
	L("wheel open: %s options=%d pages=%d" % [GS.wheel.is_open(), c.options.size(), GS.wheel._pages()])
	GS.wheel._next_page()
	await wait(2)
	# choose a good option that will fail -> body
	var seed_fail := func(): pass
	var gid = ""
	for id in c.options:
		if Data.OPT.has(id) and Data.OPT[id]["k"] != "bad": gid = id; break
	GS.wheel.close()
	GS.cm._attempt(c, -1.0, "words")
	await wait(120)
	L("after failed words: state=%s" % c.state)
	main.player.position = c.pos
	await wait(200)
	L("after body: state=%s coins=%d stopped=%d" % [c.state, GS.coins, GS.stopped])
	await wait(400)
	# ---- custom text ----
	GS.sched.running = false
	GS.sched._start_break(false)
	await wait(60)
	for n in main.students: n.cool = 0
	for i in 20:
		if GS.cm.spawn(): break
	var c2 = GS.cm.conflicts[-1]
	for i in 3000:
		await get_tree().process_frame
		if c2.state == "active": break
	main.player.position = c2.pos + Vector2(-90, 0)
	await wait(5)
	L("wheel2 open %s" % GS.wheel.is_open())
	GS.wheel.line.text = "Ni är dumma idioter"
	GS.wheel._say()
	await wait(60)
	L("bad custom -> bonus=%d omdome=%.1f" % [c2.bonus, GS.omdome])
	await wait(200)
	c2.cool = 0
	main.player.position = c2.pos + Vector2(-90, 0)
	await wait(5)
	L("wheel reopened %s" % GS.wheel.is_open())
	GS.wheel.close()
	# fetch adult
	GS.cm._fetch(c2)
	var ad = main.player_task.get("adult")
	L("fetch task adult=%s" % (ad.display_name if ad else "none"))
	main.player.position = ad.position + Vector2(30, 0)
	await wait(10)
	L("adult state=%s helper=%s" % [ad.state, c2.helper != null])
	for i in 3000:
		await get_tree().process_frame
		if c2.state != "active" and c2.state != "body": break
	L("after adult: c2=%s coins=%d" % [c2.state, GS.coins])
	await wait(200)
	# ---- shop ----
	GS.coins = 200
	GS.shop.open()
	GS.shop._buy("rastvakt", 40)
	GS.shop._buy("cam:Matsalen", 30)
	GS.shop._buy("bench", 20)
	GS.shop.close_shop()
	L("after shop coins=%d adults=%d cams=%s" % [GS.coins, main.adults.size(), str(GS.upgrades["cameras"])])
	# ---- friends ----
	var s = main.students[0]
	for i in 3:
		s.talked = false
		main._talk_pick(s, "Hej! Hur är det?")
	L("friend: %s friends=%d" % [s.is_friend, GS.friend_count()])
	# ---- lesson late ----
	GS.sched.running = true
	GS.cm.end_all()
	GS.sched.minute = 8.0
	await wait(30)
	L("bell=%s period=%s" % [GS.sched.bell, GS.sched.period_text()])
	main.player.teleport(GS.map.random_point(GS.map.ROOM_YARD))
	GS.sched.minute = 15.0
	await wait(30)
	L("period now %s arrived=%s" % [GS.sched.current()["name"], GS.sched.L.get("arrived")])
	main.player.teleport(main.player.seat_pos + Vector2(0, 40))
	await wait(10)
	L("dialog showing=%s modal=%d title=%s" % [GS.dialog.showing, GS.modal_count, GS.dialog.title_l.text])
	GS.dialog._pick(0)
	await wait(10)
	L("absence=%d grade=%s omdome=%s health=%d" % [GS.absence, GS.grade_letter(), GS.omdome_text(), GS.health])
	main.player.teleport(main.player.seat_pos)
	await wait(600)
	L("sitting=%s quiz visible=%s rb=%s" % [main.player.sitting, GS.quiz.root.visible, str(GS.sched.L.get("rb"))])
	if GS.quiz.root.visible:
		for q in 5:
			if not GS.quiz.root.visible: break
			GS.quiz._answer(GS.quiz.correct_idx)
			GS.quiz._next()
			await wait(2)
		L("after quiz grade=%s coins=%d" % [GS.grade_letter(), GS.coins])
	await wait(1500)
	var rb = GS.sched.L.get("rb")
	L("rule breaker: %s" % (rb.display_name + " " + rb.rule_break if rb else "none"))
	if rb:
		main.player.teleport(rb.position + Vector2(0, -30))
		await wait(3)
		L("hint kind=%s" % main.hint_kind)
		main.interact()
		await wait(10)
		L("rb fixed: omdome=%s coins=%d" % [GS.omdome_text(), GS.coins])
	# disturb
	var om0 = GS.omdome
	main.player.teleport(main.player.seat_pos + Vector2(0, 50))
	await wait(500)
	L("disturb: before=%.1f in_lesson=%s" % [om0, GS.sched.current_type()])
	L("after wandering in class omdome=%.1f" % GS.omdome)
	# ---- skolk whole lesson -> absence + rektor ----
	main.player.teleport(GS.map.random_point(GS.map.ROOM_YARD))
	GS.absence = 2
	GS.sched.minute = 49.5
	await wait(60)
	L("after skipping: absence=%d rektor_level=%d dialog=%s" % [GS.absence, GS.rektor_level, GS.dialog.title_l.text])
	if GS.dialog.showing: GS.dialog._pick(0)
	await wait(10)
	L("player room=%s" % GS.map.room_name(GS.map.room_at(main.player.position)))
	# ---- phone ----
	GS.phone.start_incident()
	GS.phone.toggle()
	await wait(400)
	L("phone msgs=%d open=%s" % [GS.phone.log_box.get_child_count(), GS.phone.is_open])
	GS.phone._choose("shot")
	L("need adult=%s" % GS.phone.need_adult)
	var ad2 = main.adults[0]
	main.player.teleport(ad2.position + Vector2(30, 0))
	await wait(5)
	L("hint=%s" % main.hint_kind)
	main.interact()
	await wait(5)
	L("phone resolved need=%s coins=%d" % [GS.phone.need_adult, GS.coins])
	GS.phone.toggle()
	# ---- lonely ----
	await wait(100)
	var lon = main.students.filter(func(n): return n.state == "lonely")
	L("lonely count=%d" % lon.size())
	# ---- end of day ----
	GS.sched.minute = 324.0
	await wait(120)
	L("end dialog=%s showing=%s" % [GS.dialog.title_l.text, GS.dialog.showing])
	if GS.dialog.showing: GS.dialog._pick(0)
	await wait(60)
	L("day=%d clock=%s" % [GS.day, GS.sched.clock_text()])
	# suspension
	GS.absence = 4
	GS.sched.add_absence("test")
	await wait(10)
	L("suspend dialog=%s" % GS.dialog.title_l.text)
	if GS.dialog.showing: GS.dialog._pick(0)
	await wait(10)
	if GS.dialog.showing: L("next: " + GS.dialog.title_l.text); GS.dialog._pick(0)
	await wait(100)
	L("after suspension absence=%d day=%d" % [GS.absence, GS.day])
	# run long to catch random errors
	for i in 6:
		await wait(1500)
		L("t=%s %s conflicts=%d" % [GS.sched.clock_text(), GS.sched.current()["name"], GS.cm.conflicts.size()])
		if GS.dialog.showing: GS.dialog._pick(0)
		if GS.quiz.root.visible: GS.quiz._answer(0); GS.quiz._next()
	L("DONE")
	get_tree().quit()

func wait(n):
	for i in n:
		await get_tree().process_frame
