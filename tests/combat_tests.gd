extends SceneTree
## Tests de la logique du combat (sans arène). Lancer :
## godot --headless --path . --fixed-fps 120 -s tests/combat_tests.gd

var failures := 0
const S := Combatant.State
const D := Combatant.Dir
const R := Combatant.Result


func _initialize() -> void:
	_run()


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  ÉCHEC ") + label)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _seconds(s: float) -> void:
	await _frames(int(ceil(s * 120.0)))


## Crée un combattant. yaw 0 regarde vers -Z.
func _make(team: int, pos: Vector3, yaw: float) -> Combatant:
	var body := Node3D.new()
	root.add_child(body)
	body.position = pos
	body.rotation.y = yaw
	var c := Combatant.new()
	c.body = body
	c.team = team
	body.add_child(c)
	return c


func _pair() -> Array:
	# A (héros) regarde -Z ; B est à 1,8 m devant lui et le regarde (yaw PI)
	var a := _make(0, Vector3.ZERO, 0.0)
	var b := _make(1, Vector3(0, 0, -1.8), PI)
	return [a, b]


func _cleanup(list: Array) -> void:
	for c in list:
		c.body.queue_free()
	await physics_frame


func _run() -> void:
	print("[Directions]")
	_check(Combatant.mirror(D.LEFT) == D.RIGHT and Combatant.mirror(D.RIGHT) == D.LEFT, "gauche/droite sont inversés pour la parade")
	_check(Combatant.mirror(D.UP) == D.UP and Combatant.mirror(D.DOWN) == D.DOWN, "haut/bas ne changent pas")

	print("[Attaque en 3 temps]")
	var p := _pair()
	var a: Combatant = p[0]
	var b: Combatant = p[1]
	await physics_frame
	_check(a.request_attack(D.RIGHT), "l'attaque démarre")
	_check(a.state == S.WINDUP, "état : préparation")
	_check(is_equal_approx(a.stamina, GameConfig.STAMINA_MAX - GameConfig.ATTACK_STAMINA[D.RIGHT]), "l'endurance est consommée")
	var seen := {}
	var health0 := b.health
	for i in 150:
		await physics_frame
		seen[a.state] = true
	_check(seen.has(S.STRIKE) and seen.has(S.RECOVERY), "passe par coup puis récupération")
	_check(a.state == S.IDLE, "revient à l'état libre")
	_check(b.health < health0, "le coup touche (vie %.0f -> %.0f)" % [health0, b.health])
	_check(is_equal_approx(health0 - b.health, GameConfig.ATTACK_DAMAGE[D.RIGHT]), "dégâts = ceux de la config")
	await _cleanup(p)

	print("[Portée et orientation]")
	var far := _make(0, Vector3.ZERO, 0.0)
	var far_b := _make(1, Vector3(0, 0, -6.0), PI)
	await physics_frame
	far.request_attack(D.RIGHT)
	await _seconds(1.0)
	_check(is_equal_approx(far_b.health, far_b.max_health), "hors de portée : pas de touche")
	await _cleanup([far, far_b])
	var back := _make(0, Vector3.ZERO, 0.0)
	var behind := _make(1, Vector3(0, 0, 1.8), 0.0)
	await physics_frame
	back.request_attack(D.RIGHT)
	await _seconds(1.0)
	_check(is_equal_approx(behind.health, behind.max_health), "dans le dos : pas de touche")
	await _cleanup([back, behind])

	print("[Estoc]")
	var s_a := _make(0, Vector3.ZERO, 0.0)
	var s_b := _make(1, Vector3(0, 0, -3.0), PI)
	await physics_frame
	s_a.request_attack(D.RIGHT)
	await _seconds(1.0)
	_check(is_equal_approx(s_b.health, s_b.max_health), "un coup de taille n'atteint pas une cible à 3 m")
	s_a.stamina = GameConfig.STAMINA_MAX
	s_a.request_attack(D.DOWN)
	await _seconds(1.0)
	_check(s_b.health < s_b.max_health, "l'estoc l'atteint (portée plus grande)")
	await _cleanup([s_a, s_b])
	var off_a := _make(0, Vector3.ZERO, 0.0)
	var off_b := _make(1, Vector3(1.6, 0, -1.6), PI)   # à 45° sur le côté
	await physics_frame
	off_a.request_attack(D.DOWN)
	await _seconds(1.0)
	_check(is_equal_approx(off_b.health, off_b.max_health), "l'estoc doit être visé : pas de touche à 45° sur le côté")
	await _cleanup([off_a, off_b])

	print("[Parade directionnelle]")
	p = _pair()
	a = p[0]
	b = p[1]
	await physics_frame
	# A frappe de SA droite -> B doit garder sa GAUCHE (côté opposé)
	b.set_guard(true, D.LEFT)
	await _seconds(0.5)   # garde levée depuis longtemps : parade normale
	var stam0 := b.stamina
	var res := b.receive_hit(a, D.RIGHT, 20.0)
	_check(res == R.BLOCKED, "bon côté : coup paré")
	_check(is_equal_approx(b.health, b.max_health), "aucun dégât en parant")
	_check(is_equal_approx(stam0 - b.stamina, 20.0 * GameConfig.BLOCK_STAMINA_FACTOR), "la parade coûte de l'endurance")
	b.set_guard(true, D.RIGHT)
	await _seconds(0.5)
	res = b.receive_hit(a, D.RIGHT, 20.0)
	_check(res == R.HIT and b.health < b.max_health, "mauvais côté : le coup passe")
	await _cleanup(p)

	print("[Parade parfaite]")
	p = _pair()
	a = p[0]
	b = p[1]
	await physics_frame
	b.set_guard(true, D.UP)
	await _frames(3)   # garde levée depuis 3 images seulement
	res = b.receive_hit(a, D.UP, 28.0)
	_check(res == R.PARRIED, "garde levée au dernier moment = parade parfaite")
	_check(a.state == S.STAGGER and a.stagger_perfect, "l'attaquant est déséquilibré")
	_check(is_equal_approx(b.health, b.max_health), "pas de dégâts")
	_check(not a.request_attack(D.UP), "le déséquilibré ne peut pas attaquer")
	var bonus_hp := a.health
	a.receive_hit(b, D.UP, 20.0)
	_check(is_equal_approx(bonus_hp - a.health, 20.0 * GameConfig.STAGGER_DAMAGE_BONUS), "dégâts bonus sur un adversaire déséquilibré")
	await _seconds(GameConfig.PARRY_STAGGER + 0.2)
	_check(a.state == S.IDLE, "il se rétablit ensuite")
	await _cleanup(p)

	print("[Endurance et garde brisée]")
	p = _pair()
	a = p[0]
	b = p[1]
	await physics_frame
	b.set_guard(true, D.UP)
	await _seconds(0.5)
	b.stamina = 5.0
	res = b.receive_hit(a, D.UP, 28.0)
	_check(res == R.GUARD_BROKEN, "pas assez d'endurance : la garde se brise")
	_check(b.stamina == 0.0 and b.exhausted, "endurance à 0, épuisé")
	_check(b.state == S.STAGGER, "le défenseur est déséquilibré")
	_check(is_equal_approx(b.max_health - b.health, 28.0 * GameConfig.GUARD_BREAK_DAMAGE_FACTOR), "dégâts réduits quand la garde se brise")
	_check(not b.is_guarding(), "plus de garde quand on est épuisé")
	_check(not b.request_attack(D.UP), "épuisé : pas d'attaque")
	await _seconds(GameConfig.EXHAUSTED_DELAY + 1.0)
	_check(not b.exhausted, "l'endurance remonte, il peut agir de nouveau")
	await _cleanup(p)

	print("[Endurance : attaques à la chaîne]")
	var solo := _make(0, Vector3.ZERO, 0.0)
	await physics_frame
	var counter := [0]
	solo.attack_started.connect(func(_d: int): counter[0] += 1)
	var lowest := GameConfig.STAMINA_MAX
	for i in 400:   # on relance une attaque dès que possible pendant ~13 s
		solo.request_attack(D.UP)
		await _frames(4)
		lowest = minf(lowest, solo.stamina)
	_check(counter[0] >= 5 and lowest < GameConfig.STAMINA_MAX * 0.5, "attaquer en boucle fait baisser l'endurance (%d attaques, minimum %.0f)" % [counter[0], lowest])
	await _cleanup([solo])

	print("[Tirs reçus (flèches)]")
	p = _pair()
	a = p[0]
	b = p[1]
	await physics_frame
	var flight := Vector3(0, 0, -1)   # le tir va de A vers B ; B regarde vers A (il le voit venir)
	res = b.receive_projectile(a, 30.0, flight, false)
	_check(res == R.HIT and is_equal_approx(b.max_health - b.health, 30.0), "sans garde : le tir touche")
	_check(b.state == S.STAGGER, "le tir étourdit brièvement")
	b.reset()
	b.set_guard(true, D.LEFT)
	await _seconds(0.5)
	stam0 = b.stamina
	res = b.receive_projectile(a, 30.0, flight, false)
	_check(res == R.BLOCKED and is_equal_approx(b.health, b.max_health), "garde de face : le tir est paré, aucun dégât")
	_check(is_equal_approx(stam0 - b.stamina, 30.0 * GameConfig.BLOCK_STAMINA_FACTOR * GameConfig.PROJECTILE_BLOCK_FACTOR), "parer un tir coûte moins qu'un coup d'épée")
	res = b.receive_projectile(a, 30.0, Vector3(0, 0, 1), false)
	_check(res == R.HIT, "un tir dans le dos passe malgré la garde")
	b.reset()
	b.set_guard(true, D.UP)
	await _frames(3)
	res = b.receive_projectile(a, 30.0, flight, false)
	_check(res == R.PARRIED and is_equal_approx(b.health, b.max_health), "garde levée au dernier moment : tir renvoyé")
	b.reset()
	b.set_guard(true, D.UP)
	await _seconds(0.5)
	b.stamina = 5.0
	res = b.receive_projectile(a, 40.0, flight, false)
	_check(res == R.GUARD_BROKEN, "un tir trop fort brise la garde d'un adversaire sans endurance")
	b.reset()
	b.invulnerable = true
	_check(b.receive_projectile(a, 40.0, flight, false) == R.DODGED, "le pas de côté esquive les tirs")
	await _cleanup(p)

	print("[Esquive]")
	p = _pair()
	a = p[0]
	b = p[1]
	await physics_frame
	b.invulnerable = true
	res = b.receive_hit(a, D.UP, 28.0)
	_check(res == R.DODGED and is_equal_approx(b.health, b.max_health), "invulnérable : le coup est esquivé")
	await _cleanup(p)

	print("")
	print("RÉSULTAT COMBAT : %s (%d échec(s))" % ["SUCCÈS" if failures == 0 else "ÉCHEC", failures])
	quit(1 if failures > 0 else 0)
