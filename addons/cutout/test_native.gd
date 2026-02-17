@tool
extends EditorScript

## Test script to verify Rust GDExtension is loaded correctly
## Run this from the Godot editor: File > Run Script

func _run() -> void:
	var separator = "============================================================"
	print(separator)
	print("Testing Cutout Native Extension")
	print(separator)

	# Check if native class exists
	if ClassDB.class_exists("CutoutNative"):
		print("✓ CutoutNative class found!")

		var native = CutoutNative.new()
		print("✓ Created CutoutNative instance")

		var message = native.hello_cutout()
		print("✓ Called hello_cutout(): ", message)

		var version = native.get_version()
		print("✓ Extension version: ", version)

		print("")
		print("SUCCESS: Rust GDExtension is working correctly!")
	else:
		print("✗ CutoutNative class not found")
		print("")
		print("TROUBLESHOOTING:")
		print("1. Check that cutout.gdextension exists in addons/cutout/")
		print("2. Check that the binary exists in addons/cutout/bin/")
		print("3. Restart Godot editor")
		print("4. Check the Output tab for loading errors")

	print(separator)
