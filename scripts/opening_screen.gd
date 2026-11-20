extends Control

enum SortOrder { NEWEST, OLDEST, MANUAL }

const PREFERENCES := "user://developer_catalog.cfg"
const EXPORTED_DATES := "res://developer_build_dates.cfg"

## Uncheck Listed to retire a build.
@export var builds: Array[DeveloperBuild]

@onready var _opening: Control = %Opening
@onready var _library: Control = %Library
@onready var _play_button: Button = %Play
@onready var _developers_button: Button = %DevelopersPage
@onready var _back_button: Button = %Back
@onready var _catalog: VBoxContainer = %Catalog
@onready var _notice: Label = %Notice
@onready var _sort: OptionButton = %SortOrder
@onready var _scroll: ScrollContainer = %Scroll
@onready var _edit: ConfirmationDialog = %EditBuild
@onready var _edit_title: LineEdit = %EditTitle
@onready var _edit_summary: TextEdit = %EditSummary

var _preferences := ConfigFile.new()
var _featured: DeveloperBuild
var _editing: DeveloperBuild
var _first_build_button: Button


func _ready() -> void:
	var result := _preferences.load(PREFERENCES)
	if result != OK and result != ERR_FILE_NOT_FOUND:
		_show_notice("Could not read catalog preferences. " + error_string(result))
	_developers_button.pressed.connect(_show_library)
	_back_button.pressed.connect(_show_opening)
	_play_button.pressed.connect(func(): _play(_featured))
	%Quit.pressed.connect(get_tree().quit)
	_sort.add_item("Newest first", SortOrder.NEWEST)
	_sort.add_item("Oldest first", SortOrder.OLDEST)
	_sort.add_item("Manual order", SortOrder.MANUAL)
	_sort.select(clampi(_preferences.get_value("catalog", "sort", SortOrder.NEWEST), 0, 2))
	_sort.item_selected.connect(_change_sort)
	_edit.confirmed.connect(_save_edit)
	_edit_title.text_changed.connect(func(value: String):
		_edit.get_ok_button().disabled = value.strip_edges().is_empty()
	)
	_build_catalog()
	if BuildLauncher.consume_return():
		_show_library()
	else:
		_show_opening()


func _build_catalog() -> void:
	for child in _catalog.get_children():
		_catalog.remove_child(child)
		child.queue_free()
	_first_build_button = null

	var available: Array[DeveloperBuild] = []
	var dates: Dictionary[String, int] = {}
	var positions: Dictionary[String, int] = {}
	var exported_dates := ConfigFile.new()
	if FileAccess.file_exists(EXPORTED_DATES):
		exported_dates.load(EXPORTED_DATES)
	for index in builds.size():
		var build := builds[index]
		if build != null and build.is_available() and not positions.has(build.scene_path):
			available.append(build)
			dates[build.scene_path] = build.build_time(exported_dates.get_value("dates", build.scene_path, 0))
			positions[build.scene_path] = index
	available.sort_custom(func(a: DeveloperBuild, b: DeveloperBuild) -> bool:
		var a_time := dates[a.scene_path]
		var b_time := dates[b.scene_path]
		# Without a timestamp, use registration order. New undated entries are appended.
		if a_time == b_time:
			return positions[a.scene_path] > positions[b.scene_path]
		if a_time == 0 or b_time == 0:
			return a_time == 0
		return a_time > b_time
	)
	_featured = null if available.is_empty() else available[0]
	_play_button.visible = _featured != null
	if _featured != null:
		_play_button.text = "%s %s" % [_featured.action, _title(_featured)]
		_play_button.tooltip_text = _play_button.text
		var font := _play_button.get_theme_font("font")
		var font_size := _play_button.get_theme_font_size("font_size")
		var text_width := font.get_string_size(_play_button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		_play_button.custom_minimum_size.x = clampf(text_width + 40.0, 280.0, _opening.size.x)

	if _sort.selected == SortOrder.OLDEST:
		available.reverse()
	var sections: Dictionary[String, Array] = {}
	for build in available:
		if not sections.has(build.section):
			sections[build.section] = []
		sections[build.section].append(build)
	var section_names := sections.keys()
	if _sort.selected == SortOrder.MANUAL:
		var saved: PackedStringArray = _preferences.get_value("ordering", "sections", PackedStringArray())
		_apply_order(section_names, saved, func(section: String): return section)

	for section: String in section_names:
		var group := VBoxContainer.new()
		group.set_meta("catalog_key", section)
		group.add_theme_constant_override("separation", 9)
		_catalog.add_child(group)
		var heading := _label("↕  " + section, "SectionLabel", 16)
		group.add_child(heading)
		_enable_reorder(heading, group, section, "sections")
		var cards: Array = sections[section]
		if _sort.selected == SortOrder.MANUAL:
			var saved: PackedStringArray = _preferences.get_value("card_order", section, PackedStringArray())
			_apply_order(cards, saved, func(build: DeveloperBuild): return build.scene_path)
		for build: DeveloperBuild in cards:
			var button := _add_card(group, build, dates[build.scene_path])
			if _first_build_button == null:
				_first_build_button = button
	if available.is_empty():
		_catalog.add_child(_label("No builds are currently available.", "MutedLabel", 18))


func _apply_order(items: Array, saved: PackedStringArray, key: Callable) -> void:
	var ranks := {}
	# Unranked entries retain their default order at the top of the list.
	for index in items.size():
		var id: String = key.call(items[index])
		var saved_index := saved.find(id)
		ranks[id] = index if saved_index == -1 else items.size() + saved_index
	items.sort_custom(func(a, b): return ranks[key.call(a)] < ranks[key.call(b)])


func _add_card(group: VBoxContainer, build: DeveloperBuild, timestamp: int) -> Button:
	var card := PanelContainer.new()
	card.set_meta("catalog_key", build.scene_path)
	group.add_child(card)
	_enable_reorder(card, card, _title(build), "card_order")

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var details := VBoxContainer.new()
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 2)
	row.add_child(details)
	details.add_child(_label("↕  " + _title(build), "DisplayLabel", 22))
	var summary: String = _preferences.get_value("summaries", build.scene_path, build.summary)
	if not summary.is_empty():
		details.add_child(_label(summary, "", 16))
	var date := "Build date unknown"
	if timestamp > 0:
		date = Time.get_datetime_string_from_unix_time(timestamp, true).left(16) + " UTC"
	var credit := "AI: %s  ·  " % build.credit if not build.credit.is_empty() else ""
	details.add_child(_label(credit + date, "MutedLabel", 14))

	var edit_button := Button.new()
	edit_button.text = "Edit"
	edit_button.theme_type_variation = &"QuietButton"
	edit_button.custom_minimum_size = Vector2(58, 36)
	edit_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	edit_button.tooltip_text = "Edit title and description"
	edit_button.pressed.connect(_start_edit.bind(build))
	row.add_child(edit_button)

	var button := Button.new()
	button.text = build.action
	button.custom_minimum_size = Vector2(72, 36)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.tooltip_text = build.action + " " + _title(build)
	button.pressed.connect(_play.bind(build))
	row.add_child(button)
	return button


func _enable_reorder(handle: Control, item: Control, caption: String, order_type: String) -> void:
	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	handle.mouse_force_pass_scroll_events = true
	handle.tooltip_text = "Drag above or below another " + ("section" if order_type == "sections" else "build in this section")
	handle.set_drag_forwarding(
		func(_position: Vector2):
			var preview := PanelContainer.new()
			preview.theme = theme
			var label := _label(caption, "", 16)
			label.custom_minimum_size.x = 210
			preview.add_child(label)
			handle.set_drag_preview(preview)
			return item,
		func(_position: Vector2, data: Variant):
			return data is Control and data != item and data.get_parent() == item.get_parent(),
		func(position: Vector2, data: Variant):
			_reorder(data, item, position.y >= handle.size.y / 2.0, order_type)
	)


func _reorder(source: Control, target: Control, below: bool, order_type: String) -> void:
	var container := target.get_parent()
	var keys := PackedStringArray()
	for child in container.get_children():
		if child != source and child.has_meta("catalog_key"):
			keys.append(child.get_meta("catalog_key"))
	var target_index := keys.find(target.get_meta("catalog_key"))
	keys.insert(target_index + int(below), source.get_meta("catalog_key"))
	if order_type == "sections":
		_preferences.set_value("ordering", "sections", keys)
	else:
		_preferences.set_value("card_order", container.get_meta("catalog_key"), keys)
	_sort.select(SortOrder.MANUAL)
	_save_sort()
	_refresh_at_scroll.call_deferred()


func _process(delta: float) -> void:
	if not _library.visible or not get_viewport().gui_is_dragging():
		return
	var mouse := _scroll.get_local_mouse_position()
	if Rect2(Vector2.ZERO, _scroll.size).has_point(mouse):
		var direction := int(mouse.y > _scroll.size.y - 40) - int(mouse.y < 40)
		_scroll.scroll_vertical += roundi(direction * 650.0 * delta)


func _change_sort(_index: int) -> void:
	_save_sort()
	_scroll.scroll_vertical = 0
	_build_catalog()


func _save_sort() -> void:
	_preferences.set_value("catalog", "sort", _sort.selected)
	_save_preferences()


func _start_edit(build: DeveloperBuild) -> void:
	_editing = build
	_edit_title.text = _title(build)
	_edit_summary.text = _preferences.get_value("summaries", build.scene_path, build.summary)
	_edit.get_ok_button().disabled = _edit_title.text.strip_edges().is_empty()
	_edit.popup_centered()
	_edit_title.grab_focus()
	_edit_title.select_all()


func _save_edit() -> void:
	var title := _edit_title.text.strip_edges()
	if title.is_empty():
		return
	_preferences.set_value("titles", _editing.scene_path, title)
	_preferences.set_value("summaries", _editing.scene_path, _edit_summary.text.strip_edges())
	_save_preferences()
	_refresh_at_scroll()


func _refresh_at_scroll() -> void:
	var scroll_position := _scroll.scroll_vertical
	_build_catalog()
	_scroll.set_deferred("scroll_vertical", scroll_position)


func _save_preferences() -> void:
	var result := _preferences.save(PREFERENCES)
	if result != OK:
		_show_notice("Could not save catalog changes. " + error_string(result))


func _title(build: DeveloperBuild) -> String:
	return _preferences.get_value("titles", build.scene_path, build.title)


func _label(value: String, variation: StringName, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.theme_type_variation = variation
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _play(build: DeveloperBuild) -> void:
	var result := BuildLauncher.launch(build)
	if result != OK:
		_show_library()
		_show_notice("Could not open %s. %s" % [_title(build), error_string(result)])


func _show_notice(message: String) -> void:
	_notice.text = message
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
	_opening.show()
	if _play_button.visible:
		_play_button.grab_focus()
	else:
		_developers_button.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if _library.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_show_opening()
