class_name AnimalDefinition
extends Resource

@export_category("Identity")
@export var species_id: StringName = &"deer"
@export var species_name := "Kızıl Geyik"
@export var is_predator := false
@export var body_color := Color("#8c5b35")

@export_category("Vitals")
@export_range(1.0, 500.0, 1.0) var maximum_health := 100.0
@export_range(0.1, 20.0, 0.1) var walk_speed := 2.2
@export_range(0.1, 30.0, 0.1) var trot_speed := 5.5
@export_range(0.1, 40.0, 0.1) var flee_speed := 10.5

@export_category("Combat")
@export_range(0.0, 100.0, 1.0) var attack_damage := 0.0
@export_range(0.5, 8.0, 0.1) var attack_range := 2.4
@export_range(0.2, 10.0, 0.1) var attack_cooldown := 1.4
@export_range(1.0, 200.0, 1.0) var aggression_range := 0.0

@export_category("Senses")
@export_range(1.0, 300.0, 1.0) var hearing_range := 135.0
@export_range(1.0, 300.0, 1.0) var vision_range := 105.0
@export_range(1.0, 180.0, 1.0) var field_of_view_degrees := 230.0
@export_range(0.1, 10.0, 0.1) var calm_after_seconds := 7.5

@export_category("Trophy")
@export_range(0.0, 500.0, 1.0) var minimum_trophy := 120.0
@export_range(0.0, 500.0, 1.0) var maximum_trophy := 245.0
