@tool
class_name CutoutMesh
extends Resource

## Reusable 3D mesh resource generated from a texture and 2D polygon mask.
##
## This resource encapsulates mesh generation logic and caches the resulting ArrayMesh
## for efficient reuse across multiple CutoutMeshInstance3D nodes. The mesh is automatically
## regenerated when properties change.
##
## WINDING ORDER: Expects clockwise (CW) polygon masks, consistent with Godot's
## convention where CW = solid and CCW = hole.

## The texture to map onto the front and back faces of the mesh.
@export var texture: Texture2D:
	set(value):
		texture = value
		_invalidate_mesh()

## Array of polygon masks defining the cutout shape(s).
## Each polygon should be a closed loop of 2D points in pixel coordinates.
## Multiple polygons can be used for shapes with holes (not yet implemented).
@export var mask: Array[PackedVector2Array]:
	set(value):
		mask = value
		_invalidate_mesh()

## Extrusion depth of the 3D mesh (thickness).
## The mesh will extend from -depth/2 to +depth/2 in the Z axis.
@export_range(0.01, 1.0, 0.01) var depth: float = 0.1:
	set(value):
		depth = value
		_invalidate_mesh()

## Physical size of the mesh in world units.
## The texture's pixel dimensions are scaled to match this size.
@export var mesh_size: Vector2 = Vector2(1.0, 1.0):
	set(value):
		mesh_size = value
		_invalidate_mesh()

## Texture scaling factor for the extrusion side walls.
## Higher values tile the texture more times around the perimeter.
@export_range(0.1, 10.0, 0.1) var extrusion_texture_scale: float = 1.0:
	set(value):
		extrusion_texture_scale = value
		_invalidate_mesh()

## Texture for the extrusion side walls.
## Use a 1x1 solid color texture for uniform color, or a gradient for varied effects.
@export var extrusion_texture: Texture2D:
	set(value):
		extrusion_texture = value
		_invalidate_materials()

# Internal cached mesh and materials
var _cached_mesh: ArrayMesh = null
var _mesh_dirty: bool = true
var _cached_face_material: StandardMaterial3D = null
var _cached_side_material: StandardMaterial3D = null
var _materials_dirty: bool = true


## Creates a CutoutMesh from a texture using the full contour extraction pipeline.
##
## This is a utility function for generating CutoutMesh resources from textures
## with parametric control over contour extraction, simplification, and smoothing.
##
## @param texture: The source texture to extract contours from
## @param alpha_threshold: Minimum alpha value to consider a pixel opaque (0.0-1.0)
## @param detail_threshold: Simplification tolerance (higher = simpler polygon)
## @param smooth_algorithm: Optional smoothing algorithm to apply to the polygon
## @param depth: Extrusion depth for the 3D mesh
## @param mesh_size: Physical size in world units (auto-calculated from texture if Vector2.ZERO)
## Returns the generated mesh, creating it if necessary.
## The mesh is cached and only regenerated when properties change.
func get_mesh() -> ArrayMesh:
	if _mesh_dirty or not _cached_mesh:
		_cached_mesh = generate_mesh()
		_mesh_dirty = false
	return _cached_mesh


## Marks the mesh as dirty, forcing regeneration on next get_mesh() call.
func _invalidate_mesh() -> void:
	_mesh_dirty = true
	emit_changed()


## Marks the materials as dirty, forcing regeneration on next get_*_material() call.
func _invalidate_materials() -> void:
	_cached_face_material = null
	_cached_side_material = null
	_materials_dirty = true
	emit_changed()


## Returns the face material (for front/back surfaces), creating it if necessary.
## The material is cached and shared across all instances using this CutoutMesh.
func get_face_material() -> StandardMaterial3D:
	if _materials_dirty or not _cached_face_material:
		_cached_face_material = _create_face_material()
		_materials_dirty = false
	return _cached_face_material


## Returns the side material (for extrusion walls), creating it if necessary.
## The material is cached and shared across all instances using this CutoutMesh.
func get_side_material() -> StandardMaterial3D:
	if _materials_dirty or not _cached_side_material:
		_cached_side_material = _create_side_material()
		_materials_dirty = false
	return _cached_side_material


## Creates the face material for textured front/back surfaces.
func _create_face_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()

	if texture:
		material.albedo_texture = texture

	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.cull_mode = BaseMaterial3D.CULL_BACK # Only show front

	return material


## Creates the side material for extrusion walls.
func _create_side_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()

	if extrusion_texture:
		material.albedo_texture = extrusion_texture
	else:
		# White fallback if no texture is set
		material.albedo_color = Color.WHITE

	material.roughness = 0.9
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	return material


## Generates the 3D mesh from the current texture and mask.
func generate_mesh() -> ArrayMesh:
	# Validation
	if not texture:
		push_warning("CutoutMesh: No texture set")
		return null

	if mask.is_empty() or mask[0].is_empty():
		push_warning("CutoutMesh: Empty mask")
		return null

	var image := texture.get_image()
	if not image:
		push_warning("CutoutMesh: Could not get image from texture")
		return null

	# Decompress if needed
	if image.is_compressed():
		image.decompress()

	# Use first polygon in mask (multi-polygon support future work)
	var polygon := mask[0]

	if polygon.size() < 3:
		push_warning("CutoutMesh: Polygon has less than 3 points")
		return null

	# Generate mesh
	return _generate_3d_mesh(polygon, image)


## Internal mesh generation implementation (moved from CardboardCutout).
func _generate_3d_mesh(polygon: PackedVector2Array, image: Image) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var width := float(image.get_width())
	var height := float(image.get_height())
	var half_depth := depth * 0.5

	# Convert polygon points to 2D vertices with proper scaling
	var vertices_2d := PackedVector2Array()
	var uvs := PackedVector2Array()

	for i in range(polygon.size()):
		var p := polygon[i]

		# Vertex position: scale from pixel space to mesh_size
		var vertex_x := ((p.x - width/2.0) / width) * mesh_size.x * 2.0
		var vertex_y := -((p.y - height/2.0) / height) * mesh_size.y * 2.0  # Negative for Y-up

		vertices_2d.append(Vector2(vertex_x, vertex_y))

		# UV: direct mapping from pixel position to 0-1
		uvs.append(Vector2(p.x / width, p.y / height))


	# Triangulate the polygon with fallback methods
	var triangles := CutoutGeometryUtils.triangulate_with_fallbacks(vertices_2d)
	if triangles.is_empty():
		push_warning("[CutoutMesh] Triangulation FAILED - all methods returned empty")
		return null

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
	# face_indices.append_array(triangles)
	for i in range(0, triangles.size(), 3):
		face_indices.append(triangles[i])
		face_indices.append(triangles[i + 2]) # Reversed. Clockwise
		face_indices.append(triangles[i + 1])

	# Back face (z = -half_depth)
	var back_start := vertices_2d.size()
	for i in range(vertices_2d.size()):
		face_vertices.append(Vector3(vertices_2d[i].x, vertices_2d[i].y, -half_depth))
		face_uvs.append(uvs[i])
		face_normals.append(Vector3(0, 0, -1))

	# Back face triangles (reversed winding for correct normals)
	for i in range(0, triangles.size(), 3):
		face_indices.append(back_start + triangles[i])
		face_indices.append(back_start + triangles[i + 1])  # Reversed
		face_indices.append(back_start + triangles[i + 2])  # Reversed

	# Create face surface
	var face_arrays := []
	face_arrays.resize(Mesh.ARRAY_MAX)
	face_arrays[Mesh.ARRAY_VERTEX] = face_vertices
	face_arrays[Mesh.ARRAY_TEX_UV] = face_uvs
	face_arrays[Mesh.ARRAY_NORMAL] = face_normals
	face_arrays[Mesh.ARRAY_INDEX] = face_indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, face_arrays)

	# SURFACE 1: Side walls
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

		# Calculate edge normal (perpendicular, facing outward for CW winding)
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

	return mesh
