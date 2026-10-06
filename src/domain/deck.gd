class_name Deck
extends RefCounted

var cards: Array[CardData] = []
var _rng := RandomNumberGenerator.new()
var _deck_definition: Dictionary


func _init(deck_definition: Dictionary = {}, seed_value: int = 0) -> void:
	_deck_definition = deck_definition.duplicate(true)
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


func remove_card(instance_id: int, minimum_size: int) -> bool:
	if cards.size() <= maxi(0, minimum_size):
		return false
	for index in range(cards.size()):
		if cards[index].instance_id == instance_id:
			cards.remove_at(index)
			return true
	return false


func add_card_from_spec(rank: int, suit: int, instance_id: int = 0) -> CardData:
	var resolved_id := instance_id if instance_id > 0 else next_instance_id()
	if has_instance(resolved_id):
		return null
	var card := card_from_spec(rank, suit, resolved_id)
	if card == null:
		return null
	cards.append(card)
	return card


func card_from_spec(rank: int, suit: int, instance_id: int) -> CardData:
	var suit_definition: Dictionary = {}
	var rank_definition: Dictionary = {}
	for raw_suit: Dictionary in _deck_definition.get("suits", []):
		if int(raw_suit.get("id", -1)) == suit:
			suit_definition = raw_suit
			break
	for raw_rank: Dictionary in _deck_definition.get("ranks", []):
		if int(raw_rank.get("value", -1)) == rank:
			rank_definition = raw_rank
			break
	if suit_definition.is_empty() or rank_definition.is_empty():
		return null
	return CardData.new(
		instance_id,
		rank,
		suit,
		str(rank_definition["label"]),
		str(suit_definition["name_key"]),
		str(suit_definition["symbol"]),
		Color(str(suit_definition["color"]))
	)


func next_instance_id() -> int:
	var highest := 0
	for card in cards:
		highest = maxi(highest, card.instance_id)
	return highest + 1


func distribution_by_rank() -> Dictionary:
	var output: Dictionary = {}
	for card in cards:
		output[card.rank] = int(output.get(card.rank, 0)) + 1
	return output


func distribution_by_suit() -> Dictionary:
	var output: Dictionary = {}
	for card in cards:
		output[card.suit] = int(output.get(card.suit, 0)) + 1
	return output


func to_records() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for card in cards:
		output.append(card.to_record())
	return output


func restore_records(records: Array) -> bool:
	var restored: Array[CardData] = []
	var seen: Dictionary = {}
	for raw_record: Variant in records:
		if not raw_record is Dictionary:
			return false
		var record := raw_record as Dictionary
		var instance_id := int(record.get("instance_id", 0))
		if instance_id <= 0 or seen.has(instance_id):
			return false
		var card := card_from_spec(
			int(record.get("rank", 0)),
			int(record.get("suit", -1)),
			instance_id
		)
		if card == null:
			return false
		seen[instance_id] = true
		restored.append(card)
	cards = restored
	return true


func reseed(seed_value: int) -> void:
	_rng.seed = seed_value
