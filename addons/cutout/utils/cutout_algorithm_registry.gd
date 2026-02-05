@tool
class_name CutoutAlgorithmRegistry
extends RefCounted

## Discovers and manages cutout pipeline algorithms at runtime.
## Uses ProjectSettings.get_global_class_list() to find all GDScript classes
## that inherit from the algorithm base classes.

## Information about a discovered algorithm
class AlgorithmInfo:
	var algorithm_class: String
	var script_path: String
	var display_name: String

	func _init(p_class_name: String, p_script_path: String, p_display_name: String = "") -> void:
		algorithm_class = p_class_name
		script_path = p_script_path
		display_name = p_display_name if p_display_name != "" else _format_class_name(p_class_name)

	func _format_class_name(name: String) -> String:
		# Convert "CutoutContourMooreNeighbour" to "Moore Neighbour"
		# Remove common prefixes
		var prefixes := ["CutoutContour", "CutoutPolysimp", "CutoutSmooth", "Cutout"]
		for prefix in prefixes:
			if name.begins_with(prefix):
				name = name.substr(prefix.length())
				break

		# Insert spaces before capital letters
		var result := ""
		for i in range(name.length()):
			var c := name[i]
			if i > 0 and c == c.to_upper() and c != c.to_lower():
				result += " "
			result += c

		return result.strip_edges()

	func create_instance() -> Resource:
		var script := load(script_path) as GDScript
		if script:
			return script.new()
		return null


# Cache for discovered algorithms
static var _contour_algorithms: Array[AlgorithmInfo] = []
static var _polysimp_algorithms: Array[AlgorithmInfo] = []
static var _smooth_algorithms: Array[AlgorithmInfo] = []
static var _cache_valid: bool = false


## Get all contour algorithms (classes inheriting from CutoutContourAlgorithm)
static func get_contour_algorithms() -> Array[AlgorithmInfo]:
	_ensure_cache()
	return _contour_algorithms


## Get all polygon simplification algorithms (classes inheriting from CutoutPolysimpAlgorithm)
static func get_polysimp_algorithms() -> Array[AlgorithmInfo]:
	_ensure_cache()
	return _polysimp_algorithms


## Get all smoothing algorithms (classes inheriting from CutoutSmoothAlgorithm)
static func get_smooth_algorithms() -> Array[AlgorithmInfo]:
	_ensure_cache()
	return _smooth_algorithms


## Force refresh of the algorithm cache (call after adding new algorithm scripts)
static func refresh_cache() -> void:
	_cache_valid = false
	_contour_algorithms.clear()
	_polysimp_algorithms.clear()
	_smooth_algorithms.clear()
	_ensure_cache()


## Ensure cache is populated
static func _ensure_cache() -> void:
	if _cache_valid:
		return

	_discover_algorithms()
	_cache_valid = true


## Discover all algorithm classes from the global class list
static func _discover_algorithms() -> void:
	var global_classes := ProjectSettings.get_global_class_list()

	# Build a map of class_name -> {path, base} for quick lookup
	var class_map: Dictionary = {}
	for class_info: Dictionary in global_classes:
		var cname: String = class_info.get("class", "")
		if cname != "":
			class_map[cname] = {
				"path": class_info.get("path", ""),
				"base": class_info.get("base", "")
			}

	# Check each class to see if it inherits from our base classes
	for class_info: Dictionary in global_classes:
		var cname: String = class_info.get("class", "")
		var path: String = class_info.get("path", "")

		if cname == "" or path == "":
			continue

		# Skip the base classes themselves
		if cname in ["CutoutContourAlgorithm", "CutoutPolysimpAlgorithm", "CutoutSmoothAlgorithm"]:
			continue

		# Check inheritance chain
		if _inherits_from(cname, "CutoutContourAlgorithm", class_map):
			var info := _create_algorithm_info(cname, path)
			if info:
				_contour_algorithms.append(info)
		elif _inherits_from(cname, "CutoutPolysimpAlgorithm", class_map):
			var info := _create_algorithm_info(cname, path)
			if info:
				_polysimp_algorithms.append(info)
		elif _inherits_from(cname, "CutoutSmoothAlgorithm", class_map):
			var info := _create_algorithm_info(cname, path)
			if info:
				_smooth_algorithms.append(info)

	# Sort by display name for consistent ordering
	_contour_algorithms.sort_custom(func(a: AlgorithmInfo, b: AlgorithmInfo) -> bool:
		return a.display_name.naturalcasecmp_to(b.display_name) < 0
	)
	_polysimp_algorithms.sort_custom(func(a: AlgorithmInfo, b: AlgorithmInfo) -> bool:
		return a.display_name.naturalcasecmp_to(b.display_name) < 0
	)
	_smooth_algorithms.sort_custom(func(a: AlgorithmInfo, b: AlgorithmInfo) -> bool:
		return a.display_name.naturalcasecmp_to(b.display_name) < 0
	)


## Check if a class inherits from a target base class (traverses inheritance chain)
static func _inherits_from(cls_name: String, target_base: String, class_map: Dictionary) -> bool:
	var current := cls_name
	var visited: Dictionary = {}  # Prevent infinite loops

	while current != "" and current not in visited:
		visited[current] = true

		if not class_map.has(current):
			# Reached a native class or unknown - stop
			return false

		var base: String = class_map[current].get("base", "")
		if base == target_base:
			return true

		current = base

	return false


## Create an AlgorithmInfo, extracting display name from script if available
static func _create_algorithm_info(cname: String, path: String) -> AlgorithmInfo:
	var display_name := ""

	# Try to load the script and check for DISPLAY_NAME constant
	var script := load(path) as GDScript
	if script:
		# Check if the script has a DISPLAY_NAME constant
		var constants := script.get_script_constant_map()
		if constants.has("DISPLAY_NAME"):
			display_name = str(constants["DISPLAY_NAME"])

	return AlgorithmInfo.new(cname, path, display_name)
