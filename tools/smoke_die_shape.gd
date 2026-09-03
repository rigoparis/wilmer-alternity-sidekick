extends "res://tools/test_harness.gd"
##
## Die geometry and face reading, with no physics and no scene.
##
## AGENTS.md names reading which face is up as one of the three hard parts of the
## tray, and the d4 as the case with no up-face at all. This is where that is
## settled, headless, before any dice are ever thrown -- because a reading bug in
## a physics scene looks exactly like bad luck.
##
## The load-bearing test is _test_every_reading_is_reachable: for every die, for
## every number on it, orient the die so that number's direction points up and
## assert the die reads it back. That is 50 orientations across five shapes, and
## it is the difference between "the mapping looks right" and "the mapping is
## right".
##

const Shape := preload("res://scripts/core/dice/die_shape.gd")

## sides -> [corner count, face count, triangles the mesh should produce]
const EXPECTED := {
	4: [4, 4, 4],
	6: [8, 6, 12],
	8: [6, 8, 8],
	12: [20, 12, 36],
	20: [12, 20, 20],
}


func _init() -> void:
	begin("die shape")

	_test_supported_sides()
	_test_shapes_are_the_right_solids()
	_test_numbering()
	_test_every_reading_is_reachable()
	_test_cocked_detection()
	_test_meshes()
	_test_label_placements()

	finish()


func _test_supported_sides() -> void:
	for sides in [4, 6, 8, 12, 20]:
		check_true(Shape.is_supported(sides), "d%d is supported" % sides)
		check(Shape.for_sides(sides) != null, "d%d builds" % sides)

	# "+d0" is real notation in this game's data -- it means no die at all -- so
	# an unsupported request has to be answerable rather than crash.
	check_false(Shape.is_supported(0), "d0 is not a shape")
	check(Shape.for_sides(0) == null, "and asking for one returns null")
	check_false(Shape.is_supported(10), "d10 is not built")
	check(Shape.for_sides(10) == null, "and returns null rather than a wrong solid")


func _test_shapes_are_the_right_solids() -> void:
	for sides in EXPECTED:
		var shape = Shape.for_sides(sides)
		var want: Array = EXPECTED[sides]
		check_eq(shape.vertices.size(), want[0], "d%d has %d corners" % [sides, want[0]])
		check_eq(shape.face_normals.size(), want[1], "d%d has %d faces" % [sides, want[1]])
		check_eq(shape.readings.size(), want[1] if sides != 4 else 4, "d%d has %d readings" % [sides, sides])

		# Regular solids: every corner the same distance out, every face the same
		# distance from the centre. A generator that drifted would show here.
		var first_radius: float = (shape.vertices[0] as Vector3).length()
		for v in shape.vertices:
			check_approx((v as Vector3).length(), first_radius, "d%d corners share a radius" % sides, 0.0001)

		for n in shape.face_normals:
			check_approx((n as Vector3).length(), 1.0, "d%d face normals are unit length" % sides, 0.0001)

	# The d4 is the one die read by its corner rather than its face.
	check_eq(Shape.for_sides(4).read_mode, Shape.ReadMode.VERTEX_UP, "the d4 is read by its apex")
	for sides in [6, 8, 12, 20]:
		check_eq(Shape.for_sides(sides).read_mode, Shape.ReadMode.FACE_UP, "the d%d is read by its up face" % sides)


func _test_numbering() -> void:
	for sides in EXPECTED:
		var shape = Shape.for_sides(sides)
		var seen := {}
		for reading in shape.readings:
			seen[AlternityNum.as_int(reading["number"])] = true
		check_eq(seen.size(), sides, "a d%d carries %d distinct numbers" % [sides, sides])
		for n in range(1, sides + 1):
			check_true(seen.has(n), "a d%d has a %d on it" % [sides, n])

	# Opposite faces sum to sides + 1, which is what a real die does. A
	# tetrahedron has no opposite faces, so it is excluded rather than fudged.
	for sides in [6, 8, 12, 20]:
		var shape = Shape.for_sides(sides)
		var pairs := 0
		for a in shape.readings:
			for b in shape.readings:
				if (a["direction"] as Vector3).dot(b["direction"] as Vector3) < -0.999:
					check_eq(
						AlternityNum.as_int(a["number"]) + AlternityNum.as_int(b["number"]), sides + 1,
						"d%d opposite faces sum to %d" % [sides, sides + 1]
					)
					pairs += 1
		check_eq(pairs, sides, "every d%d face has an opposite" % sides)


## The one that matters.
##
## For every number on every die, turn the die so that number's direction points
## up, and read it back. If this passes, the tray cannot report the wrong face
## for a die that settled cleanly.
func _test_every_reading_is_reachable() -> void:
	for sides in EXPECTED:
		var shape = Shape.for_sides(sides)
		for reading in shape.readings:
			var direction: Vector3 = reading["direction"]
			var number := AlternityNum.as_int(reading["number"])
			var orientation := Basis(Quaternion(direction, Vector3.UP))

			var got: Dictionary = shape.read(orientation)
			check_eq(AlternityNum.as_int(got["number"]), number, "a d%d showing %d reads %d" % [sides, number, number])
			check_false(bool(got["cocked"]), "a d%d resting on %d is not cocked" % [sides, number])
			check_true(float(got["dot"]) > 0.999, "and it points squarely up")
			# The runner-up must be a clear distance behind, or a settled die
			# would be one nudge away from reading as something else.
			check_true(float(got["margin"]) > 0.2, "with the next reading well behind")

	# Reading must not depend on which way the tray happens to face. A die
	# spun about the vertical axis shows the same number.
	var d20 = Shape.for_sides(20)
	var top: Vector3 = d20.readings[0]["direction"]
	var expected := AlternityNum.as_int(d20.readings[0]["number"])
	for degrees in [0, 37, 90, 180, 271, 359]:
		var spun := Basis(Vector3.UP, deg_to_rad(degrees)) * Basis(Quaternion(top, Vector3.UP))
		check_eq(
			AlternityNum.as_int(d20.read(spun)["number"]), expected,
			"a d20 spun %d degrees about the vertical still reads the same" % degrees
		)


## A die leaning on a wall or resting on an edge has to be reported as cocked
## rather than resolved to whichever face happens to be marginally highest.
func _test_cocked_detection() -> void:
	for sides in EXPECTED:
		var shape = Shape.for_sides(sides)
		var a: Vector3 = shape.readings[0]["direction"]

		# Find a neighbouring reading and tip the die halfway between the two.
		# That is exactly the ambiguous case: no face is up, and picking one
		# would be inventing a result.
		var neighbour := Vector3.ZERO
		var best := -2.0
		for reading in shape.readings:
			var d: Vector3 = reading["direction"]
			if d.distance_to(a) < 0.0001:
				continue
			var dot := d.dot(a)
			if dot > best:
				best = dot
				neighbour = d
		var between := (a + neighbour).normalized()
		var tipped := Basis(Quaternion(between, Vector3.UP))
		check_true(bool(shape.read(tipped)["cocked"]), "a d%d balanced between two readings is cocked" % sides)

	# And a die tipped only slightly is still readable -- the threshold must not
	# be so tight that ordinary settling reads as cocked.
	var d6 = Shape.for_sides(6)
	var up: Vector3 = d6.readings[0]["direction"]
	var slight := Basis(Vector3.RIGHT, deg_to_rad(8)) * Basis(Quaternion(up, Vector3.UP))
	var read: Dictionary = d6.read(slight)
	check_false(bool(read["cocked"]), "a d6 sitting 8 degrees off level still reads")
	check_eq(AlternityNum.as_int(read["number"]), AlternityNum.as_int(d6.readings[0]["number"]), "and reads correctly")


func _test_meshes() -> void:
	for sides in EXPECTED:
		var shape = Shape.for_sides(sides)
		var mesh := shape.build_mesh()
		check(mesh != null, "a d%d builds a mesh" % sides)
		if mesh == null:
			continue
		var faces := mesh.get_faces()
		check_eq(faces.size() / 3, EXPECTED[sides][2], "a d%d is %d triangles" % [sides, EXPECTED[sides][2]])

		# Every triangle must lie on the hull: no corner further out than the
		# circumradius, which would mean the fan crossed itself.
		var radius: float = (shape.vertices[0] as Vector3).length()
		for v in faces:
			check_true((v as Vector3).length() <= radius + 0.0001, "a d%d triangle stays on the hull" % sides)

		check_eq(shape.hull_points().size(), shape.vertices.size(), "a d%d hands its corners to physics" % sides)

		# Winding, checked against the engine's own convention rather than against
		# a remembered rule. Godot draws clockwise-from-outside as the front face,
		# so a correctly wound triangle has its right-hand normal pointing inward
		# -- which is what BoxMesh does. Get this backwards and nothing looks
		# inside out: every face is culled and the die renders as a dark blob.
		check_eq(
			_winding_of(mesh), _winding_of(_reference_mesh()),
			"a d%d is wound the same way the engine winds its own meshes" % sides
		)


## "outward" or "inward": which way (b-a) x (c-a) points relative to the centre.
func _winding_of(mesh: Mesh) -> String:
	var faces := mesh.get_faces()
	var outward := 0
	var inward := 0
	for i in range(0, faces.size(), 3):
		var a: Vector3 = faces[i]
		var b: Vector3 = faces[i + 1]
		var c: Vector3 = faces[i + 2]
		var centre := (a + b + c) / 3.0
		if centre.length() < 0.0001:
			continue
		if ((b - a).cross(c - a)).normalized().dot(centre.normalized()) > 0.0:
			outward += 1
		else:
			inward += 1
	if outward > 0 and inward > 0:
		return "mixed"
	return "outward" if outward > 0 else "inward"


## A mesh the engine built itself, to read the convention off rather than
## hardcode it.
func _reference_mesh() -> Mesh:
	var box := BoxMesh.new()
	box.size = Vector3(2, 2, 2)
	return box


func _test_label_placements() -> void:
	# A face-read die gets one number per face, at its centre.
	for sides in [6, 8, 12, 20]:
		var shape = Shape.for_sides(sides)
		var places := shape.label_placements()
		check_eq(places.size(), sides, "a d%d places one number per face" % sides)
		var numbers := {}
		for place in places:
			numbers[AlternityNum.as_int(place["number"])] = true
		check_eq(numbers.size(), sides, "covering every number once")

	# An apex-numbered d4 writes each number three times, once beside each corner
	# carrying it -- which is what makes it readable from above at all.
	var d4 = Shape.for_sides(4)
	var d4_places := d4.label_placements()
	check_eq(d4_places.size(), 12, "a d4 places twelve numbers")
	var counts := {}
	for place in d4_places:
		var n := AlternityNum.as_int(place["number"])
		counts[n] = AlternityNum.as_int(counts.get(n, 0)) + 1
	check_eq(counts.size(), 4, "across four numbers")
	for n in counts:
		check_eq(AlternityNum.as_int(counts[n]), 3, "each written three times, once per touching face")

	# A number written beside a corner must actually be near that corner, or the
	# apex a player reads would not be the apex the die reports.
	var radius: float = (d4.vertices[0] as Vector3).length()
	for place in d4_places:
		var number := AlternityNum.as_int(place["number"])
		var corner := Vector3.ZERO
		for reading in d4.readings:
			if AlternityNum.as_int(reading["number"]) == number:
				corner = (reading["direction"] as Vector3) * radius
		check_true(
			(place["position"] as Vector3).distance_to(corner) < radius,
			"the %d is written nearer its own corner than the die is wide" % number
		)
