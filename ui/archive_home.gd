class_name ArchiveHome
extends Control
## The original sealed archive: four books orbit one shared reading space.

signal navigate(destination: String)
signal book_selected(id: StringName)
signal accent_changed(color: Color)
signal preparation_changed
signal cue_requested(cue: String)

const BOOKS: Array[BookPresentation] = [preload("res://game/content/books/frost.tres"), preload("res://game/content/books/storm.tres"), preload("res://game/content/books/spirit.tres"), preload("res://game/content/books/flame.tres")]
var settings: AppSettings
var repository: VocabularyRepository
var selected: int = 0
var accent := Color("8bdeff")
var _accent_tween: Tween
const ACCENT_SECONDS := 0.9
var prepared: bool = false
var reduced_motion: bool = false
var quality: int = 2
var clock: float = 0.0
var orbit: float = 0.0
var orbit_target: float = 0.0
var orbit_start: float = 0.0
var orbit_elapsed: float = 1.25
var caption_elapsed: float = 1.0
var deployment: float = 0.0
var deployment_start: float = 0.0
var deployment_elapsed: float = .65
var interactive: bool = true
var _accumulated_input := true
var cards: Array[Button] = []
var book_visuals: Array[Control] = []
var stage: ArchiveStage
var fluid: FluidAtmosphere
var book_hits: Control
var artworks: Array[TextureRect] = []
var auras: Array[ColorRect] = []
var patterns: Array[TextureRect] = []
var card_commands: Array[Label] = []
var effects: ArchiveEffects
var floor_plane: ColorRect
var portal: Control
var caption_layer: Control
var wing_layers: Array[Control] = []
var book_titles: Array[Label] = []
var paper: ColorRect
var decoration: Control
var title_accent: Label
var book_command: Label
var seal_layers: Array[TextureRect] = []
var seal_weights := PackedFloat32Array([1.0, 0.0, 0.0, 0.0])
var hover_amount := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var caption: VBoxContainer
var title_group: VBoxContainer
var archive_label: Label
var menu: GridContainer
var right_menu: GridContainer
var menu_buttons: Array[OpenButton] = []
var prepare_button: OpenButton
var back_button: OpenButton
var left_wing: VBoxContainer
var right_wing: VBoxContainer
var bottom_hint: Label
var command_label: Label
var hint: Label
var counter: Label
var difficulty_buttons: Array[Button] = []
var difficulty_text: Label
var vocabulary_select: OptionButton
var seed_edit: LineEdit
const MODE_IDS = ["story", "normal", "hard", "nightmare", "apocalypse"]
const MODE_NAMES = ["启程", "冒险", "深渊", "噩梦", "灭世"]

static func create() -> ArchiveHome:
	return load("res://ui/scenes/archive_home.tscn").instantiate() as ArchiveHome


func _ready() -> void:
	_accumulated_input = Input.use_accumulated_input
	stage = $ArchiveStage
	book_hits = $BookHits
	decoration = $Decoration
	caption_layer = $CaptionLayer
	caption = $CaptionLayer/Caption
	title_group = $TitleGroup
	title_accent = $TitleGroup/Heading/TitleAccent
	archive_label = $ArchiveLabel
	counter = $Counter
	menu = $Menu
	right_menu = $RightMenu
	for column: GridContainer in [menu, right_menu]:
		for button: OpenButton in column.get_children():
			menu_buttons.append(button)
	prepare_button = $PrepareButton
	back_button = $BackButton
	left_wing = $LeftWingLayer/LeftWing
	right_wing = $RightWingLayer/RightWing
	wing_layers = [$LeftWingLayer, $RightWingLayer]
	vocabulary_select = $LeftWingLayer/LeftWing/VocabularySelect
	difficulty_text = $RightWingLayer/RightWing/DifficultyText
	seed_edit = $RightWingLayer/RightWing/SeedEdit
	bottom_hint = $BottomHint
	command_label = $CommandLabel
	book_command = $BookCommand
	hint = $Hint
	bottom_hint.text = ""
	var home_keys := HBoxContainer.new()
	home_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home_keys.add_theme_constant_override("separation", 24)
	bottom_hint.add_child(home_keys)
	home_keys.add_child(KeyHint.create("← / → · 1–4", "选书"))
	home_keys.add_child(KeyHint.create("Enter / Space", "准备"))
	hint.text = ""
	for button: Button in book_hits.get_children():
		cards.append(button)
	for label: Label in $BookTitles.get_children():
		book_titles.append(label)
	for label: Label in $CardCommands.get_children():
		card_commands.append(label)
	for button: Button in $RightWingLayer/RightWing/Modes.get_children():
		difficulty_buttons.append(button)
	paper = stage.scenery.get_node("Paper") as ColorRect
	(paper.material as ShaderMaterial).set_shader_parameter("paper_noise",preload("res://ui/effects/paper_noise.tres"))
	preload("res://ui/effects/paper_noise.tres").changed.connect(stage.request_render)
	visibility_changed.connect(_sync_visibility)
	decoration.draw.connect(_draw_decoration)
	floor_plane = stage.scenery.get_node("Floor") as ColorRect
	floor_plane.light_mask = 2
	effects = stage.scenery.get_node("ArchiveEffects") as ArchiveEffects
	fluid = FluidAtmosphere.new()
	fluid.name = "FluidAtmosphere"
	fluid.scene_quality = settings.quality
	fluid.set_options(settings.fluid_quality, settings.reduce_motion)
	stage.scenery.add_child(fluid)
	stage.scenery.move_child(fluid, 1)
	fluid.bind_particles(effects.get_node("Dust") as GPUParticles2D, 2.4)
	paper.light_mask = 2
	portal = stage.scenery.get_node("Portal") as Control
	# The archive skeleton stays in place; school emblems crossfade independently.
	for book in BOOKS:
		var emblem := TextureRect.new()
		emblem.texture = book.seal
		emblem.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		emblem.material = preload("res://ui/materials/book_seal.tres").duplicate()
		(emblem.material as ShaderMaterial).set_shader_parameter("tint", book.color)
		(emblem.material as ShaderMaterial).set_shader_parameter("strength", .65)
		emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		stage.scenery.add_child(emblem)
		seal_layers.append(emblem)
	for i in BOOKS.size():
		var button := cards[i]
		book_titles[i].text = BOOKS[i].title
		book_titles[i].add_theme_color_override("font_color", BOOKS[i].color)
		card_commands[i].text = "%s  |  %d" % [BOOKS[i].id, i + 1]
		button.pressed.connect(func() -> void: select_book(i))
		button.mouse_entered.connect(func() -> void: cue_requested.emit("ui.focus"))
		var visual := preload("res://ui/scenes/archive_book_visual.tscn").instantiate() as Control
		stage.scenery.add_child(visual)
		book_visuals.append(visual)
		var aura := visual.get_node("Aura") as ColorRect
		(aura.material as ShaderMaterial).set_shader_parameter("school_color", BOOKS[i].color)
		auras.append(aura)
		var pattern := visual.get_node("Pattern") as TextureRect
		pattern.texture = ArcanaRunes.seal(BOOKS[i].id, 320.0)
		patterns.append(pattern)
		var artwork := visual.get_node("Artwork") as TextureRect
		artwork.texture = BOOKS[i].artwork
		artwork.light_mask = 2
		(artwork.material as ShaderMaterial).set_shader_parameter("artwork", BOOKS[i].artwork)
		(artwork.material as ShaderMaterial).set_shader_parameter("school_color", BOOKS[i].color)
		artworks.append(artwork)
	for button: OpenButton in menu_buttons:
		var destination := button.name.to_lower()
		button.pressed.connect(func() -> void: navigate.emit(destination))
		_connect_action_cues(button)
	prepare_button.pressed.connect(func() -> void:
		if prepared:
			navigate.emit("battle")
		else:
			request_preparation()
	)
	_connect_action_cues(prepare_button)
	back_button.pressed.connect(func() -> void: set_prepared(false))
	_connect_action_cues(back_button)
	refresh_vocabulary_choices()
	vocabulary_select.item_selected.connect(func(index: int) -> void:
		settings.vocabulary_id = str(vocabulary_select.get_item_metadata(index))
		preparation_changed.emit()
	)
	var manage_vocabulary := $LeftWingLayer/LeftWing/ManageVocabulary as OpenButton
	manage_vocabulary.pressed.connect(func() -> void: navigate.emit("vocab"))
	_connect_action_cues(manage_vocabulary)
	var progressive := $LeftWingLayer/LeftWing/Progressive as CheckButton
	progressive.button_pressed = settings.progressive
	progressive.toggled.connect(func(value: bool) -> void:
		if settings.progressive == value:
			return
		settings.progressive = value
		preparation_changed.emit()
		cue_requested.emit("ui.tab")
	)
	for i in MODE_NAMES.size():
		var button := difficulty_buttons[i]
		button.pressed.connect(func() -> void: _difficulty(i))
	seed_edit.text = settings.run_seed
	seed_edit.text_changed.connect(func(value: String) -> void:
		settings.run_seed = value
		preparation_changed.emit()
	)
	# Commands share the caption baseline instead of adding empty rows.
	for pair: Array in [[seed_edit, "seed"], [vocabulary_select, "library"], [progressive, "progress"]]:
		var target: Control = pair[0]
		var label_target: Control = target if target == progressive else target.get_parent().get_child(target.get_index() - 1)
		var tag := CommandTag.create(pair[1])
		label_target.add_child(tag)
		tag.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		tag.offset_left = -90
		tag.offset_right = -20
		tag.offset_top = -8
		tag.offset_bottom = 8
	for i in difficulty_buttons.size():
		(difficulty_buttons[i] as OpenButton).set_command_word(MODE_IDS[i])
	prepare_button.set_command_word("start")
	back_button.set_command_word("back")
	manage_vocabulary.set_command_word("vocab")
	resized.connect(_layout)
	var initial := 0
	for i in BOOKS.size():
		if str(BOOKS[i].id) == settings.book_id:
			initial = i
	select_book(initial, false)
	_difficulty(maxi(0, MODE_IDS.find(settings.difficulty)), false)
	set_prepared(false)
	_layout()


func select_book(index: int, notify: bool = true) -> void:
	if notify and posmod(index, BOOKS.size()) == selected:
		return
	selected = posmod(index, BOOKS.size())
	var delta := wrapf(float(selected) - orbit_target, -2.0, 2.0)
	orbit_start = orbit
	orbit_target += delta
	orbit_elapsed = 0.0
	caption_elapsed = 0.0
	if reduced_motion or not notify:
		orbit = orbit_target
	var book := BOOKS[selected]
	book_command.text = "%s  |  %d" % [book.id, selected + 1]
	$CaptionLayer/Caption/Eyebrow.text = book.eyebrow
	$CaptionLayer/Caption/Headline.text = book.headline
	$CaptionLayer/Caption/Description.text = book.subtitle
	$CaptionLayer/Caption/Traits.text = book.description
	counter.text = "%02d / 04" % (selected + 1)
	settings.book_id = str(book.id)
	refresh_book_access()
	_transition_accent(book.color, notify)
	if notify:
		book_selected.emit(book.id)
	_layout()
	if notify:
		var chosen := cards[selected]
		stage.resonate(chosen.get_transform() * (chosen.size * 0.5))


func refresh_vocabulary_choices() -> void:
	vocabulary_select.clear()
	for entry: Dictionary in repository.catalog():
		vocabulary_select.add_item(str(entry.title))
		vocabulary_select.set_item_metadata(vocabulary_select.item_count - 1, str(entry.id))
		if str(entry.id) == settings.vocabulary_id:
			vocabulary_select.select(vocabulary_select.item_count - 1)


func _transition_accent(target: Color, animate: bool) -> void:
	if _accent_tween != null:
		_accent_tween.kill()
	if not animate:
		for i in seal_weights.size():
			seal_weights[i] = 1.0 if i == selected else 0.0
		_set_accent(target)
		return
	# Gentle color changes remain enabled with reduced motion; no displacement.
	_accent_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_accent_tween.tween_method(_blend_theme.bind(accent, target, seal_weights.duplicate(), selected), 0.0, 1.0, ACCENT_SECONDS)


func _blend_theme(progress: float, start: Color, target: Color, start_weights: PackedFloat32Array, target_index: int) -> void:
	for i in seal_weights.size():
		seal_weights[i] = lerpf(start_weights[i], 1.0 if i == target_index else 0.0, progress)
	_set_accent(start.lerp(target, progress))


func _set_accent(value: Color) -> void:
	accent = value
	(stage.get_node("CrystalEdges") as CrystalEdges).configure(quality, reduced_motion, accent)
	fluid.fog_color = Color("668b9b").lerp(accent, .25)
	fluid.light_color = accent
	fluid.update_appearance()
	title_accent.add_theme_color_override("font_color", accent)
	for i in seal_layers.size():
		seal_layers[i].modulate = Color(1,1,1,.045 * seal_weights[i])
		seal_layers[i].visible = seal_weights[i] > 0.0001 and settings.book_unlocked(BOOKS[i].id)
	(floor_plane.material as ShaderMaterial).set_shader_parameter("school_color", accent)
	portal.set("tint", accent)
	effects.set_accent(accent)
	if caption.get_child_count() > 0:
		(caption.get_child(0) as Label).add_theme_color_override("font_color", accent)
	for wing: VBoxContainer in [left_wing, right_wing]:
		(wing.get_child(0) as Label).add_theme_color_override("font_color", accent.lerp(Color.WHITE,.3))
	for i in difficulty_buttons.size():
		if MODE_IDS[i] == settings.difficulty:
			difficulty_buttons[i].add_theme_color_override("font_color", accent.lerp(Color.WHITE,.4))
	decoration.queue_redraw()
	accent_changed.emit(accent)
	stage.request_render()


func request_preparation() -> void:
	if settings.book_unlocked(BOOKS[selected].id):
		set_prepared(true)
	else:
		navigate.emit("learn")


func refresh_book_access() -> void:
	var unlocked := settings.book_unlocked(BOOKS[selected].id)
	var access := $CaptionLayer/Caption/Access as Label
	access.visible = not unlocked
	access.text = "完成本书练习后解锁出征" if settings.lesson_available(BOOKS[selected].id) else "完成基础操作与本书练习后解锁出征"
	prepare_button.set_caption("进入咒典" if prepared else ("准备出征  →" if unlocked else "练习此书  →"))
	var key_row := bottom_hint.get_child(0)
	(key_row.get_child(1) as KeyHint).description = "出征" if prepared else ("准备" if unlocked else "练习")


func set_prepared(value: bool, audible: bool = true) -> void:
	var changed := prepared != value
	prepared = value
	deployment_start = deployment
	deployment_elapsed = 0.0
	if reduced_motion:
		deployment = 1.0 if value else 0.0
	_layout_motion()
	_layout_books()
	stage.request_render()
	back_button.visible = value
	refresh_book_access()
	var key_row := bottom_hint.get_child(0)
	(key_row.get_child(0) as KeyHint).key_text = "← / → · 1–5" if value else "← / → · 1–4"
	(key_row.get_child(0) as KeyHint).description = "难度" if value else "选书"
	prepare_button.disabled = not interactive
	navigate.emit("prepared" if value else "archive")
	_apply_interaction()
	decoration.queue_redraw()
	if changed and audible:
		cue_requested.emit("ui.open" if value else "ui.close")


func _difficulty(index: int, notify: bool = true) -> void:
	var changed: bool = settings.difficulty != MODE_IDS[index]
	settings.difficulty = MODE_IDS[index]
	for i in difficulty_buttons.size():
		difficulty_buttons[i].add_theme_color_override("font_color", accent.lerp(Color.WHITE,.4) if i == index else Color("788a8c"))
		(difficulty_buttons[i] as OpenButton).set_selected_visual(i == index)
	difficulty_text.text = ["生命宽裕，来敌较少，适合初次落笔。", "从容开场，逐段迎接完整挑战。", "敌人更加耐打，考验处置顺序与御术时机。", "精英更耐打，考验持续输入与防御。", "敌人耐久与伤害极高。适合保留遗物升档挑战。"] [index]
	if notify:
		preparation_changed.emit()
		if changed:
			cue_requested.emit("ui.tab")


func _sync_visibility() -> void:
	var active := is_visible_in_tree()
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	stage.set_active(active)
	if not active:
		Input.use_accumulated_input = _accumulated_input


func _process(delta: float) -> void:
	for emblem in seal_layers:
		(emblem.material as ShaderMaterial).set_shader_parameter("clock", 0.0 if reduced_motion else clock)
	var started := DebugLog.begin()
	Input.use_accumulated_input = _accumulated_input if not interactive or reduced_motion or fluid.quality == FluidField2D.Quality.OFF else false
	if not reduced_motion:
		clock += delta
	orbit_elapsed += delta
	caption_elapsed += delta
	deployment_elapsed += delta
	for i in cards.size():
		var active := interactive and not prepared and (cards[i].is_hovered() or bool(cards[i].get_meta("command_match",false)))
		var previous_hover := hover_amount[i]
		var hover_target := 1.0 if active else 0.0
		hover_amount[i] = hover_target if reduced_motion else lerpf(hover_amount[i], hover_target, 1.0 - exp(-delta / 0.14))
		if absf(hover_amount[i] - (1.0 if active else 0.0)) < 0.001:
			hover_amount[i] = 1.0 if active else 0.0
		if hover_amount[i] != previous_hover:
			stage.request_render()
	orbit = lerpf(orbit_start, orbit_target, MotionCurve.cubic(orbit_elapsed / 1.25)) if not reduced_motion and orbit_elapsed < 1.25 else orbit_target
	deployment = lerpf(deployment_start, 1.0 if prepared else 0.0, MotionCurve.cubic(deployment_elapsed / .65, Vector2(.2,.75), Vector2(.2,1))) if not reduced_motion and deployment_elapsed < .65 else (1.0 if prepared else 0.0)
	(paper.material as ShaderMaterial).set_shader_parameter("clock", clock if not reduced_motion else 0.0)
	(paper.material as ShaderMaterial).set_shader_parameter("detail",[.65,.85,1.][quality])
	_layout_motion()
	_layout_books()
	if not interactive:
		fluid.untrack(&"pointer")
	decoration.queue_redraw()
	DebugLog.end(&"home.layout", started)


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion or fluid == null:
		return
	var motion := event as InputEventMouseMotion
	var inverse := get_global_transform_with_canvas().affine_inverse()
	var pointer := inverse * motion.position - fluid.position
	var area := Rect2(Vector2.ZERO, fluid.size)
	if interactive and not reduced_motion and fluid.quality != FluidField2D.Quality.OFF and area.has_point(pointer):
		if not fluid._motion.has(&"pointer"):
			var start := inverse * (motion.position - motion.relative) - fluid.position
			if area.has_point(start):
				fluid.track_body(&"pointer", start, Vector2.ONE * 24, 0, accent, 0, false, 36, 1.0, FluidInfluence.BodyShape.POINTED)
		fluid.track_body(&"pointer", pointer, Vector2.ONE * 24, 0, accent, 0, false, 36, 1.0, FluidInfluence.BodyShape.POINTED)
	else:
		fluid.untrack(&"pointer")


func _exit_tree() -> void:
	Input.use_accumulated_input = _accumulated_input


func _layout() -> void:
	if paper == null:
		return
	var safe_width := _safe_width()
	var safe_left := _safe_left()
	stage.configure(quality, reduced_motion)
	(stage.get_node("CrystalEdges") as CrystalEdges).configure(quality, reduced_motion, accent)
	(paper.material as ShaderMaterial).set_shader_parameter("worldSpan", Vector2(800.*size.x/maxf(size.y,1.),800.))
	title_group.position = Vector2(safe_left + safe_width * .05, (size.y-64) * .065)
	title_group.size.x = 340
	var content_height := size.y - 64.0
	archive_label.position = Vector2(size.x * .5 - 140, content_height * .085)
	archive_label.size = Vector2(280, 26)
	counter.position = archive_label.position + Vector2(0, 32)
	counter.size = Vector2(280, 24)
	var sigil_center := Vector2(size.x * .5, content_height * .465)
	fluid.position = Vector2.ZERO
	fluid.size = size
	effects.configure(Vector2(size.x*.5,content_height*.45),size,quality,reduced_motion)
	var card_width := minf(390, minf(safe_width*.25, size.y*.37))
	var card_height := minf(440, size.y*.42)
	var front_bottom := content_height - clampf(size.y*.14,100,170) - 128 - 38
	effects.set_anchors(sigil_center,minf(safe_width*.51,content_height*.46),Vector2(size.x*.5,front_bottom-card_height*.56),maxf(card_width,card_height*.88)*.86 if settings.book_unlocked(BOOKS[selected].id) else 0.0)
	portal.size = Vector2.ONE * minf(safe_width * .68, content_height * .85)
	portal.position = sigil_center - portal.size * .5
	for emblem in seal_layers:
		emblem.size = Vector2.ONE * minf(safe_width * .54, 660)
		emblem.position = sigil_center - emblem.size * .5
	floor_plane.size = Vector2(minf(safe_width * .85, 1200), content_height * .35)
	floor_plane.position = Vector2(size.x*.5, content_height*.62) - floor_plane.size*.5
	caption.size.x = minf(470.0, safe_width * .44)
	menu.size.x = 240
	right_menu.size.x = 240
	menu.position = Vector2(safe_left + safe_width * .05, content_height - 106 - menu.get_combined_minimum_size().y)
	right_menu.position = Vector2(safe_left + safe_width * .95 - right_menu.size.x, menu.position.y)
	prepare_button.position = Vector2(size.x * .5 - 130, content_height - 96)
	prepare_button.size = Vector2(260, 52)
	back_button.position = Vector2(safe_left + safe_width * .05, 85)
	left_wing.size.x = minf(390, safe_width * .26)
	right_wing.size.x = minf(390, safe_width * .26)
	var keys_width := (bottom_hint.get_child(0) as HBoxContainer).get_combined_minimum_size().x
	bottom_hint.position = Vector2(size.x - 32 - keys_width, size.y - 44)
	bottom_hint.size = Vector2(keys_width, 32)
	command_label.position = Vector2(safe_left + safe_width*.05, size.y - 44)
	command_label.size = Vector2(650, 38)
	book_command.hide()
	hint.position = Vector2(safe_left + safe_width - 470, size.y - 42)
	hint.size.x = 370
	_layout_motion()
	_layout_books()


func _layout_books() -> void:
	var safe_width := _safe_width()
	var content_height := size.y - 64.0
	var caption_bottom := clampf(size.y * .14, 100, 170)
	var grid_top := content_height * .19
	var grid_bottom := content_height - caption_bottom - 128 - 38
	var card_width := minf(390, minf(safe_width*.25, size.y*.37))
	var card_height := minf(440, size.y*.42)
	for i in cards.size():
		var angle := (float(i) - orbit) * PI * .5
		var depth := (cos(angle) + 1.0) * .5
		var book_scale := .5 + depth * .5
		var bottom := Vector2(size.x*.5 + sin(angle)*safe_width*.64*.43, lerpf(grid_top, grid_bottom, .55 + depth*.45))
		cards[i].size = Vector2(card_width,card_height)
		cards[i].pivot_offset = Vector2(card_width*.5,card_height)
		cards[i].position = bottom - Vector2(card_width*.5,card_height)
		cards[i].scale = Vector2.ONE*book_scale
		cards[i].rotation = sin(angle)*deg_to_rad(-13)
		cards[i].z_index = int(depth * 10.0) + 1
		var hover := hover_amount[i]
		var unlocked := settings.book_unlocked(BOOKS[i].id)
		cards[i].modulate.a = pow(lerpf(.48+depth*.52,1.0,hover) * lerpf(1.0, .08, deployment*(1.0-seal_weights[i])),2.2)
		var visual := book_visuals[i]
		visual.size = cards[i].size
		visual.pivot_offset = cards[i].pivot_offset
		visual.position = cards[i].position
		visual.scale = cards[i].scale
		visual.rotation = cards[i].rotation
		visual.z_index = cards[i].z_index
		visual.modulate = cards[i].modulate
		var float_phase := (1.0-cos(clock*TAU/7.0))*.5 if not reduced_motion else 0.0
		var center := visual.get_transform() * Vector2(card_width * .5, card_height * .45 - 12 * float_phase)
		fluid.track_body(StringName("book_%d" % i), center - fluid.position, Vector2(card_width * .40, card_height * .43) * book_scale, visual.rotation + deg_to_rad(2) * float_phase, BOOKS[i].color, ((.7 if i == selected else .3) + hover * .25) if unlocked else 0.0, true, 24.0, visual.modulate.a)
		var art_size := Vector2(card_width,card_height*.88)
		artworks[i].size = art_size * 1.4
		artworks[i].position = -art_size*.2 + Vector2(0,-12*float_phase)
		artworks[i].pivot_offset = artworks[i].size*.5
		artworks[i].rotation = deg_to_rad(2)*float_phase
		var mat := artworks[i].material as ShaderMaterial
		mat.set_shader_parameter("artwork_size", card_width)
		mat.set_shader_parameter("blur_pixels", lerpf(pow(1.0-depth,1.5)*8.5*(1.0-hover),12.0,deployment*(1.0-seal_weights[i])))
		mat.set_shader_parameter("brightness", lerpf(.48+depth*.52,1.08,hover) * (1.0 if unlocked else 0.36))
		mat.set_shader_parameter("awakening", 1.0 if unlocked else 0.0)
		mat.set_shader_parameter("hover", hover)
		patterns[i].size = art_size * 1.08
		patterns[i].visible = unlocked
		patterns[i].position = -art_size*.04
		patterns[i].modulate = Color(BOOKS[i].color,pow(lerpf(.14,.55,seal_weights[i]),2.2))
		auras[i].position = -art_size*.2
		auras[i].visible = unlocked
		auras[i].size = art_size*1.4
		var aura := auras[i].material as ShaderMaterial
		aura.set_shader_parameter("clock",clock if not reduced_motion else 0.)
		aura.set_shader_parameter("canvas_size",auras[i].size)
		aura.set_shader_parameter("density",4 if quality==0 else 12)
		book_titles[i].position = bottom-Vector2(card_width*.5,34.0 if i == selected else 52*book_scale)
		book_titles[i].size = Vector2(card_width,48)
		var font_size := 30 if i == selected else 16
		if book_titles[i].get_theme_font_size("font_size") != font_size:
			book_titles[i].add_theme_font_size_override("font_size", font_size)
		var font_color := (accent if i == selected else BOOKS[i].color) if unlocked else Color("768087")
		if book_titles[i].get_theme_color("font_color") != font_color:
			book_titles[i].add_theme_color_override("font_color", font_color)
		book_titles[i].modulate.a = (1.-deployment)*(.48+depth*.52)*smoothstep(.05,.3,depth)
		book_titles[i].z_index = cards[i].z_index+1
		card_commands[i].position = bottom+Vector2(-card_width*.5,2 if i==selected else 0)
		card_commands[i].size = Vector2(card_width,24)
		card_commands[i].modulate.a = 0.0 if i == selected else (1.-deployment)*.7*smoothstep(.05,.3,depth)
		card_commands[i].z_index = cards[i].z_index+1
	# GUI hit order follows tree order, independently of CanvasItem z_index.
	var ordered: Array[Button] = cards.duplicate()
	ordered.sort_custom(func(a: Button, b: Button) -> bool: return a.z_index < b.z_index)
	for i in ordered.size():
		if ordered[i].get_index() != i:
			book_hits.move_child(ordered[i], i)


func _layout_motion() -> void:
	if caption == null:
		return
	var safe_width := _safe_width()
	var arrival := 1.0 if reduced_motion else MotionCurve.cubic(caption_elapsed,Vector2(0,.0),Vector2(.58,1))
	# Wrapped text may initially measure at zero width; keep the final bounds fitted.
	caption.size.y = caption.get_combined_minimum_size().y
	caption.position = Vector2(size.x * .5 - caption.size.x * .5,size.y-64-clampf(size.y*.14,100,170)-128-38+28+5*(1.-arrival))
	caption_layer.modulate.a = arrival*(1.-deployment)
	var safe_left := _safe_left()
	for control: Control in [menu,right_menu,title_group,archive_label,counter]:
		control.modulate.a = 1.-deployment
	left_wing.position = Vector2(lerpf(size.x*.5-left_wing.size.x, safe_left + safe_width*.05, deployment), (size.y-64)*.23).round()
	right_wing.position = Vector2(lerpf(size.x*.5, safe_left + safe_width*.95-right_wing.size.x, deployment),(size.y-64)*.23).round()
	for layer in wing_layers:
		layer.visible = prepared or deployment > .001
		layer.modulate.a = deployment


func _safe_width() -> float:
	return minf(size.x, size.y * 16.0 / 9.0)


func _safe_left() -> float:
	return (size.x - _safe_width()) * 0.5


func _draw_decoration() -> void:
	decoration.draw_line(Vector2(0, size.y - 64), Vector2(size.x, size.y - 64), Color(accent, .16), 1.0)


func _text(parent: Node, value: String, font_size: int, color: Color) -> Label:
	var label := PageShell.label(parent, value, font_size, color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func set_interactive(value: bool) -> void:
	interactive = value
	stage.get_node("CrystalEdges").visible = value
	_apply_interaction()


func _apply_interaction() -> void:
	seed_edit.focus_mode = Control.FOCUS_CLICK if interactive and prepared else Control.FOCUS_NONE
	seed_edit.editable = interactive and prepared
	prepare_button.disabled = not interactive
	back_button.disabled = not interactive
	for card in cards:
		card.focus_mode = Control.FOCUS_NONE
		card.mouse_filter = Control.MOUSE_FILTER_STOP if interactive and not prepared else Control.MOUSE_FILTER_IGNORE
	for button: OpenButton in menu_buttons:
		button.disabled = prepared or not interactive
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _connect_action_cues(button: OpenButton) -> void:
	button.mouse_entered.connect(func() -> void: cue_requested.emit("ui.focus"))
