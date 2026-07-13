extends Node

## Application-wide event boundary. Gameplay domains publish facts here and never
## retain references to UI, mission, or save implementations.

signal game_phase_changed(phase: int)
signal game_paused(paused: bool)
signal player_spawned(player: Node)
signal player_noise_emitted(world_position: Vector3, loudness: float, category: StringName)
signal shot_fired(origin: Vector3, direction: Vector3, loudness: float)
signal aiming_changed(is_aiming: bool)
signal stamina_changed(current: float, maximum: float)
signal player_health_changed(current: float, maximum: float)
signal player_died()
signal swimming_changed(is_swimming: bool)
signal ammo_changed(in_magazine: int, reserve: int, is_reloading: bool)
signal animal_state_changed(animal: Node, state_name: StringName)
signal animal_hit(animal: Node, report: Dictionary)
signal animal_harvested(report: Dictionary)
signal animal_population_changed(counts: Dictionary)
signal hit_marker_requested(lethal: bool)
signal pickup_collected(pickup_type: StringName, amount: int)
signal outpost_interacted()
signal objective_updated(title: String, detail: String, progress: float)
signal score_changed(score: int, ethical_rating: float)
signal interaction_prompt_changed(text: String, visible: bool)
signal notification_requested(text: String, severity: int, duration: float)
signal settings_changed(settings: Dictionary)

enum NotificationSeverity {
	INFO,
	SUCCESS,
	WARNING,
	ERROR,
}
