@tool
class_name MeshPreview3D
extends Node3D

## 3D preview container for displaying CutoutMesh in the dock.
## Manages lighting, environment, and the CutoutMeshInstance3D.

## Reference to the CutoutMeshInstance3D child
var _mesh_instance: CutoutMeshInstance3D

## Reference to the directional light
var _light: DirectionalLight3D

## The CutoutMesh being previewed
var _cutout_mesh: CutoutMesh


func _ready() -> void:
	_setup_scene()


func _setup_scene() -> void:
	# Create directional light if not exists
	if not _light:
		_light = DirectionalLight3D.new()
		_light.name = "PreviewLight"
		_light.rotation_degrees = Vector3(-45, -45, 0)
		_light.light_energy = 1.0
		_light.shadow_enabled = false
		add_child(_light)

	# Create CutoutMeshInstance3D if not exists
	if not _mesh_instance:
		_mesh_instance = CutoutMeshInstance3D.new()
		_mesh_instance.name = "PreviewMeshInstance"
		add_child(_mesh_instance)


## Set the CutoutMesh to preview
func set_cutout_mesh(mesh: CutoutMesh) -> void:
	_cutout_mesh = mesh

	if not _mesh_instance:
		_setup_scene()

	_mesh_instance.cutout_mesh = mesh


## Get the current CutoutMesh
func get_cutout_mesh() -> CutoutMesh:
	return _cutout_mesh


## Clear the preview
func clear() -> void:
	_cutout_mesh = null
	if _mesh_instance:
		_mesh_instance.cutout_mesh = null


## Get the bounds of the current mesh for camera fitting
func get_mesh_bounds() -> AABB:
	if not _cutout_mesh:
		return AABB(Vector3.ZERO, Vector3.ONE)

	var mesh_size := _cutout_mesh.mesh_size
	var depth := _cutout_mesh.depth

	# Mesh is centered at origin, extends from -depth/2 to +depth/2 in Z
	var half_size := Vector3(mesh_size.x / 2.0, mesh_size.y / 2.0, depth / 2.0)
	return AABB(-half_size, half_size * 2.0)


## Get the center point of the mesh
func get_mesh_center() -> Vector3:
	return Vector3.ZERO  # Mesh is always centered at origin
