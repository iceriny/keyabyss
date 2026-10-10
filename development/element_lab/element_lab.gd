extends Node
## Isolated material study: one orthographic world, one shared planar velocity field.
const WORLD := Vector2(1600,900)
const FIRE := Vector2(985,465)
const ICE := Vector2(630,470)
const FONT: Font = preload("res://assets/fonts/jinghua-song.ttf")
var world: SubViewport
var field: FluidField2D
var chemistry := Combustion.new()
var frost := FrostGrowth.new()
var ice_material: ShaderMaterial
var growth_steps := 0
var fire_lights: Array[PointLight2D] = []
var light: PointLight2D
var fuel_button: Button
var pause_button: Button
var light_button: Button
var film_button: Button
var density_button: Button
var film_visible := true
var density_index := 0
const DENSITIES := [.42,.56]
var pointer := Vector2(640,400)
var previous_pointer := pointer
var stirring := FluidInfluence.new()
var vortices: Array[FluidInfluence] = []
var ice_age := 0.0
var clock := 0.0
var supply := true
var halted := false
var ready_to_step := false
var fire_light_level := 0.0
var evidence := ""
var capture_stage := 0
var measurements: Dictionary = {}
var gpu_times: Array[float] = []
var _last_gpu_frame := -1


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--rho="):
			frost.vapor_density=clampf(argument.trim_prefix("--rho=").to_float(),.2,.8)
	density_index=maxi(DENSITIES.find(frost.vapor_density),0)
	get_window().title = "键渊 · 冰与火材质小样"
	get_window().size = Vector2i(1440,810)
	get_window().content_scale_size = Vector2i(WORLD)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().use_hdr_2d = true
	world = SubViewport.new()
	world.size = Vector2i(WORLD)
	world.use_hdr_2d = true
	world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(world)
	var output := TextureRect.new()
	output.texture = world.get_texture()
	output.size = WORLD
	output.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(output)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CANVAS
	environment.environment.glow_enabled = true
	environment.environment.glow_intensity = .65
	environment.environment.glow_strength = .85
	environment.environment.glow_hdr_threshold = 1.0
	environment.environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	world.add_child(environment)
	var floor_surface := _surface(preload("res://development/element_lab/space.gdshader"))
	(floor_surface.material as ShaderMaterial).set_shader_parameter("paper_noise",preload("res://ui/effects/paper_noise.tres"))
	var backdrop := BackBufferCopy.new()
	backdrop.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	world.add_child(backdrop)
	_add_ice()
	_add_flow()
	field.add_child(chemistry)
	RenderingServer.call_on_render_thread(chemistry.configure.bind(field.field_texture()))
	var gas_backdrop := BackBufferCopy.new()
	gas_backdrop.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	world.add_child(gas_backdrop)
	var fire := _surface(preload("res://ui/materials/combustion.gdshader"))
	(fire.material as ShaderMaterial).set_shader_parameter("combustion",chemistry.texture)
	_add_lights()
	_add_embers()
	_add_controls()
	world.msaa_2d = Viewport.MSAA_4X
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			evidence = argument.trim_prefix("--capture=")
			DirAccess.make_dir_recursive_absolute(evidence)
	await RenderingServer.frame_post_draw
	ready_to_step = true


func _surface(shader: Shader) -> ColorRect:
	var surface := ColorRect.new()
	surface.size = WORLD
	surface.light_mask = 2
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = shader
	surface.material = material
	world.add_child(surface)
	return surface


func _add_ice() -> void:
	world.add_child(frost)
	RenderingServer.call_on_render_thread(frost.configure)
	var patch := ColorRect.new()
	patch.size = Vector2.ONE*610
	patch.position = ICE-patch.size*.5
	patch.light_mask = 2
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ice_material = ShaderMaterial.new()
	ice_material.shader = preload("res://ui/materials/ice_surface.gdshader")
	ice_material.set_shader_parameter("crystal_surface",frost.surface_texture)
	ice_material.set_shader_parameter("microstructure",preload("res://assets/art/effects/frost_microfacets.png"))
	ice_material.set_shader_parameter("film_structure",preload("res://assets/art/effects/ice_microstructure.png"))
	patch.material = ice_material
	world.add_child(patch)


func _add_flow() -> void:
	field = FluidField2D.new()
	field.size = WORLD
	field.quality = FluidField2D.Quality.HIGH
	field.wind = Vector2.ZERO
	field.buoyancy = 0.0
	field.settling = 0.0
	field.vorticity = 2.0
	field.velocity_decay = .75
	field.density_decay = 1.2
	field.turbulence = .8
	field.turbulence_force = 100.0
	field.turbulence_scale = 145.0
	field.turbulence_detail = .8
	field.opacity = .16
	field.center_clear = 0.0
	world.add_child(field)
	field.set_process(false)
	for i in 3:
		var vortex := FluidInfluence.new()
		vortex.extent = Vector2.ONE*130
		vortex.coupling = 2.5
		vortex.spin = [2.7,-3.0,2.0][i]
		vortices.append(vortex)
		field.sources.append(vortex)
	var mist := FluidInfluence.new()
	mist.center = ICE
	mist.extent = Vector2(200,140)
	mist.density = .12
	mist.noise_amount = 1.0
	mist.noise_scale = 55
	mist.medium = FluidMedium.new()
	mist.medium.color = Color("abcbdc")
	mist.medium.dissipation = 1.5
	field.sources.append(mist)
	stirring.extent = Vector2.ONE*115
	stirring.displacement_radius = 28
	stirring.coupling = 22


func _lamp(at: Vector2,color: Color,energy: float,radius: float) -> PointLight2D:
	var lamp := PointLight2D.new()
	var texture := GradientTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(.5,.5)
	texture.fill_to = Vector2(1,.5)
	texture.gradient = Gradient.new()
	texture.gradient.offsets = PackedFloat32Array([0,.22,.6,1])
	texture.gradient.colors = PackedColorArray([Color.WHITE,Color(1,1,1,.65),Color(1,1,1,.18),Color(1,1,1,0)])
	lamp.texture = texture
	lamp.texture_scale = radius*2/256
	lamp.position = at
	lamp.color = color
	lamp.energy = energy
	lamp.height = 90
	lamp.range_item_cull_mask = 2
	world.add_child(lamp)
	return lamp


func _add_lights() -> void:
	light = _lamp(pointer,Color("ceeaff"),2.0,320)
	for i in 3:
		fire_lights.append(_lamp(FIRE+Vector2.from_angle(i*TAU/3)*65,Color("ffad65"),0,420))


func _add_embers() -> void:
	var particles := GPUParticles2D.new()
	particles.position = FIRE
	particles.amount = 90
	particles.lifetime = 1.4
	particles.preprocess = .5
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	motion.emission_sphere_radius = 108
	motion.gravity = Vector3.ZERO
	motion.spread = 180
	motion.initial_velocity_min = 7
	motion.initial_velocity_max = 25
	motion.scale_min = .08
	motion.scale_max = .23
	motion.color = Color(3.2,1.1,.12)
	var ramp := GradientTexture1D.new()
	ramp.gradient = Gradient.new()
	ramp.gradient.colors = PackedColorArray([Color.WHITE,Color(.5,.15,.015,0)])
	motion.color_ramp = ramp
	particles.process_material = motion
	particles.visibility_rect = Rect2(-350,-350,700,700)
	var texture := GradientTexture2D.new()
	texture.width = 12
	texture.height = 12
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(.5,.5)
	texture.fill_to = Vector2(1,.5)
	texture.gradient = Gradient.new()
	texture.gradient.colors = PackedColorArray([Color.WHITE,Color(1,1,1,0)])
	particles.texture = texture
	world.add_child(particles)
	field.bind_particles(particles,3.0)
	particles.name = "Embers"


func _label(text: String,at: Vector2,points: int,color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_override("font",FONT)
	label.add_theme_font_size_override("font_size",points)
	label.add_theme_color_override("font_color",color)
	add_child(label)


func _button(text: String,at: Vector2,action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = Vector2(135,40)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font",FONT)
	button.add_theme_font_size_override("font_size",19)
	button.add_theme_color_override("font_color",Color("c4c4af"))
	button.add_theme_color_override("font_hover_color",Color("f2dfac"))
	button.pressed.connect(action)
	add_child(button)
	return button


func _add_controls() -> void:
	_label("冰与火",Vector2(70,56),32,Color("ded0ad"))
	_label("材质小样",Vector2(74,105),16,Color("8eaaa9"))
	_label("移动鼠标照明 · 按住左键搅动气流",Vector2(70,784),18,Color("9baead"))
	_button("重新结晶",Vector2(70,825),func():
		ice_age=0.0
		growth_steps=0
		RenderingServer.call_on_render_thread(frost.reset))
	fuel_button = _button("停止供火",Vector2(245,825),_toggle_fuel)
	pause_button = _button("暂停",Vector2(420,825),func():
		halted=not halted
		pause_button.text="继续" if halted else "暂停"
		(world.get_node("Embers") as GPUParticles2D).speed_scale=0.0 if halted else 1.0)
	light_button = _button("关闭探照光",Vector2(595,825),func():
		light.enabled=not light.enabled
		light_button.text="关闭探照光" if light.enabled else "开启探照光")
	film_button = _button("隐藏冰膜",Vector2(770,825),_toggle_film)
	density_button = _button("水汽 %.2f" % frost.vapor_density,Vector2(945,825),func():
		density_index=(density_index+1)%DENSITIES.size()
		frost.vapor_density=DENSITIES[density_index]
		density_button.text="水汽 %.2f" % frost.vapor_density
		ice_age=0.0
		growth_steps=0
		RenderingServer.call_on_render_thread(frost.reset.bind(false)))
	_button("离开",Vector2(1390,825),func(): get_tree().quit())


func _toggle_fuel() -> void:
	supply=not supply
	fuel_button.text="停止供火" if supply else "恢复供火"
	(world.get_node("Embers") as GPUParticles2D).emitting=supply


func _toggle_film() -> void:
	film_visible=not film_visible
	ice_material.set_shader_parameter("show_film",film_visible)
	film_button.text="隐藏冰膜" if film_visible else "显示冰膜"


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion: pointer=(event as InputEventMouseMotion).position
	if event is InputEventKey and event.is_pressed() and event.physical_keycode==KEY_ESCAPE:
		get_tree().quit()


func _process(delta: float) -> void:
	if not ready_to_step: return
	light.position=pointer
	if halted: return
	var dt:=minf(delta,.0333333)
	clock+=dt
	ice_age+=dt
	var measure := not evidence.is_empty() and clock>2.0 and clock<4.5
	if measure: RenderingServer.call_on_render_thread(_gpu_mark.bind("lab_begin"))
	var target_steps := mini(FrostGrowth.MAX_STEPS,int(ice_age*480.0))
	if ice_age<10.1:
		RenderingServer.call_on_render_thread(frost.step.bind(target_steps-growth_steps,dt))
	growth_steps=target_steps
	for i in vortices.size():
		vortices[i].center=FIRE+Vector2.from_angle(clock*.35+i*TAU/3)*90
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and pointer.y<760:
		stirring.center=pointer
		stirring.velocity=(pointer-previous_pointer)/maxf(dt,.001)
		if not field.sources.has(stirring): field.sources.append(stirring)
	else: field.sources.erase(stirring)
	previous_pointer=pointer
	field._process(dt)
	RenderingServer.call_on_render_thread(chemistry.step.bind(PackedFloat32Array([WORLD.x,WORLD.y,dt,clock,FIRE.x,FIRE.y,165.0,1.0 if supply else 0.0])))
	if measure:
		RenderingServer.call_on_render_thread(_gpu_mark.bind("lab_end"))
		RenderingServer.call_on_render_thread(_read_gpu_times)
	fire_light_level=move_toward(fire_light_level,1.0 if supply else 0.0,dt*(.7 if supply else .5))
	for i in fire_lights.size():
		fire_lights[i].energy=fire_light_level*(.65+.09*sin(clock*3.1+i*2.0))
	if not evidence.is_empty(): _capture_sequence()


func _capture_sequence() -> void:
	var times := [1.2,5.0,7.0,7.2,9.0,13.0]
	if capture_stage>=times.size() or clock<times[capture_stage]: return
	var names := ["01-growth","02-burning","03-raking-light","04-crystal-only","05-fire-light","06-cooled"]
	var stage:=capture_stage
	capture_stage+=1
	_capture(names[stage],stage)


func _capture(label: String,stage: int) -> void:
	halted=true
	await RenderingServer.frame_post_draw
	var source:=get_viewport().get_texture().get_image()
	var picture:=Image.create(source.get_width(),source.get_height(),false,Image.FORMAT_RGBA8)
	for y in source.get_height():
		for x in source.get_width(): picture.set_pixel(x,y,source.get_pixel(x,y).linear_to_srgb())
	picture.save_png(evidence.path_join(label+".png"))
	if stage in [0,1,5]:
		var crystals := frost.texture.get_image()
		var surface_state:=frost.surface_texture.get_image()
		var frozen := 0
		var old_height := 0.0
		var old_count := 0
		var young_height := 0.0
		var young_count := 0
		for y in crystals.get_height():
			for x in crystals.get_width():
				var cell:=crystals.get_pixel(x,y)
				if cell.a<=0.0: continue
				frozen+=1
				var height:=surface_state.get_pixel(x,y).r*7.0
				if cell.a<growth_steps*.25:
					old_height+=height
					old_count+=1
				if cell.a>growth_steps*.75:
					young_height+=height
					young_count+=1
		measurements[label+"_frozen_cells"]=frozen
		measurements[label+"_old_height"]=old_height/maxi(old_count,1)
		measurements[label+"_young_height"]=young_height/maxi(young_count,1)
		var film_only:=0
		var bare_crystal:=0
		for y in surface_state.get_height():
			for x in surface_state.get_width():
				var cell:=surface_state.get_pixel(x,y)
				if cell.a<.5 and cell.g>.5: film_only+=1
				if cell.a>.5 and cell.g<.1: bare_crystal+=1
		measurements[label+"_film_only_cells"]=film_only
		measurements[label+"_bare_crystal_cells"]=bare_crystal
		if stage==5: measurements["film_only_cells"]=film_only
	if stage in [1,5]:
		var state:=chemistry.texture.get_image()
		var temperature:=0.0
		for y in state.get_height():
			for x in state.get_width(): temperature=maxf(temperature,state.get_pixel(x,y).g)
		measurements[label+"_max_temperature"]=temperature
	if stage==1: pointer=Vector2(420,535)
	if stage==2: _toggle_film()
	if stage==3:
		_toggle_film()
		light.enabled=false
	if stage==4: _toggle_fuel()
	if stage==5:
		measurements["vapor_density"]=frost.vapor_density
		measurements["older_is_thicker"]=measurements["06-cooled_old_height"]>measurements["06-cooled_young_height"]
		measurements["zero_gravity"]=field.buoyancy==0.0 and field.settling==0.0
		measurements["cooled"]=measurements["06-cooled_max_temperature"]<measurements["02-burning_max_temperature"]*.35
		measurements["grew"]=measurements["02-burning_frozen_cells"]>measurements["01-growth_frozen_cells"]
		gpu_times.sort()
		if not gpu_times.is_empty():
			@warning_ignore("integer_division") # Median sample index intentionally truncates.
			measurements["compute_ms_median"]=gpu_times[gpu_times.size()/2]
			measurements["compute_ms_p95"]=gpu_times[int(gpu_times.size()*.95)]
			measurements["compute_samples"]=gpu_times.size()
		measurements["gpu"]=RenderingServer.get_video_adapter_name()
		FileAccess.open(evidence.path_join("observations.json"),FileAccess.WRITE).store_string(JSON.stringify(measurements,"\t"))
		print("Element lab observations: ",measurements)
		get_tree().quit(0 if measurements.cooled and measurements.grew and measurements.older_is_thicker and measurements.film_only_cells>0 else 1)
	halted=false


func _gpu_mark(label: String) -> void:
	RenderingServer.get_rendering_device().capture_timestamp(label)


func _read_gpu_times() -> void:
	var rd:=RenderingServer.get_rendering_device()
	var frame:=rd.get_captured_timestamps_frame()
	if frame==_last_gpu_frame: return
	_last_gpu_frame=frame
	var start: int=-1
	for index in rd.get_captured_timestamps_count():
		var label:=rd.get_captured_timestamp_name(index)
		if label=="lab_begin": start=rd.get_captured_timestamp_gpu_time(index)
		elif label=="lab_end" and start>=0:
			_record_gpu_time.call_deferred(float(rd.get_captured_timestamp_gpu_time(index)-start)/1000000.0)


func _record_gpu_time(milliseconds: float) -> void:
	gpu_times.append(milliseconds)
