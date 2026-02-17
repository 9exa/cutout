@tool
extends EditorScript

## Utility script to create the required assets for the destruction showcase
## Run this script in the Godot editor to generate the texture and sound placeholders

const CutoutMesh = preload("res://addons/cutout/resources/cutout_mesh.gd")


func _run() -> void:
	print("Creating assets for destruction showcase...")

	# Create target texture
	create_target_texture()

	# Create default cutout mesh resource
	create_default_cutout_mesh()

	# Create sound note
	create_sound_note()

	print("Assets created successfully!")
	print("Note: You'll need to add an actual explosion sound file (explosion.ogg)")


func create_target_texture() -> void:
	var image := Image.create(512, 512, false, Image.FORMAT_RGBA8)

	# Create a target/bullseye pattern
	var center := Vector2(256, 256)
	var colors := [
		Color(1.0, 0.2, 0.2),  # Red
		Color(1.0, 1.0, 1.0),  # White
		Color(1.0, 0.2, 0.2),  # Red
		Color(1.0, 1.0, 1.0),  # White
		Color(0.2, 0.2, 1.0),  # Blue (center)
	]

	for x in range(512):
		for y in range(512):
			var pos := Vector2(x, y)
			var dist := pos.distance_to(center)

			var color_index := 0
			if dist < 50:
				color_index = 4  # Blue center
			elif dist < 100:
				color_index = 3
			elif dist < 150:
				color_index = 2
			elif dist < 200:
				color_index = 1
			else:
				color_index = 0

			if dist < 250:
				image.set_pixel(x, y, colors[color_index])
			else:
				image.set_pixel(x, y, Color(0.8, 0.8, 0.8, 1.0))

	# Save the texture
	var texture := ImageTexture.create_from_image(image)
	ResourceSaver.save(texture, "res://addons/cutout/demo_project/examples/destruction/target_texture.png")
	print("Created target_texture.png")


func create_default_cutout_mesh() -> void:
	var cutout_mesh := CutoutMesh.new()

	# Load or create texture
	var texture_path := "res://addons/cutout/demo_project/examples/destruction/target_texture.png"
	if ResourceLoader.exists(texture_path):
		cutout_mesh.texture = load(texture_path)
	else:
		# Create a simple white texture if target doesn't exist
		var image := Image.create(256, 256, false, Image.FORMAT_RGB8)
		image.fill(Color.WHITE)
		cutout_mesh.texture = ImageTexture.create_from_image(image)

	# Create a star-shaped polygon
	var outer_polygon := create_star_polygon(Vector2(256, 256), 200, 100, 8)
	cutout_mesh.mask = [outer_polygon]
	cutout_mesh.depth = 0.5
	cutout_mesh.mesh_size = Vector2(3, 3)
	cutout_mesh.extrusion_texture_scale = 1.0

	# Save the resource
	ResourceSaver.save(cutout_mesh, "res://addons/cutout/demo_project/examples/destruction/default_cutout.tres")
	print("Created default_cutout.tres")


func create_star_polygon(center: Vector2, outer_radius: float, inner_radius: float, points: int) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var angle_step := TAU / (points * 2)

	for i in range(points * 2):
		var angle := i * angle_step - PI / 2
		var radius := outer_radius if i % 2 == 0 else inner_radius
		var point := center + Vector2(cos(angle), sin(angle)) * radius
		polygon.append(point)

	return polygon


func create_sound_note() -> void:
	var note := "# Explosion Sound

To complete the destruction showcase, you need to add an explosion sound file:

1. Find or create an explosion sound effect (WAV or OGG format recommended)
2. Name it 'explosion.ogg'
3. Place it in the 'examples/destruction/' folder
4. The destructible_cutout.gd script will automatically use it

Recommended free sound sources:
- Freesound.org
- OpenGameArt.org
- Zapsplat.com (requires free account)

Search for terms like:
- 'explosion'
- 'impact'
- 'crash'
- 'shatter'
- 'destruction'

The sound should be short (1-2 seconds) and punchy for best effect.
"

	var file := FileAccess.open("res://addons/cutout/demo_project/examples/destruction/SOUND_NOTE.txt", FileAccess.WRITE)
	if file:
		file.store_string(note)
		file.close()
		print("Created SOUND_NOTE.txt with instructions for adding explosion sound")
