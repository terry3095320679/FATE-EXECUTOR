class_name CardOfferGenerator
extends RefCounted


static func generate(deck: Deck, rng: RandomNumberGenerator, count: int) -> Array[Dictionary]:
	var combinations: Array[Dictionary] = []
	for suit in range(4):
		for rank in range(2, 15):
			combinations.append({"rank": rank, "suit": suit})
	var output: Array[Dictionary] = []
	var candidate_count := mini(maxi(0, count), combinations.size())
	var first_id := deck.next_instance_id()
	for index in range(candidate_count):
		var chosen_index := rng.randi_range(0, combinations.size() - 1)
		var chosen: Dictionary = combinations.pop_at(chosen_index)
		output.append({
			"instance_id": first_id + index,
			"rank": int(chosen["rank"]),
			"suit": int(chosen["suit"])
		})
	return output
