class_name PokerHandResult
extends RefCounted

var hand_id: StringName = &""
var display_name: String = ""
var priority: int = 0
var attack_points: int = 0
var multiplier: float = 0.0
var damage: int = 0
var scoring_cards: Array[CardData] = []
var unscored_cards: Array[CardData] = []


func summary() -> String:
	if hand_id == &"":
		return ""
	return "%s:%d*%.2f=%d" % [
		hand_id,
		attack_points,
		multiplier,
		damage
	]
