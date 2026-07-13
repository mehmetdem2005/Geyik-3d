class_name HuntMission
extends Node

enum Stage {
	WAITING,
	HARVEST_DEER,
	RETURN_TO_OUTPOST,
	COMPLETE,
}

var stage := Stage.WAITING


func _ready() -> void:
	EventBus.game_phase_changed.connect(_on_phase_changed)
	EventBus.animal_harvested.connect(_on_animal_harvested)
	EventBus.outpost_interacted.connect(_on_outpost_interacted)


func _on_phase_changed(phase: int) -> void:
	if phase == GameState.Phase.PLAYING and stage == Stage.WAITING:
		stage = Stage.HARVEST_DEER
		EventBus.objective_updated.emit("İLK İZ", "Bir kızıl geyik avla ve yakından doğrula", 0.0)


func _on_animal_harvested(report: Dictionary) -> void:
	if stage != Stage.HARVEST_DEER or report.get("species") != &"deer":
		return
	stage = Stage.RETURN_TO_OUTPOST
	EventBus.objective_updated.emit("EMANET", "Orman karakoluna dön ve tezgâhı kullan", 0.67)


func _on_outpost_interacted() -> void:
	if stage == Stage.HARVEST_DEER:
		EventBus.notification_requested.emit("Önce bir kızıl geyik avlamalısın", EventBus.NotificationSeverity.WARNING, 2.2)
		return
	if stage != Stage.RETURN_TO_OUTPOST:
		return
	stage = Stage.COMPLETE
	EventBus.objective_updated.emit("AV TAMAMLANDI", "Kupa ve ilerleme kaydedildi", 1.0)
	GameState.complete_hunt()

