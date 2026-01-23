# This file shows the expected UI structure for the collapsible cutout dock
# Each pipeline section should follow this pattern:
#
# VBoxContainer (Section Container)
#   ├─ Button (Section Header/Toggle Button)
#   └─ VBoxContainer (Section Content)
#       ├─ HBoxContainer (Algorithm Selector)
#       │   ├─ Label ("Algorithm:")
#       │   └─ OptionButton
#       └─ VBoxContainer (Parameters Container)
#           └─ [Dynamically generated parameter controls]
#
# Example scene structure:

# PipelineSection (VBoxContainer)
#   ContourSection (VBoxContainer)
#     ContourSectionButton (Button) - Text: "▼ Contour Extraction"
#     ContourSectionContent (VBoxContainer)
#       AlphaThreshold (HBoxContainer)
#         Label - Text: "Alpha Threshold:"
#         HSlider
#         Value (Label)
#       AlgorithmSelector (HBoxContainer)
#         Label - Text: "Algorithm:"
#         OptionButton
#
#   PreSimpSection (VBoxContainer)
#     PreSimpSectionButton (Button) - Text: "▼ Pre-Simplification (Mandatory)"
#     PreSimpSectionContent (VBoxContainer)
#       AlgorithmSelector (HBoxContainer)
#         Label - Text: "Algorithm:"
#         OptionButton
#       Parameters (VBoxContainer) - Empty, filled dynamically
#
#   SmoothSection (VBoxContainer)
#     SmoothSectionButton (Button) - Text: "▼ Smoothing (Mandatory)"
#     SmoothSectionContent (VBoxContainer)
#       AlgorithmSelector (HBoxContainer)
#         Label - Text: "Algorithm:"
#         OptionButton
#       Parameters (VBoxContainer) - Empty, filled dynamically
#
#   PostSimpSection (VBoxContainer)
#     PostSimpSectionButton (Button) - Text: "▼ Post-Simplification (Mandatory)"
#     PostSimpSectionContent (VBoxContainer)
#       AlgorithmSelector (HBoxContainer)
#         Label - Text: "Algorithm:"
#         OptionButton
#       Parameters (VBoxContainer) - Empty, filled dynamically

static func create_collapsible_section(title: String) -> VBoxContainer:
	var section = VBoxContainer.new()
	section.custom_minimum_size.y = 50

	# Header button
	var button = Button.new()
	button.text = "▼ " + title
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	section.add_child(button)

	# Content container
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	section.add_child(content)

	# Algorithm selector
	var algo_container = HBoxContainer.new()
	var algo_label = Label.new()
	algo_label.text = "Algorithm:"
	algo_label.custom_minimum_size.x = 100
	algo_container.add_child(algo_label)

	var algo_option = OptionButton.new()
	algo_option.custom_minimum_size.x = 200
	algo_container.add_child(algo_option)
	content.add_child(algo_container)

	# Parameters container (empty, filled dynamically)
	var params = VBoxContainer.new()
	params.add_theme_constant_override("separation", 5)
	content.add_child(params)

	return section