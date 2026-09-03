class_name DiceTray
extends Node3D
##
## Where the dice actually tumble. The other two hard parts from AGENTS.md:
## detecting the settle, and never hanging a GM who is waiting on one.
##
## The outcome is read from where the dice stop. Nothing here decides a result
## and animates it afterwards -- the impulse is randomised, the dice collide with
## each other and the walls, and whatever they show is what gets reported. That
## inversion is the whole point, and it is why cross-platform determinism is not
## required and must never be relied on.
##
## Three policies, all decided before this was built:
##
##   cocked      a die resting on an edge or against a wall voids the throw and
##               every die is re-thrown together, up to MAX_ATTEMPTS. Recorded
##               on the result as `rerolls`, so the log is honest about it.
##   timeout     a hard cap per attempt. When it fires the simulation is frozen
##               and a result is forced from where the dice are, because a die
##               spinning in a corner must never leave a GM waiting forever.
##   the d4      read by its apex, like every other die is read by its up face.
##               See DieShape; there is no special case here.
##
## Emits `settled` with an Array of {sides, number} once a throw resolves, and
## polls nothing -- a caller awaits the signal.
##

## A throw resolved. `faces` is [{sides, number}] in the order the dice were
## asked for; `rerolls` is how many whole throws were voided getting here.
signal settled(faces: Array, rerolls: int)

## Physics layers, reserved in project.godot long before this existed.
const LAYER_DIE := 1
const LAYER_WALL := 2
const LAYER_FLOOR := 3

## Tray dimensions, in world units.
##
## Not metres. A first version built these at life size -- an 11mm die in a 32cm
## tray -- and the dice fell straight through the floor: at that scale a falling
## die crosses a centimetre-thick floor in well under one physics step, and the
## solver has almost no room to resolve a contact before the next frame. Rigid
## bodies around a unit across are what the engine is tuned for, so the tray is
## built there and the camera is simply placed further back. How big a die looks
## is a camera question, not a physics one.
const TRAY_HALF := 7.0
const WALL_HEIGHT := 6.0
const WALL_THICKNESS := 0.5
const DIE_RADIUS := 0.5

## How still a die must be to count as stopped, and for how long. Both matter:
## a die at the top of a bounce is momentarily slow.
const STILL_SPEED := 0.06
const STILL_SPIN := 0.2
const STILL_SECONDS := 0.2

## Hard cap per attempt. A die that has not stopped by now is not going to.
const ATTEMPT_TIMEOUT := 5.0

## Whole throws, including the first. A cocked die voids the throw; this is what
## stops that recursing forever when a tray is somehow shaped so a die can never
## settle.
const MAX_ATTEMPTS := 4

## Where dice are dropped from.
##
## Inside the box, with clearance under the lid. Spawning a body overlapping
## static geometry is how the first version launched its dice through the floor:
## the solver resolves the penetration by ejecting them, and it does not care
## which way.
const DROP_HEIGHT := 3.0

var _rng := RandomNumberGenerator.new()
var _shapes: Array = []
var _bodies: Array[RigidBody3D] = []
var _still_for: float = 0.0
var _elapsed: float = 0.0
var _attempt: int = 0
var _rolling: bool = false
var _palette: ThemePalette

## Whether the last throw ran out of time rather than coming to rest.
##
## Exposed because "a result was produced" and "the dice settled" are different
## claims, and a tray can satisfy the first while failing the second. An early
## version of this file did exactly that -- every die fell through the floor and
## the number was read off one in free fall at the timeout -- and every test
## passed, because they only ever asked for a result.
var _last_forced: bool = false

## Numbers drawn on the dice. Kept so a rebuild can reuse them.
var _label_font: Font


func _ready() -> void:
	_rng.randomize()
	set_physics_process(false)


func configure(palette: ThemePalette, font: Font = null) -> void:
	_palette = palette
	_label_font = font
	_build_tray()


# --- Throwing --------------------------------------------------------------

## Throw one die per entry in `sides_list`. Unsupported sides are skipped, so a
## caller may pass a parsed notation straight through without filtering d0.
##
## Returns false when there is nothing to throw, in which case `settled` is never
## emitted and the caller must not await it.
func throw(sides_list: Array) -> bool:
	_shapes.clear()
	for sides in sides_list:
		var shape := DieShape.for_sides(AlternityNum.as_int(sides))
		if shape != null:
			_shapes.append(shape)
	if _shapes.is_empty():
		return false

	_attempt = 0
	_rolling = true
	_throw_attempt()
	return true


func is_rolling() -> bool:
	return _rolling


## True when the last throw was resolved by the timeout instead of by settling.
func was_forced() -> bool:
	return _last_forced


## How long the last attempt ran, in seconds.
func last_attempt_seconds() -> float:
	return _elapsed


func _throw_attempt() -> void:
	_attempt += 1
	_still_for = 0.0
	_elapsed = 0.0
	_clear_dice()

	for i in _shapes.size():
		var body := _build_die(_shapes[i], i)
		add_child(body)
		_bodies.append(body)
		_launch(body, i)

	set_physics_process(true)


## Randomise the launch, not the outcome.
##
## This is the only place randomness enters a physical roll. The dice then
## collide with each other and the walls, and the faces they end on are read.
## Nothing downstream re-rolls or re-simulates -- see AGENTS.md.
func _launch(body: RigidBody3D, index: int) -> void:
	var spread := TRAY_HALF * 0.45
	# Dice are laid across the tray so they do not start stacked, then jittered on
	# every axis. A single die that always left from the same point would still
	# tumble, but it would explore far less of the tray on the way down.
	var lane := 0.0 if _shapes.size() < 2 else lerpf(-spread, spread, float(index) / float(_shapes.size() - 1))
	body.position = Vector3(
		lane + _rng.randf_range(-spread * 0.4, spread * 0.4),
		DROP_HEIGHT + _rng.randf_range(-0.4, 0.4),
		_rng.randf_range(-spread, spread)
	)
	body.rotation = Vector3(
		_rng.randf_range(0.0, TAU), _rng.randf_range(0.0, TAU), _rng.randf_range(0.0, TAU)
	)
	body.linear_velocity = Vector3(
		_rng.randf_range(-3.5, 3.5), _rng.randf_range(-6.0, -2.0), _rng.randf_range(-3.5, 3.5)
	)
	body.angular_velocity = Vector3(
		_rng.randf_range(-16.0, 16.0), _rng.randf_range(-16.0, 16.0), _rng.randf_range(-16.0, 16.0)
	)


# --- Settling --------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not _rolling:
		return
	_elapsed += delta

	if _all_still(delta):
		_finish_attempt(false)
		return

	# The hard timeout. A die spinning in a corner, wedged between two others, or
	# thrown through a gap must not be able to hang the person waiting for the
	# number -- least of all a GM on the other end of a connection.
	if _elapsed >= ATTEMPT_TIMEOUT:
		_finish_attempt(true)


func _all_still(delta: float) -> bool:
	for body in _bodies:
		if body.linear_velocity.length() > STILL_SPEED or body.angular_velocity.length() > STILL_SPIN:
			_still_for = 0.0
			return false
	# Slow is not stopped: a die at the apex of a bounce is momentarily still.
	_still_for += delta
	return _still_for >= STILL_SECONDS


func _finish_attempt(timed_out: bool) -> void:
	var faces: Array = []
	var any_cocked := false

	for i in _bodies.size():
		var reading: Dictionary = _shapes[i].read(_bodies[i].global_transform.basis)
		if bool(reading.get("cocked", false)):
			any_cocked = true
		faces.append({
			"sides": _shapes[i].sides,
			"number": AlternityNum.as_int(reading.get("number", 1), 1),
			"cocked": bool(reading.get("cocked", false)),
		})

	# A cocked die voids the throw and every die goes again -- decided up front,
	# and the reason RollResult has somewhere to record it.
	if any_cocked and not timed_out and _attempt < MAX_ATTEMPTS:
		_throw_attempt()
		return

	# Out of attempts, or the clock ran out. Force a result from where the dice
	# are: an answer read from a die that had almost stopped is worth more than
	# no answer at all, and this is the branch that guarantees one exists.
	set_physics_process(false)
	_rolling = false
	_last_forced = timed_out
	settled.emit(faces, _attempt - 1)


# --- Building --------------------------------------------------------------

func _clear_dice() -> void:
	for body in _bodies:
		if is_instance_valid(body):
			body.queue_free()
	_bodies.clear()


func _build_die(shape: DieShape, index: int) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "Die%d" % index
	body.collision_layer = 1 << (LAYER_DIE - 1)
	# Dice collide with each other and with the tray. Colliding with each other
	# is not decoration: it is part of what decides the outcome.
	body.collision_mask = (1 << (LAYER_DIE - 1)) | (1 << (LAYER_WALL - 1)) | (1 << (LAYER_FLOOR - 1))
	body.mass = 1.0
	# Heavier-feeling gravity than the engine default. At this scale a die is a
	# unit across, and real dice fall a few of their own widths and stop inside a
	# second or so; at 1g they drift down instead, and a player watches three
	# seconds of tumbling before a number appears. Well short of the speed that
	# would risk tunnelling through a half-unit floor in one step.
	body.gravity_scale = 3.0
	# Enough damping that a die which is nearly done stops being nearly done.
	body.angular_damp = 0.35
	body.linear_damp = 0.08
	body.physics_material_override = _die_material()
	# Continuous detection: a die is small and fast, and tunnelling through the
	# floor is how a roll silently produces nothing.
	body.continuous_cd = true

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = shape.build_mesh()
	mesh_instance.scale = Vector3.ONE * DIE_RADIUS
	mesh_instance.material_override = _die_face_material()
	body.add_child(mesh_instance)

	var collider := CollisionShape3D.new()
	var hull := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for p in shape.hull_points():
		points.append(p * DIE_RADIUS)
	hull.points = points
	collider.shape = hull
	body.add_child(collider)

	_add_numbers(body, shape)
	return body


## Draw the numbers on the die.
##
## Label3D rather than a generated texture atlas: it uses the app's own font, so
## the numbers match the rest of the UI, and it needs no UV mapping to get right.
## A roll is two or three dice, so the node count is not worth optimising against
## the risk of mapping a digit onto the wrong face.
func _add_numbers(body: RigidBody3D, shape: DieShape) -> void:
	for placement in shape.label_placements():
		var label := Label3D.new()
		label.text = str(AlternityNum.as_int(placement["number"]))
		label.font_size = 96
		label.pixel_size = DIE_RADIUS / 260.0
		label.modulate = _palette.text if _palette != null else Color.WHITE
		label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		label.no_depth_test = false
		label.double_sided = false
		if _label_font != null:
			label.font = _label_font

		var normal: Vector3 = placement["normal"]
		# Lift the number just clear of the surface so it does not z-fight the
		# face it is written on.
		label.position = (placement["position"] as Vector3) * DIE_RADIUS + normal * (DIE_RADIUS * 0.02)
		label.basis = _facing(normal)
		body.add_child(label)


## An orientation whose -Z looks along `normal`, so a Label3D drawn on that face
## reads the right way up from outside the die.
func _facing(normal: Vector3) -> Basis:
	var forward := normal.normalized()
	var reference := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var right := reference.cross(forward).normalized()
	var up := forward.cross(right).normalized()
	return Basis(right, up, forward)


func _die_material() -> PhysicsMaterial:
	var material := PhysicsMaterial.new()
	# Dice are hard and not very bouncy. Too much bounce and they never settle;
	# none at all and they land dead and look fake.
	material.friction = 0.6
	material.bounce = 0.18
	return material


func _die_face_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = _palette.surface_soft if _palette != null else Color(0.2, 0.22, 0.28)
	material.metallic = 0.1
	material.roughness = 0.45
	return material


func _build_tray() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "TrayFloor"
	floor_body.collision_layer = 1 << (LAYER_FLOOR - 1)
	floor_body.collision_mask = 1 << (LAYER_DIE - 1)
	floor_body.physics_material_override = _die_material()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	# Thick enough that a fast die cannot cross it between physics steps.
	floor_box.size = Vector3(TRAY_HALF * 2.0, WALL_THICKNESS, TRAY_HALF * 2.0)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(0, -WALL_THICKNESS * 0.5, 0)
	floor_body.add_child(floor_shape)
	add_child(floor_body)

	var floor_mesh := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = floor_box.size
	floor_mesh.mesh = plane
	floor_mesh.position = Vector3(0, -WALL_THICKNESS * 0.5, 0)
	var felt := StandardMaterial3D.new()
	felt.albedo_color = _palette.surface if _palette != null else Color(0.1, 0.12, 0.16)
	felt.roughness = 0.95
	floor_mesh.material_override = felt
	add_child(floor_mesh)

	# Four walls, plus a lid. The lid is not decoration: without it a die thrown
	# hard enough leaves the tray, and a die that has left has no face to read.
	var span := TRAY_HALF * 2.0 + WALL_THICKNESS
	var walls := [
		[Vector3(TRAY_HALF, WALL_HEIGHT * 0.5, 0), Vector3(WALL_THICKNESS, WALL_HEIGHT, span)],
		[Vector3(-TRAY_HALF, WALL_HEIGHT * 0.5, 0), Vector3(WALL_THICKNESS, WALL_HEIGHT, span)],
		[Vector3(0, WALL_HEIGHT * 0.5, TRAY_HALF), Vector3(span, WALL_HEIGHT, WALL_THICKNESS)],
		[Vector3(0, WALL_HEIGHT * 0.5, -TRAY_HALF), Vector3(span, WALL_HEIGHT, WALL_THICKNESS)],
		[Vector3(0, WALL_HEIGHT, 0), Vector3(span, WALL_THICKNESS, span)],
	]
	for spec in walls:
		var wall := StaticBody3D.new()
		wall.collision_layer = 1 << (LAYER_WALL - 1)
		wall.collision_mask = 1 << (LAYER_DIE - 1)
		wall.physics_material_override = _die_material()
		var shape_node := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec[1]
		shape_node.shape = box
		wall.position = spec[0]
		wall.add_child(shape_node)
		add_child(wall)


## Read the dice where they lie, without waiting.
##
## For tests and for the forced path. Returns [{sides, number, cocked}].
func read_now() -> Array:
	var faces: Array = []
	for i in _bodies.size():
		var reading: Dictionary = _shapes[i].read(_bodies[i].global_transform.basis)
		faces.append({
			"sides": _shapes[i].sides,
			"number": AlternityNum.as_int(reading.get("number", 1), 1),
			"cocked": bool(reading.get("cocked", false)),
		})
	return faces
