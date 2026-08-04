class_name CardData
extends RefCounted

var instance_id: int
var rank: int
var suit: int
var rank_label: String
var suit_name: String
var suit_symbol: String
var suit_color: Color


func _init(
	p_instance_id: int = 0,
	p_rank: int = 1,
	p_suit: int = 0,
	p_rank_label: String = "A",
	p_suit_name: String = "梅花",
	p_suit_symbol: String = "♣",
	p_suit_color: Color = Color("#242a38")
) -> void:
	instance_id = p_instance_id
	rank = p_rank
	suit = p_suit
	rank_label = p_rank_label
	suit_name = p_suit_name
	suit_symbol = p_suit_symbol
	suit_color = p_suit_color


func display_name() -> String:
	return "%s%s" % [suit_symbol, rank_label]


func debug_key() -> String:
	return "%s_%s_%d" % [suit_name, rank_label, instance_id]

