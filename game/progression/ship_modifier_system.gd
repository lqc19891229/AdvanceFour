class_name ShipModifierSystem
extends RefCounted

# Fixed addends, additive percentages, then independent multiplicative factors.
# A modifier's target_filter is evaluated against the system being modified.
static func apply(base: float, stat: StringName, modifiers: Array, target: StringName = &"ALL", minimum: float = 0.0) -> float:
	var flat := 0.0
	var percent := 0.0
	var factor := 1.0
	for raw in modifiers:
		var mod := raw as BridgeModifierDefinition
		if mod == null or mod.stat != stat:
			continue
		var filter := String(mod.target_filter).to_upper()
		if not filter.is_empty() and filter != "ALL" and filter != String(target):
			continue
		match mod.operation:
			"FLAT":
				flat += mod.value
			"PERCENT_ADD":
				percent += mod.value
			"MULTIPLIER":
				if mod.value > 0.0:
					factor *= mod.value
	return maxf((base + flat) * maxf(0.0, 1.0 + percent) * factor, minimum)
