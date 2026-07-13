extends Node

## Self-contained procedural audio layer. Cues are generated once and cached so
## the project remains immediately playable without binary asset dependencies.

const MIX_RATE := 22050

var _cue_cache: Dictionary = {}
var _ambience_player: AudioStreamPlayer


func _ready() -> void:
	_ensure_buses()
	EventBus.settings_changed.connect(_on_settings_changed)
	_on_settings_changed(SettingsService.get_all())
	_start_forest_ambience()


func play_cue(cue: StringName, world_position := Vector3.INF) -> void:
	var stream: AudioStreamWAV = _get_or_build_cue(cue)
	if world_position != Vector3.INF:
		var player_3d := AudioStreamPlayer3D.new()
		player_3d.stream = stream
		player_3d.bus = &"SFX"
		player_3d.global_position = world_position
		player_3d.max_distance = 170.0 if cue == &"rifle_shot" else 38.0
		player_3d.finished.connect(player_3d.queue_free)
		add_child(player_3d)
		player_3d.play()
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"SFX"
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func _ensure_buses() -> void:
	for bus_name: StringName in [&"SFX", &"Ambience"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _on_settings_changed(settings: Dictionary) -> void:
	_set_bus_volume(&"Master", float(settings.get("master_volume", 0.82)))
	_set_bus_volume(&"SFX", float(settings.get("sfx_volume", 0.9)))
	_set_bus_volume(&"Ambience", float(settings.get("ambience_volume", 0.72)))


func _set_bus_volume(bus_name: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(clampf(linear, 0.001, 1.0)))


func _get_or_build_cue(cue: StringName) -> AudioStreamWAV:
	if _cue_cache.has(cue):
		return _cue_cache[cue]
	var duration := 0.14
	var frequency := 240.0
	var noise := 0.1
	match cue:
		&"rifle_shot":
			duration = 0.62
			frequency = 72.0
			noise = 0.92
		&"dry_fire":
			duration = 0.07
			frequency = 1100.0
			noise = 0.3
		&"reload":
			duration = 0.38
			frequency = 510.0
			noise = 0.38
		&"footstep":
			duration = 0.11
			frequency = 95.0
			noise = 0.72
		&"hit":
			duration = 0.16
			frequency = 150.0
			noise = 0.5
		&"ui_confirm":
			duration = 0.12
			frequency = 760.0
			noise = 0.02
		&"ui_warning":
			duration = 0.25
			frequency = 310.0
			noise = 0.03
	var stream := _synthesize(duration, frequency, noise, int(hash(cue)))
	_cue_cache[cue] = stream
	return stream


func _synthesize(duration: float, frequency: float, noise_mix: float, seed: int, loop := false) -> AudioStreamWAV:
	var frame_count := maxi(1, int(duration * MIX_RATE))
	var bytes := PackedByteArray()
	bytes.resize(frame_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for frame in frame_count:
		var t := float(frame) / MIX_RATE
		var envelope := 1.0 if loop else pow(1.0 - float(frame) / frame_count, 2.2)
		var tone := sin(TAU * frequency * t) * (1.0 - noise_mix)
		var filtered_noise := rng.randf_range(-1.0, 1.0) * noise_mix
		var sample := clampf((tone + filtered_noise) * envelope * 0.72, -1.0, 1.0)
		bytes.encode_s16(frame * 2, int(sample * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = frame_count
	return wav


func _start_forest_ambience() -> void:
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "ForestAmbience"
	_ambience_player.bus = &"Ambience"
	_ambience_player.volume_db = -19.0
	_ambience_player.stream = _synthesize(3.0, 56.0, 0.55, 481516, true)
	add_child(_ambience_player)
	_ambience_player.play()
