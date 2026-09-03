class_name DieShape
extends RefCounted
##
## The geometry of one die, and the mapping from an orientation to the number
## showing. No physics and no rendering -- this is the part that has to be right.
##
## Reading a settled die is one of the three hard parts named in AGENTS.md, and
## the trick that makes it tractable is to stop thinking in faces. A die declares
## a set of **readings**: directions in the die's own space, each carrying a
## number. Reading it is "which declared direction points most upward once the
## die's orientation is applied". That single rule covers every shape here:
##
##     d6, d8, d12, d20   the readings are face normals -- the face pointing up
##     d4                 the readings are vertex directions -- the apex,
##                        because a tetrahedron has no up-face at all
##
## Framing it that way is also what makes a custom model possible later. A die
## supplied as a mesh cannot have its numbering inferred from geometry, so it
## would have to declare the same orientation -> number list; nothing in the
## reading logic would change.
##
## Meshes are generated rather than authored, so the normals used to read a die
## are the same numbers that built it. An imported model's normals are something
## you have to verify; these are true by construction.
##
## Numbers follow the convention that opposite faces sum to sides + 1, which is
## what an actual die does.
##

## How far a die may tip and still be read, as a fraction of the angle to its
## nearest other reading.
##
## Derived per shape rather than fixed, because a single threshold cannot serve
## every die here. A d6's faces are 90 degrees apart and a d20's are 41.8; a
## tolerance loose enough for the cube reads a d20 balanced on an edge as though
## it had settled, which is precisely the silent wrong answer the tray must not
## produce. At a third of the way to the neighbour, the midpoint between two
## readings is always cocked and an ordinary settle always is not.
const SETTLE_TOLERANCE := 0.35

## Which end of the die is read.
enum ReadMode {
	## The face pointing up. Every die but the d4.
	FACE_UP,
	## The corner pointing up. The d4, which has no up-face.
	VERTEX_UP,
}

## Circumradius of the generated mesh. The tray scales from here.
const UNIT_RADIUS := 1.0

var sides: int = 6
var read_mode: ReadMode = ReadMode.FACE_UP

## Smallest angle between two readings on this die, in radians. What
## SETTLE_TOLERANCE is a fraction of.
var neighbour_angle: float = PI

## Cached cos(neighbour_angle * SETTLE_TOLERANCE): a reading pointing less
## upward than this is cocked.
var settled_min_dot: float = 0.9

## Corner points, normalized to UNIT_RADIUS.
var vertices: Array[Vector3] = []

## Outward normals of the mesh faces, in the die's own space.
var face_normals: Array[Vector3] = []

## Direction -> number. What reading a settled die actually consults.
var readings: Array = []


static func _phi() -> float:
	return (1.0 + sqrt(5.0)) / 2.0


## Build the shape for a die with `sides` faces.
##
## Returns null for a number of sides this does not know how to make. The caller
## must handle that rather than assume: "d0" is real notation meaning no die at
## all, and the rules data contains it.
static func for_sides(sides_wanted: int) -> DieShape:
	match sides_wanted:
		4:
			return _tetrahedron()
		6:
			return _cube()
		8:
			return _octahedron()
		12:
			return _dodecahedron()
		20:
			return _icosahedron()
	return null


static func is_supported(sides_wanted: int) -> bool:
	return sides_wanted in [4, 6, 8, 12, 20]


# --- Reading ---------------------------------------------------------------

## The number showing, given the die's current orientation.
##
## Returns {number, dot, margin, cocked}:
##
##   number   the reading that points most upward
##   dot      how upward it points; 1.0 is dead flat
##   margin   how far ahead of the runner-up it is, which is what makes an
##            ambiguous orientation visible rather than silently picking one
##   cocked   true when nothing points convincingly up
##
## `up` is a parameter rather than hardcoded so this is testable without a scene
## and so a tray tilted for the camera does not change what the dice read.
func read(orientation: Basis, up: Vector3 = Vector3.UP) -> Dictionary:
	var best_number := 0
	var best_dot := -2.0
	var second_dot := -2.0

	for reading in readings:
		var world: Vector3 = (orientation * (reading["direction"] as Vector3)).normalized()
		var d := world.dot(up)
		if d > best_dot:
			second_dot = best_dot
			best_dot = d
			best_number = AlternityNum.as_int(reading["number"])
		elif d > second_dot:
			second_dot = d

	return {
		"number": best_number,
		"dot": best_dot,
		"margin": best_dot - second_dot,
		"cocked": best_dot < settled_min_dot,
	}


# --- Mesh ------------------------------------------------------------------

## Triangles for rendering, and the convex hull points for physics.
##
## Faces are built by gathering the vertices lying on each face's plane and
## fanning them, which works the same for a cube, a dodecahedron and a
## tetrahedron -- so there is one triangulation to get right rather than five.
func build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for normal in face_normals:
		var ring := _face_ring(normal)
		if ring.size() < 3:
			continue
		# Fan from the first corner. Every face here is convex and planar, which
		# is what makes a fan safe.
		for i in range(1, ring.size() - 1):
			for v in [ring[0], ring[i], ring[i + 1]]:
				st.set_normal(normal)
				st.add_vertex(v)

	st.index()
	return st.commit()


## The points a physics convex hull is built from.
func hull_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	for v in vertices:
		points.append(v)
	return points


## Where a number should be drawn, in the die's own space.
##
## Returns [{position, normal, number}]. A face-read die gets one label at each
## face centre. A d4 gets three per number, one beside each corner carrying it --
## which is what an apex-numbered d4 actually looks like, and the reason it can
## be read from above at all.
func label_placements() -> Array:
	var out: Array = []
	if read_mode == ReadMode.FACE_UP:
		for reading in readings:
			var normal: Vector3 = reading["direction"]
			var ring := _face_ring(normal)
			var centre := Vector3.ZERO
			for v in ring:
				centre += v
			if not ring.is_empty():
				centre /= float(ring.size())
			out.append({
				"position": centre,
				"normal": normal,
				"number": AlternityNum.as_int(reading["number"]),
			})
		return out

	# Apex numbering. The number at a vertex is written on each face that touches
	# it, pulled in from the corner towards the face centre so it sits on the
	# face rather than on the edge.
	for reading in readings:
		var vertex: Vector3 = reading["direction"] * UNIT_RADIUS
		var number := AlternityNum.as_int(reading["number"])
		for normal in face_normals:
			var ring := _face_ring(normal)
			var touches := false
			var centre := Vector3.ZERO
			for v in ring:
				centre += v
				if v.distance_to(vertex) < 0.001:
					touches = true
			if not touches or ring.is_empty():
				continue
			centre /= float(ring.size())
			out.append({
				"position": vertex.lerp(centre, 0.45),
				"normal": normal,
				"number": number,
			})
	return out


## The corners lying on one face, ordered around its normal.
func _face_ring(normal: Vector3) -> Array[Vector3]:
	var n := normal.normalized()
	# How far out this face's plane is: the furthest any corner reaches along the
	# normal. Every corner at that distance is on the face.
	var reach := -INF
	for v in vertices:
		reach = maxf(reach, v.dot(n))

	var on_face: Array[Vector3] = []
	for v in vertices:
		if absf(v.dot(n) - reach) < 0.0001:
			on_face.append(v)
	if on_face.size() < 3:
		return on_face

	# Order them by angle in the face's own plane, so the fan does not cross
	# itself. Winding is chosen to face outward along the normal.
	var centre := Vector3.ZERO
	for v in on_face:
		centre += v
	centre /= float(on_face.size())

	var axis_x := (on_face[0] - centre).normalized()
	var axis_y := n.cross(axis_x).normalized()
	on_face.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		var oa := a - centre
		var ob := b - centre
		return atan2(oa.dot(axis_y), oa.dot(axis_x)) < atan2(ob.dot(axis_y), ob.dot(axis_x)))
	return on_face


# --- Shapes ----------------------------------------------------------------

func _finish(raw_vertices: Array, raw_normals: Array, reading_directions: Array) -> DieShape:
	vertices.clear()
	for v in raw_vertices:
		vertices.append((v as Vector3).normalized() * UNIT_RADIUS)
	face_normals.clear()
	for n in raw_normals:
		face_normals.append((n as Vector3).normalized())
	readings = _number_directions(reading_directions)
	_measure_settle_tolerance()
	return self


## Find the closest pair of readings, which is what decides how far this
## particular die may tip and still be read.
func _measure_settle_tolerance() -> void:
	var closest := PI
	for i in readings.size():
		for j in range(i + 1, readings.size()):
			var a: Vector3 = readings[i]["direction"]
			var b: Vector3 = readings[j]["direction"]
			closest = minf(closest, a.angle_to(b))
	neighbour_angle = closest
	settled_min_dot = cos(closest * SETTLE_TOLERANCE)


## Assign numbers so that opposite readings sum to sides + 1, which is what a
## real die does. Pairing by antipode rather than by index means the rule holds
## whatever order the directions were generated in.
func _number_directions(directions: Array) -> Array:
	var out: Array = []
	var taken := {}
	var next := 1
	for i in directions.size():
		if taken.has(i):
			continue
		var dir: Vector3 = (directions[i] as Vector3).normalized()
		taken[i] = next
		# Find the antipode and give it the complement.
		for j in directions.size():
			if j == i or taken.has(j):
				continue
			if (directions[j] as Vector3).normalized().dot(dir) < -0.999:
				taken[j] = sides + 1 - next
				break
		next += 1

	for i in directions.size():
		out.append({
			"direction": (directions[i] as Vector3).normalized(),
			"number": AlternityNum.as_int(taken.get(i, i + 1)),
		})
	return out


static func _tetrahedron() -> DieShape:
	var shape := DieShape.new()
	shape.sides = 4
	# A tetrahedron has no opposite faces, so it is the one die where numbering
	# cannot pair antipodes -- and the one that is read by its apex.
	shape.read_mode = ReadMode.VERTEX_UP
	var corners := [
		Vector3(1, 1, 1), Vector3(1, -1, -1), Vector3(-1, 1, -1), Vector3(-1, -1, 1),
	]
	# The face opposite a corner has that corner's direction reversed.
	var normals := []
	for c in corners:
		normals.append(-(c as Vector3))
	shape._finish(corners, normals, corners)
	return shape


static func _cube() -> DieShape:
	var shape := DieShape.new()
	shape.sides = 6
	var corners := []
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				corners.append(Vector3(x, y, z))
	var normals := [
		Vector3.UP, Vector3.DOWN, Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD,
	]
	shape._finish(corners, normals, normals)
	return shape


static func _octahedron() -> DieShape:
	var shape := DieShape.new()
	shape.sides = 8
	var corners := [
		Vector3(1, 0, 0), Vector3(-1, 0, 0),
		Vector3(0, 1, 0), Vector3(0, -1, 0),
		Vector3(0, 0, 1), Vector3(0, 0, -1),
	]
	var normals := []
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				normals.append(Vector3(x, y, z))
	shape._finish(corners, normals, normals)
	return shape


## The two remaining shapes are duals of each other, which is the whole reason
## they are cheap to generate: a dodecahedron's twelve faces point at an
## icosahedron's twelve corners, and an icosahedron's twenty faces point at a
## dodecahedron's twenty corners. One set of points builds both dice.
static func _icosahedron_points() -> Array:
	var p := _phi()
	var out := []
	for s1 in [-1.0, 1.0]:
		for s2 in [-1.0, 1.0]:
			out.append(Vector3(0, s1 * 1.0, s2 * p))
			out.append(Vector3(s1 * 1.0, s2 * p, 0))
			out.append(Vector3(s1 * p, 0, s2 * 1.0))
	return out


## The twenty corners of a dodecahedron, in the orientation dual to the
## icosahedron above.
##
## The cyclic ordering here is load-bearing and easy to get wrong: the pattern
## has to be the one whose points sit at the icosahedron's face centres, not its
## mirror. With the ordering rotated the wrong way the two solids are still
## regular and still the right size -- only twelve of the twenty faces gather any
## corners at all, so the die comes out with holes in it rather than visibly
## malformed. Verified by smoke_die_shape, which counts the triangles.
static func _dodecahedron_points() -> Array:
	var p := _phi()
	var inv := 1.0 / p
	var out := []
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				out.append(Vector3(x, y, z))
	for s1 in [-1.0, 1.0]:
		for s2 in [-1.0, 1.0]:
			out.append(Vector3(s1 * inv, 0, s2 * p))
			out.append(Vector3(s1 * p, s2 * inv, 0))
			out.append(Vector3(0, s1 * p, s2 * inv))
	return out


static func _dodecahedron() -> DieShape:
	var shape := DieShape.new()
	shape.sides = 12
	var normals := _icosahedron_points()
	shape._finish(_dodecahedron_points(), normals, normals)
	return shape


static func _icosahedron() -> DieShape:
	var shape := DieShape.new()
	shape.sides = 20
	var normals := _dodecahedron_points()
	shape._finish(_icosahedron_points(), normals, normals)
	return shape
