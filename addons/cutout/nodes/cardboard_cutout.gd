@tool
extends Node3D
class_name CardboardCutout

enum CutoutMethod {
	CONTOUR_FOLLOWING
}

@export var texture: Texture2D:
	set(value):
		texture = value
		_regenerate_mesh()

@export var cutout_method: CutoutMethod = CutoutMethod.CONTOUR_FOLLOWING:
	set(value):
		cutout_method = value
		_regenerate_mesh()

@export_range(0.01, 1.0, 0.01) var depth: float = 0.1:
	set(value):
		depth = value
		_regenerate_mesh()

@export_range(0.5, 10.0, 0.1) var detail_threshold: float = 2.0:
	set(value):
		detail_threshold = value
		_regenerate_mesh()

@export_range(0.0, 1.0, 0.01) var alpha_threshold: float = 0.5:
	set(value):
		alpha_threshold = value
		_regenerate_mesh()

@export var smooth_algorithm: CutoutSmoothAlgorithm:
	set(value):
		if smooth_algorithm != null and smooth_algorithm.changed.is_connected(_on_smooth_algorithm_changed):
			smooth_algorithm.changed.disconnect(_on_smooth_algorithm_changed)

		smooth_algorithm = value

		if smooth_algorithm != null:
			smooth_algorithm.changed.connect(_on_smooth_algorithm_changed)

		_regenerate_mesh()

@export var mesh_size: Vector2 = Vector2(1.0, 1.0):
	set(value):
		mesh_size = value
		_regenerate_mesh()

@export var side_color: Color = Color(0.7, 0.6, 0.5, 1.0):
	set(value):
		side_color = value
		_setup_material()

@export var extrusion_texture: Texture2D = null:
	set(value):
		extrusion_texture = value
		_setup_material()

@export_range(0.1, 10.0, 0.1) var extrusion_texture_scale: float = 1.0:
	set(value):
		extrusion_texture_scale = value
		_regenerate_mesh()  # Need to regenerate for new UVs

var _mesh_instance: MeshInstance3D
var _last_texture: Texture2D = null


func _ready() -> void:
	# Ensure we're in the proper scene tree before setting up
	if is_node_ready():
		_setup_mesh_instance()
		if texture:
			_regenerate_mesh()


func _setup_mesh_instance() -> void:
	# Try to find existing internal MeshInstance3D child first
	if not _mesh_instance and is_inside_tree() and is_node_ready():
		if has_node("__CardboardMesh__"):
			_mesh_instance = get_node("__CardboardMesh__")

	# Create new one only if none exists
	if not _mesh_instance:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "__CardboardMesh__"
		add_child(_mesh_instance)
		if Engine.is_editor_hint() and is_inside_tree():
			var root := get_tree().edited_scene_root
			if root:
				_mesh_instance.owner = root
		# Make visible in editor
		_mesh_instance.set_meta("_edit_lock_", false)


func _regenerate_mesh() -> void:
	if not is_node_ready() or not texture:
		return

	if not _mesh_instance:
		_setup_mesh_instance()

	# Get image data from texture
	var image := texture.get_image()
	if not image:
		push_warning("CardboardCutout: Could not get image from texture")
		return

	# Set default mesh_size from texture dimensions if texture changed
	if texture != _last_texture:
		_last_texture = texture
		var width_pixels := image.get_width()
		var height_pixels := image.get_height()
		mesh_size = Vector2(width_pixels * 0.01, height_pixels * 0.01)
		print("CardboardCutout: Set default mesh_size to ", mesh_size, " from texture dimensions")

	# Decompress if compressed (required for get_pixel())
	if image.is_compressed():
		image.decompress()

	# Extract contour based on selected method
	var contour: PackedVector2Array
	match cutout_method:
		CutoutMethod.CONTOUR_FOLLOWING:
			contour = ContourUtils.extract_contour(image, alpha_threshold)

	print("CardboardCutout: Contour has ", contour.size(), " points")

	if contour.is_empty():
		push_warning("CardboardCutout: No contour found in texture")
		return

	# Simplify the contour
	var simplified := ContourUtils.simplify_polygon(contour, detail_threshold)
	print("CardboardCutout: Simplified to ", simplified.size(), " points")

	# Apply smoothing if algorithm is set
	if smooth_algorithm:
		simplified = smooth_algorithm.smooth(simplified)
		print("CardboardCutout: Smoothed polygon has ", simplified.size(), " points")

	# Generate 3D mesh from simplified contour
	var mesh := _generate_3d_mesh(simplified, image)
	if mesh:
		print("CardboardCutout: Mesh generated successfully with ", mesh.get_surface_count(), " surface(s)")
		_mesh_instance.mesh = mesh
	else:
		push_warning("CardboardCutout: Mesh generation failed")

	# Set up material
	_setup_material()


# Generate 3D mesh from 2D polygon with depth extrusion
func _generate_3d_mesh(polygon: PackedVector2Array, image: Image) -> ArrayMesh:
	if polygon.size() < 3:
		print("CardboardCutout: Not enough points for mesh (", polygon.size(), ")")
		return null

	print("CardboardCutout: Generating mesh from ", polygon.size(), " points with depth ", depth)

	var mesh := ArrayMesh.new()
	var width := float(image.get_width())
	var height := float(image.get_height())
	var half_depth := depth * 0.5

	# Handle any polygon (not just quads)
	if polygon.size() >= 3:
		# First, convert polygon points to 2D vertices
		var vertices_2d := PackedVector2Array()
		var uvs := PackedVector2Array()

		# Process all polygon points
		for i in range(polygon.size()):
			var p := polygon[i]

			# Vertex position: scale from pixel space to mesh_size
			var vertex_x := ((p.x - width/2.0) / width) * mesh_size.x * 2.0
			var vertex_y := -((p.y - height/2.0) / height) * mesh_size.y * 2.0  # Negative for Y-up

			vertices_2d.append(Vector2(vertex_x, vertex_y))

			# UV: direct mapping from pixel position to 0-1
			uvs.append(Vector2(p.x / width, p.y / height))

		# Triangulate the polygon with fallback methods
		var triangles := ContourUtils.triangulate_with_fallbacks(vertices_2d)
		if triangles.is_empty():
			print("CardboardCutout: All triangulation methods failed")
			return null

		print("CardboardCutout: Triangulated into ", triangles.size() / 3, " triangles")

		# SURFACE 0: Front and back faces (textured)
		var face_vertices := PackedVector3Array()
		var face_uvs := PackedVector2Array()
		var face_normals := PackedVector3Array()
		var face_indices := PackedInt32Array()

		# Front face (z = +half_depth)
		for i in range(vertices_2d.size()):
			face_vertices.append(Vector3(vertices_2d[i].x, vertices_2d[i].y, half_depth))
			face_uvs.append(uvs[i])
			face_normals.append(Vector3(0, 0, 1))

		# Front face triangles using triangulation
		face_indices.append_array(triangles)

		# Back face (z = -half_depth)
		var back_start := vertices_2d.size()
		for i in range(vertices_2d.size()):
			face_vertices.append(Vector3(vertices_2d[i].x, vertices_2d[i].y, -half_depth))
			face_uvs.append(uvs[i])
			face_normals.append(Vector3(0, 0, -1))

		# Back face triangles (reversed winding)
		for i in range(0, triangles.size(), 3):
			face_indices.append(back_start + triangles[i])
			face_indices.append(back_start + triangles[i + 2])  # Reversed
			face_indices.append(back_start + triangles[i + 1])  # Reversed

		# Create face surface
		var face_arrays := []
		face_arrays.resize(Mesh.ARRAY_MAX)
		face_arrays[Mesh.ARRAY_VERTEX] = face_vertices
		face_arrays[Mesh.ARRAY_TEX_UV] = face_uvs
		face_arrays[Mesh.ARRAY_NORMAL] = face_normals
		face_arrays[Mesh.ARRAY_INDEX] = face_indices

		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, face_arrays)

		# SURFACE 1: Side walls (solid color)
		var side_vertices := PackedVector3Array()
		var side_normals := PackedVector3Array()
		var side_uvs := PackedVector2Array()

		# Create side walls for each edge
		var perimeter_distance := 0.0  # Track distance along perimeter for UV mapping

		for i in range(vertices_2d.size()):
			var next_i := (i + 1) % vertices_2d.size()
			var v1 := vertices_2d[i]
			var v2 := vertices_2d[next_i]

			# Calculate edge length for UV mapping
			var edge_length := (v2 - v1).length()

			# Calculate edge normal (perpendicular, facing outward)
			var edge := v2 - v1
			var normal := Vector3(-edge.y, edge.x, 0).normalized()

			# Create quad vertices for this edge
			var v1_front := Vector3(v1.x, v1.y, half_depth)
			var v2_front := Vector3(v2.x, v2.y, half_depth)
			var v1_back := Vector3(v1.x, v1.y, -half_depth)
			var v2_back := Vector3(v2.x, v2.y, -half_depth)

			# Calculate UVs for tiled texture
			# U coordinate: distance along perimeter (scaled by texture scale)
			# V coordinate: depth position (0 at front, 1 at back)
			var u1 := perimeter_distance * extrusion_texture_scale
			var u2 := (perimeter_distance + edge_length) * extrusion_texture_scale
			var v_front := 0.0
			var v_back := 1.0  # Simple 0-1 mapping across depth

			# Add two triangles for this edge quad
			# Triangle 1: v1_front, v1_back, v2_front
			side_vertices.append_array([v1_front, v1_back, v2_front])
			side_normals.append_array([normal, normal, normal])
			side_uvs.append_array([
				Vector2(u1, v_front),  # v1_front
				Vector2(u1, v_back),   # v1_back
				Vector2(u2, v_front)   # v2_front
			])

			# Triangle 2: v2_front, v1_back, v2_back
			side_vertices.append_array([v2_front, v1_back, v2_back])
			side_normals.append_array([normal, normal, normal])
			side_uvs.append_array([
				Vector2(u2, v_front),  # v2_front
				Vector2(u1, v_back),   # v1_back
				Vector2(u2, v_back)    # v2_back
			])

			# Update perimeter distance for next edge
			perimeter_distance += edge_length

		# Create side surface
		var side_arrays := []
		side_arrays.resize(Mesh.ARRAY_MAX)
		side_arrays[Mesh.ARRAY_VERTEX] = side_vertices
		side_arrays[Mesh.ARRAY_NORMAL] = side_normals
		side_arrays[Mesh.ARRAY_TEX_UV] = side_uvs

		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, side_arrays)

		print("CardboardCutout: Mesh created with ", face_vertices.size() + side_vertices.size(), " vertices (", face_vertices.size(), " face, ", side_vertices.size(), " side)")
		print("CardboardCutout: Mesh has ", mesh.get_surface_count(), " surfaces")

		# Verify surfaces
		for i in range(mesh.get_surface_count()):
			var array_len := mesh.surface_get_array_len(i)
			print("  Surface ", i, ": ", array_len, " vertices")

	return mesh


func _setup_material() -> void:
	if not _mesh_instance or not _mesh_instance.mesh or not texture:
		return

	var mesh := _mesh_instance.mesh
	if mesh.get_surface_count() < 1:
		return

	# Material for faces (surface 0) - textured
	var face_material := StandardMaterial3D.new()
	face_material.resource_local_to_scene = true
	face_material.albedo_texture = texture
	face_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	face_material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Show both sides

	_mesh_instance.set_surface_override_material(0, face_material)

	# Material for sides (surface 1) - solid color or textured
	if mesh.get_surface_count() >= 2:
		var side_material := StandardMaterial3D.new()
		side_material.resource_local_to_scene = true

		if extrusion_texture:
			side_material.albedo_texture = extrusion_texture
		else:
			side_material.albedo_color = side_color

		side_material.roughness = 0.9
		side_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		side_material.cull_mode = BaseMaterial3D.CULL_DISABLED

		_mesh_instance.set_surface_override_material(1, side_material)

	print("CardboardCutout: Materials set up for ", mesh.get_surface_count(), " surfaces")


func _on_smooth_algorithm_changed() -> void:
	_regenerate_mesh()
