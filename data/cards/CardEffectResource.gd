extends Resource
class_name CardEffectResource

@export var effect_type: String = ""
@export var element: StringName = &""
@export var value: float = 0.0
@export var duration: float = 0.0
@export var radius: float = 0.0
@export var stacks: int = 1
@export var interval: int = 0
@export var operation: String = ""
@export var property_name: StringName = &""
@export var upgrade_id: StringName = &""
@export var metadata: Dictionary = {}


func to_effect_dict() -> Dictionary:
	return {
		"effect_type": effect_type,
		"element": String(element),
		"value": value,
		"duration": duration,
		"radius": radius,
		"stacks": stacks,
		"interval": interval,
		"operation": operation,
		"property_name": String(property_name),
		"upgrade_id": String(upgrade_id),
		"metadata": metadata.duplicate(true),
	}
