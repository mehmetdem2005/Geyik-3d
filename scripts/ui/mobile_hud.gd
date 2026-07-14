class_name MobileHUD
extends CanvasLayer

const IVORY := Color("#f2e4c7")
const GOLD := Color("#c99a4e")
const FOREST := Color("#132a22")
const PANEL := Color(0.025, 0.055, 0.045, 0.84)
const DANGER := Color("#d85252")

var _root: Control
var _controls: Control
var _menu_overlay: Control
var _pause_overlay: Control
var _results_overlay: Control
var _health_bar: ProgressBar
var _health_label: Label
var _stamina_bar: ProgressBar
var _ammo_label: Label
var _population_label: Label
var _objective_title: Label
var _objective_detail: Label
var _interaction_label: Label
var _notification_label: Label
var _swim_label: Label
var _hit_marker: Label
var _blood_overlay: ColorRect
var _interact_button: Button
var _aim_button: Button
var _crouch_button: Button
var _results_title: Label
var _results_detail: Label
var _notification_time := 0.0
var _hit_time := 0.0
var _blood_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_connect_events()
	_apply_phase(GameState.phase)


func _process(delta: float) -> void:
	if _notification_time > 0.0:
		_notification_time -= delta
		if _notification_time <= 0.0:
			_notification_label.hide()
	if _hit_time > 0.0:
		_hit_time -= delta
		_hit_marker.modulate.a = clampf(_hit_time * 8.0, 0.0, 1.0)
	if _blood_time > 0.0:
		_blood_time -= delta
		_blood_overlay.modulate.a = clampf(_blood_time * 1.8, 0.0, 0.5)


func _connect_events() -> void:
	EventBus.game_phase_changed.connect(_apply_phase)
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.stamina_changed.connect(_on_stamina_changed)
	EventBus.ammo_changed.connect(_on_ammo_changed)
	EventBus.animal_population_changed.connect(_on_population_changed)
	EventBus.objective_updated.connect(_on_objective_updated)
	EventBus.interaction_prompt_changed.connect(_on_interaction_prompt)
	EventBus.notification_requested.connect(_on_notification)
	EventBus.swimming_changed.connect(_on_swimming_changed)
	EventBus.hit_marker_requested.connect(_on_hit_marker)
	EventBus.player_died.connect(_on_player_died)


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "MobileHUDRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_world_hud()
	_build_touch_controls()
	_build_menu()
	_build_pause_overlay()
	_build_results_overlay()


func _build_world_hud() -> void:
	var status_panel := PanelContainer.new()
	status_panel.add_theme_stylebox_override("panel", _style_box(PANEL, 14.0, GOLD.darkened(0.25), 1))
	status_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	status_panel.position = Vector2(20, 18)
	status_panel.size = Vector2(240, 130)
	_root.add_child(status_panel)
	var status_vbox := VBoxContainer.new()
	status_vbox.add_theme_constant_override("separation", 5)
	status_panel.add_child(status_vbox)
	_health_label = _label("CAN 100", 18, IVORY)
	status_vbox.add_child(_health_label)
	_health_bar = _progress_bar(Color("#42b66c"), 100.0)
	status_vbox.add_child(_health_bar)
	var stamina_label := _label("DAYANIKLILIK", 13, IVORY.darkened(0.1))
	status_vbox.add_child(stamina_label)
	_stamina_bar = _progress_bar(GOLD, 100.0)
	status_vbox.add_child(_stamina_bar)
	_population_label = _label("🦌 0   🐺 0   🐻 0", 17, IVORY)
	status_vbox.add_child(_population_label)

	var ammo_panel := PanelContainer.new()
	ammo_panel.add_theme_stylebox_override("panel", _style_box(PANEL, 14.0, GOLD.darkened(0.25), 1))
	ammo_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ammo_panel.position = Vector2(-230, 18)
	ammo_panel.size = Vector2(210, 84)
	_root.add_child(ammo_panel)
	var ammo_vbox := VBoxContainer.new()
	ammo_panel.add_child(ammo_vbox)
	var weapon_label := _label("ANADOLU .308", 15, IVORY.darkened(0.12))
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_vbox.add_child(weapon_label)
	_ammo_label = _label("5 / 20", 30, GOLD)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_vbox.add_child(_ammo_label)

	var objective_panel := PanelContainer.new()
	objective_panel.add_theme_stylebox_override("panel", _style_box(Color(0.025, 0.055, 0.045, 0.76), 12.0, Color(0, 0, 0, 0), 0))
	objective_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	objective_panel.position = Vector2(-250, 18)
	objective_panel.size = Vector2(500, 78)
	_root.add_child(objective_panel)
	var objective_vbox := VBoxContainer.new()
	objective_panel.add_child(objective_vbox)
	_objective_title = _label("", 18, GOLD)
	_objective_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_vbox.add_child(_objective_title)
	_objective_detail = _label("", 15, IVORY)
	_objective_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_vbox.add_child(_objective_detail)

	var crosshair_h := ColorRect.new()
	crosshair_h.color = Color(0.86, 1.0, 0.84, 0.88)
	crosshair_h.set_anchors_preset(Control.PRESET_CENTER)
	crosshair_h.position = Vector2(-13, -1)
	crosshair_h.size = Vector2(26, 2)
	crosshair_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(crosshair_h)
	var crosshair_v := ColorRect.new()
	crosshair_v.color = crosshair_h.color
	crosshair_v.set_anchors_preset(Control.PRESET_CENTER)
	crosshair_v.position = Vector2(-1, -13)
	crosshair_v.size = Vector2(2, 26)
	crosshair_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(crosshair_v)

	_hit_marker = _label("×", 54, Color.WHITE)
	_hit_marker.set_anchors_preset(Control.PRESET_CENTER)
	_hit_marker.position = Vector2(-22, -36)
	_hit_marker.size = Vector2(44, 72)
	_hit_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hit_marker.modulate.a = 0.0
	_root.add_child(_hit_marker)

	_interaction_label = _label("", 17, IVORY)
	_interaction_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_interaction_label.position = Vector2(-180, -105)
	_interaction_label.size = Vector2(360, 42)
	_interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interaction_label.hide()
	_root.add_child(_interaction_label)

	_notification_label = _label("", 18, IVORY)
	_notification_label.set_anchors_preset(Control.PRESET_CENTER)
	_notification_label.position = Vector2(-230, 58)
	_notification_label.size = Vector2(460, 48)
	_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notification_label.add_theme_stylebox_override("normal", _style_box(PANEL, 10.0, GOLD.darkened(0.3), 1))
	_notification_label.hide()
	_root.add_child(_notification_label)

	_swim_label = _label("YÜZÜYORSUN", 22, Color("#8fdaf0"))
	_swim_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_swim_label.position = Vector2(-120, 112)
	_swim_label.size = Vector2(240, 38)
	_swim_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_swim_label.hide()
	_root.add_child(_swim_label)

	_blood_overlay = ColorRect.new()
	_blood_overlay.color = Color(0.55, 0.0, 0.0, 0.32)
	_blood_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blood_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blood_overlay.modulate.a = 0.0
	_root.add_child(_blood_overlay)


func _build_touch_controls() -> void:
	_controls = Control.new()
	_controls.name = "TouchControls"
	_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_controls)
	var look_zone := TouchLookZone.new()
	look_zone.name = "LookZone"
	look_zone.anchor_left = 0.4
	look_zone.anchor_right = 1.0
	look_zone.anchor_bottom = 1.0
	_controls.add_child(look_zone)
	var joystick := VirtualJoystick.new()
	joystick.name = "MovementJoystick"
	joystick.anchor_right = 0.55
	joystick.anchor_bottom = 1.0
	_controls.add_child(joystick)

	var fire := _action_button("ATEŞ", Vector2(1, 1), Vector2(-82, -86), 104, DANGER)
	_bind_hold(fire, &"fire")
	var reload := _action_button("DOLDUR", Vector2(1, 1), Vector2(-190, -64), 68, FOREST.lightened(0.1))
	_bind_press(reload, &"reload")
	_aim_button = _action_button("NİŞAN", Vector2(1, 1), Vector2(-82, -200), 70, FOREST.lightened(0.1))
	_aim_button.pressed.connect(func() -> void:
		var active := InputRouter.toggle_action(&"aim")
		_aim_button.modulate = GOLD if active else Color.WHITE
	)
	_interact_button = _action_button("EYLEM", Vector2(1, 1), Vector2(-184, -156), 72, GOLD.darkened(0.25))
	_bind_press(_interact_button, &"interact")
	_interact_button.hide()
	var sprint := _action_button("KOŞ", Vector2(0, 1), Vector2(250, -82), 72, FOREST.lightened(0.1))
	_bind_hold(sprint, &"sprint")
	_crouch_button = _action_button("EĞİL", Vector2(0, 1), Vector2(336, -82), 66, FOREST.lightened(0.1))
	_crouch_button.pressed.connect(func() -> void:
		var active := InputRouter.toggle_action(&"crouch")
		_crouch_button.modulate = GOLD if active else Color.WHITE
	)
	var jump := _action_button("ZIPLA", Vector2(0, 1), Vector2(414, -82), 66, FOREST.lightened(0.1))
	_bind_press(jump, &"jump")
	var pause := _action_button("Ⅱ", Vector2(1, 0), Vector2(-42, 128), 52, FOREST)
	pause.pressed.connect(GameState.toggle_pause)


func _build_menu() -> void:
	_menu_overlay = _overlay_root(Color(0.015, 0.035, 0.028, 0.88))
	var card := _center_card(_menu_overlay, Vector2(560, 390))
	var title := _label("GEYİK 3D", 54, IVORY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(title)
	var rule := HSeparator.new()
	rule.modulate = GOLD
	card.add_child(rule)
	var subtitle := _label("AÇIK DÜNYA MOBİL AV", 19, GOLD)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(subtitle)
	var description := _label("Rüzgârı dinle, izini gizle ve avını etik bir atışla tamamla.\nSol başparmak hareket • Sağ alan bakış", 17, IVORY.darkened(0.08))
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(description)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 22
	card.add_child(spacer)
	var start := Button.new()
	start.text = "AVA BAŞLA"
	start.custom_minimum_size = Vector2(330, 68)
	_style_button(start, GOLD.darkened(0.25))
	start.pressed.connect(func() -> void:
		InputRouter.clear_gameplay_input()
		GameState.start_hunt()
	)
	card.add_child(start)


func _build_pause_overlay() -> void:
	_pause_overlay = _overlay_root(Color(0.01, 0.025, 0.02, 0.88))
	var card := _center_card(_pause_overlay, Vector2(520, 430))
	var title := _label("AV DURAKLATILDI", 35, IVORY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(title)
	card.add_child(_label("Ana Ses", 15, IVORY))
	var volume := HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.01
	volume.value = float(SettingsService.get_value(&"master_volume", 0.82))
	volume.value_changed.connect(func(value: float) -> void: SettingsService.set_value(&"master_volume", value))
	card.add_child(volume)
	card.add_child(_label("Dokunmatik Hassasiyeti", 15, IVORY))
	var sensitivity := HSlider.new()
	sensitivity.min_value = 0.0015
	sensitivity.max_value = 0.008
	sensitivity.step = 0.0001
	sensitivity.value = float(SettingsService.get_value(&"touch_sensitivity", 0.0038))
	sensitivity.value_changed.connect(func(value: float) -> void: SettingsService.set_value(&"touch_sensitivity", value))
	card.add_child(sensitivity)
	var resume := Button.new()
	resume.text = "DEVAM ET"
	resume.custom_minimum_size.y = 62
	_style_button(resume, GOLD.darkened(0.25))
	resume.pressed.connect(GameState.toggle_pause)
	card.add_child(resume)
	_pause_overlay.hide()


func _build_results_overlay() -> void:
	_results_overlay = _overlay_root(Color(0.01, 0.02, 0.016, 0.92))
	var card := _center_card(_results_overlay, Vector2(560, 370))
	_results_title = _label("AV TAMAMLANDI", 42, GOLD)
	_results_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(_results_title)
	_results_detail = _label("", 19, IVORY)
	_results_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(_results_detail)
	var restart := Button.new()
	restart.text = "YENİ AV"
	restart.custom_minimum_size.y = 64
	_style_button(restart, FOREST.lightened(0.08))
	restart.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().reload_current_scene()
	)
	card.add_child(restart)
	_results_overlay.hide()


func _apply_phase(phase: int) -> void:
	if _menu_overlay == null:
		return
	_menu_overlay.visible = phase == GameState.Phase.MAIN_MENU
	_pause_overlay.visible = phase == GameState.Phase.PAUSED
	_results_overlay.visible = phase == GameState.Phase.RESULTS
	_controls.visible = phase == GameState.Phase.PLAYING
	if phase != GameState.Phase.PLAYING:
		InputRouter.clear_gameplay_input()
	if phase == GameState.Phase.RESULTS:
		var completed := bool(GameState.current_hunt.get("completed", false))
		_results_title.text = "AV TAMAMLANDI" if completed else "AV OLDUN"
		_results_title.add_theme_color_override("font_color", GOLD if completed else DANGER)
		_results_detail.text = "Puan: %s\nAtış: %s • İsabet: %s • Etik: %%%s" % [
			GameState.current_hunt.get("score", 0),
			GameState.current_hunt.get("shots", 0),
			GameState.current_hunt.get("hits", 0),
			int(float(GameState.current_hunt.get("ethical_rating", 0.0)) * 100.0),
		]


func _on_health_changed(current: float, maximum: float) -> void:
	var previous := _health_bar.value
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "CAN %s" % int(round(current))
	if current < previous:
		_blood_time = 0.5
	_health_bar.modulate = DANGER if current / maximum < 0.35 else Color.WHITE


func _on_stamina_changed(current: float, maximum: float) -> void:
	_stamina_bar.max_value = maximum
	_stamina_bar.value = current


func _on_ammo_changed(in_magazine: int, reserve: int, reloading: bool) -> void:
	_ammo_label.text = "… / %s" % reserve if reloading else "%s / %s" % [in_magazine, reserve]


func _on_population_changed(counts: Dictionary) -> void:
	_population_label.text = "🦌 %s   🐺 %s   🐻 %s" % [counts.get(&"deer", 0), counts.get(&"wolf", 0), counts.get(&"bear", 0)]


func _on_objective_updated(title: String, detail: String, _progress: float) -> void:
	_objective_title.text = title
	_objective_detail.text = detail


func _on_interaction_prompt(text: String, visible: bool) -> void:
	_interaction_label.text = text
	_interaction_label.visible = visible
	_interact_button.visible = visible


func _on_notification(text: String, severity: int, duration: float) -> void:
	_notification_label.text = text
	_notification_label.add_theme_color_override("font_color", DANGER if severity >= EventBus.NotificationSeverity.ERROR else (GOLD if severity == EventBus.NotificationSeverity.WARNING else IVORY))
	_notification_label.show()
	_notification_time = duration


func _on_swimming_changed(swimming: bool) -> void:
	_swim_label.visible = swimming


func _on_hit_marker(lethal: bool) -> void:
	_hit_marker.add_theme_color_override("font_color", DANGER if lethal else Color.WHITE)
	_hit_marker.modulate.a = 1.0
	_hit_time = 0.22


func _on_player_died() -> void:
	_blood_time = 3.0


func _action_button(text: String, anchor: Vector2, center_offset: Vector2, diameter: float, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.anchor_left = anchor.x
	button.anchor_right = anchor.x
	button.anchor_top = anchor.y
	button.anchor_bottom = anchor.y
	button.offset_left = center_offset.x - diameter * 0.5
	button.offset_right = center_offset.x + diameter * 0.5
	button.offset_top = center_offset.y - diameter * 0.5
	button.offset_bottom = center_offset.y + diameter * 0.5
	_style_button(button, color, diameter * 0.5)
	_controls.add_child(button)
	return button


func _bind_hold(button: Button, action: StringName) -> void:
	button.button_down.connect(func() -> void: InputRouter.set_action(action, true))
	button.button_up.connect(func() -> void: InputRouter.set_action(action, false))


func _bind_press(button: Button, action: StringName) -> void:
	button.pressed.connect(func() -> void:
		InputRouter.set_action(action, true)
		InputRouter.set_action(action, false)
	)


func _style_button(button: Button, color: Color, radius := 12.0) -> void:
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", IVORY)
	button.add_theme_stylebox_override("normal", _style_box(Color(color, 0.82), radius, Color(IVORY, 0.56), 2))
	button.add_theme_stylebox_override("hover", _style_box(Color(color.lightened(0.1), 0.9), radius, GOLD, 2))
	button.add_theme_stylebox_override("pressed", _style_box(Color(DANGER, 0.92), radius, Color.WHITE, 2))


func _progress_bar(fill: Color, maximum: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(190, 12)
	bar.max_value = maximum
	bar.value = maximum
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _style_box(Color(0, 0, 0, 0.55), 5.0, Color(0, 0, 0, 0), 0))
	bar.add_theme_stylebox_override("fill", _style_box(fill, 5.0, Color(0, 0, 0, 0), 0))
	return bar


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.78))
	label.add_theme_constant_override("outline_size", 4)
	return label


func _style_box(color: Color, radius: float, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = int(radius)
	style.corner_radius_top_right = int(radius)
	style.corner_radius_bottom_left = int(radius)
	style.corner_radius_bottom_right = int(radius)
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style


func _overlay_root(color: Color) -> Control:
	var overlay := ColorRect.new()
	overlay.color = color
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(overlay)
	return overlay


func _center_card(overlay: Control, minimum_size: Vector2) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum_size
	panel.add_theme_stylebox_override("panel", _style_box(PANEL, 20.0, GOLD.darkened(0.18), 2))
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)
	return vbox
