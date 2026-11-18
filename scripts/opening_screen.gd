extends Control

## Cards are grouped by section and ordered by milestone. Uncheck Listed to retire a build.
@export var builds: Array[DeveloperBuild]

@onready var _opening: Control = %Opening
@onready var _library: Control = %Library
@onready var _play_button: Button = %Play
@onready var _developers_button: Button = %DevelopersPage
@onready var _back_button: Button = %Back
@onready var _catalog: VBoxContainer = %Catalog
@onready var _notice: Label = %Notice

var _first_build_button: Button


func _ready() -> void:
	_developers_button.pressed.connect(_show_library)
	_back_button.pressed.connect(_show_opening)
	%Quit.pressed.connect(get_tree().quit)
	_build_catalog()
	if BuildLauncher.consume_return():
		_show_library()
	else:
		_show_opening()


func _build_catalog() -> void:
	var sections: Dictionary[String, VBoxContainer] = {}
	var available: Array[DeveloperBuild] = []
	for build in builds:
		if build != null and build.is_available():
			available.append(build)
	available.sort_custom(func(a: DeveloperBuild, b: DeveloperBuild) -> bool:
		if a.milestone_utc == b.milestone_utc:
			return a.title < b.title
		return a.milestone_utc > b.milestone_utc
	)
	var latest: DeveloperBuild
	for build in available:
		if not sections.has(build.section):
			var group := VBoxContainer.new()
			group.add_theme_constant_override("separation", 9)
			group.add_child(_label(build.section, "SectionLabel", 16))
			_catalog.add_child(group)
			sections[build.section] = group
		var button := _add_card(sections[build.section], build)
		if _first_build_button == null:
			_first_build_button = button
		if latest == null and build.action == "Play":
			latest = build
	_play_button.visible = latest != null
	if latest != null:
		_play_button.text = "Play " + latest.title
		_play_button.pressed.connect(_play.bind(latest))
	if _first_build_button == null:
		_catalog.add_child(_label("No builds are currently available.", "MutedLabel", 18))


func _add_card(group: VBoxContainer, build: DeveloperBuild) -> Button:
	var card := PanelContainer.new()
	group.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 2)
	row.add_child(details)
	details.add_child(_label(build.title, "DisplayLabel", 22))
	details.add_child(_label(build.summary, "", 16))
	var milestone := "Local study" if build.milestone_utc.is_empty() else build.milestone_utc + " UTC"
	details.add_child(_label("AI: %s  ·  %s" % [build.credit, milestone], "MutedLabel", 14))
	var button := Button.new()
	button.text = build.action
	button.custom_minimum_size = Vector2(86, 36)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.tooltip_text = build.action + " " + build.title
	button.pressed.connect(_play.bind(build))
	row.add_child(button)
	return button


func _label(value: String, variation: StringName, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.theme_type_variation = variation
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _play(build: DeveloperBuild) -> void:
	var result := BuildLauncher.launch(build)
	if result != OK:
		_show_library()
		_notice.text = "Could not open %s. %s" % [build.title, error_string(result)]
		_notice.show()


func _show_library() -> void:
	_opening.hide()
	_library.show()
	if _first_build_button:
		_first_build_button.grab_focus()
	else:
		_back_button.grab_focus()


func _show_opening() -> void:
	_library.hide()
	_notice.hide()
	_opening.show()
	if _play_button.visible:
		_play_button.grab_focus()
	else:
		_developers_button.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if _library.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_show_opening()
