extends Node

enum Phase {
	MAIN_MENU,
	PLAYING,
	PAUSED,
	RESULTS,
}

var phase := Phase.MAIN_MENU
var current_hunt: Dictionary = {}
var progress: Dictionary = {}


func _ready() -> void:
	progress = SaveService.load_progress()
	reset_hunt()


func reset_hunt() -> void:
	current_hunt = {
		"started_at": Time.get_ticks_msec(),
		"shots": 0,
		"hits": 0,
		"harvests": 0,
		"score": 0,
		"ethical_rating": 1.0,
		"completed": false,
	}


func start_hunt() -> void:
	reset_hunt()
	set_phase(Phase.PLAYING)


func set_phase(next_phase: Phase) -> void:
	phase = next_phase
	get_tree().paused = phase == Phase.PAUSED
	EventBus.game_phase_changed.emit(phase)
	EventBus.game_paused.emit(phase == Phase.PAUSED)


func toggle_pause() -> void:
	if phase == Phase.PLAYING:
		set_phase(Phase.PAUSED)
	elif phase == Phase.PAUSED:
		set_phase(Phase.PLAYING)


func register_shot() -> void:
	current_hunt["shots"] = int(current_hunt["shots"]) + 1


func register_hit() -> void:
	current_hunt["hits"] = int(current_hunt["hits"]) + 1


func register_harvest(report: Dictionary) -> void:
	current_hunt["harvests"] = int(current_hunt["harvests"]) + 1
	var ethical := bool(report.get("ethical", false))
	var ethical_rating := float(current_hunt["ethical_rating"])
	current_hunt["ethical_rating"] = clampf(ethical_rating + (0.08 if ethical else -0.28), 0.0, 1.0)
	var score_delta := int(report.get("score", 0))
	current_hunt["score"] = int(current_hunt["score"]) + score_delta
	progress["total_harvests"] = int(progress.get("total_harvests", 0)) + 1
	progress["best_trophy"] = maxf(float(progress.get("best_trophy", 0.0)), float(report.get("trophy", 0.0)))
	EventBus.score_changed.emit(int(current_hunt["score"]), float(current_hunt["ethical_rating"]))


func complete_hunt() -> void:
	if bool(current_hunt.get("completed", false)):
		return
	current_hunt["completed"] = true
	progress["successful_hunts"] = int(progress.get("successful_hunts", 0)) + 1
	progress["best_score"] = maxi(int(progress.get("best_score", 0)), int(current_hunt["score"]))
	SaveService.save_progress(progress)
	set_phase(Phase.RESULTS)

