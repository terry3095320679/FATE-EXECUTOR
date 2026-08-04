class_name Deck
extends RefCounted

var cards: Array[CardData] = []
var _rng := RandomNumberGenerator.new()


func _init(deck_definition: Dictionary = {}, seed_value: int = 0) -> void:
	_rng.seed = seed_value if seed_value != 0 else Time.get_ticks_usec()
	_build_standard_deck(deck_definition)


func _build_standard_deck(deck_definition: Dictionary) -> void:
	cards.clear()
	var next_id := 1
	for raw_suit: Dictionary in deck_definition.get("suits", []):
		for raw_rank: Dictionary in deck_definition.get("ranks", []):
			cards.append(CardData.new(
				next_id,
				int(raw_rank["value"]),
				int(raw_suit["id"]),
				str(raw_rank["label"]),
				str(raw_suit["name_key"]),
				str(raw_suit["symbol"]),
				Color(str(raw_suit["color"]))
			))
			next_id += 1


func draw_unique(count: int) -> Array[CardData]:
	return draw_unique_excluding(count, {})


func draw_unique_excluding(count: int, excluded_instance_ids: Dictionary) -> Array[CardData]:
	var pool: Array[CardData] = []
	for card in cards:
		if not excluded_instance_ids.has(card.instance_id):
			pool.append(card)
	var drawn: Array[CardData] = []
	var draw_count: int = mini(count, pool.size())
	for _index in range(draw_count):
		var chosen_index := _rng.randi_range(0, pool.size() - 1)
		drawn.append(pool.pop_at(chosen_index))
	return drawn


func has_instance(instance_id: int) -> bool:
	for card in cards:
		if card.instance_id == instance_id:
			return true
	return false


func reseed(seed_value: int) -> void:
	_rng.seed = seed_value
