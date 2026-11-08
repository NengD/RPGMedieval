extends SceneTree
## Gros plan des coups d'en haut et d'estoc, sous 2 angles, à 6 instants.
const OUT := "C:/Users/bende/AppData/Local/Temp/claude/1737c38915366fd2/a0d4bad4-af99-45bc-bf90-d212f860c18b/scratchpad/"
var model: HeroModel
var body: Node3D
var cam: Camera3D
var c: Combatant
func _initialize() -> void:
	_run()
func _step() -> void:
	await physics_frame
	await process_frame
	model.drive(1.0 / 120.0, Vector3.ZERO, body.global_basis, true, false, Vector3.ZERO)
func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 150, 0)
	sun.light_energy = 1.5
	world.add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.6, 0.75)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.8)
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	body = Node3D.new()
	world.add_child(body)
	c = Combatant.new()
	c.body = body
	body.add_child(c)
	model = HeroModel.new()
	body.add_child(model)
	cam = Camera3D.new()
	world.add_child(cam)
	cam.current = true
	await process_frame
	model.bind(c)
	for i in 30: await _step()
	var cams := [["arriere", Vector3(1.6, 1.6, 2.6)], ["face", Vector3(-1.8, 1.5, -2.4)]]
	var sheet := Image.create(330 * 6, 380 * 4, false, Image.FORMAT_RGB8)
	var row := 0
	for d in [0, 2]:
		for cdef in cams:
			c.reset()
			model.reset()
			for i in 20: await _step()
			cam.position = cdef[1]
			cam.look_at(Vector3(0, 1.3, 0))
			c.request_attack(d)
			var total: float = (GameConfig.ATTACK_WINDUP[d] + GameConfig.ATTACK_STRIKE[d] + GameConfig.ATTACK_RECOVERY[d]) / c.speed_scale
			var marks := [0.25, 0.5, 0.7, 0.8, 0.9, 1.0]
			var t := 0.0
			var gi := 0
			var windup: float = GameConfig.ATTACK_WINDUP[d]
			var times := [windup * 0.35, windup * 0.75, windup * 0.95, windup + 0.05, windup + 0.15, windup + 0.35]
			while gi < times.size() and t < 3.0:
				await _step()
				t += 1.0 / 120.0
				if t >= times[gi]:
					await process_frame
					var img := root.get_texture().get_image()
					sheet.blit_rect(img.get_region(Rect2i(235, 60, 330, 380)), Rect2i(0, 0, 330, 380), Vector2i(gi * 330, row * 380))
					gi += 1
			print("ligne ", row, " dir ", d, " ", cdef[0])
			row += 1
	sheet.save_png(OUT + "close.png")
	quit()
